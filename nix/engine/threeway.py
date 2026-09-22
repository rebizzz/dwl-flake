"""Three-way merge for hunks that no longer match after an earlier patch."""

import os
import re
import shutil
import subprocess
import sys
import tempfile
from typing import List, Optional, Set, Tuple


def _make_writable(tree: str) -> None:
    """Store copies are read-only, and patch writes via a temp file next to each
    target, so the directories need write permission too."""

    def allow_write(path: str) -> None:
        if os.path.islink(path):
            return
        try:
            os.chmod(path, os.stat(path).st_mode | 0o200)
        except OSError:
            pass

    allow_write(tree)
    for root, dirs, files in os.walk(tree):
        for name in dirs + files:
            allow_write(os.path.join(root, name))


def snapshot_pristine(target_dir: str) -> str:
    """Copies the unpatched source tree aside for use as a merge ancestor."""
    dest = tempfile.mkdtemp(prefix="dwl-pristine-")
    tree = os.path.join(dest, "tree")
    shutil.copytree(target_dir, tree, symlinks=True)
    _make_writable(tree)
    return tree


def _run_patch(tree: str, patch_path: str, fuzz: int, dry_run: bool) -> bool:
    cmd = ["patch", "-p1", "-f", "-s", "-l", f"-F{fuzz}", "--no-backup-if-mismatch"]
    if dry_run:
        cmd.append("--dry-run")
    with open(patch_path, "rb") as f:
        res = subprocess.run(cmd, stdin=f, cwd=tree, capture_output=True)
    return res.returncode == 0


def _patch_into(tree: str, patch_path: str, dry_run: bool = False) -> bool:
    """Applies one patch to `tree`, exact match first, then fuzz.

    Each level is probed with --dry-run because a failed real run leaves the
    tree half-patched and poisons the next attempt.
    """
    for fuzz in (0, 3):
        if not _run_patch(tree, patch_path, fuzz, dry_run=True):
            continue
        return True if dry_run else _run_patch(tree, patch_path, fuzz, dry_run=False)
    return False


def _fresh_copy(tree: str) -> str:
    work = tempfile.mkdtemp(prefix="dwl-merge-")
    dest = os.path.join(work, "tree")
    shutil.copytree(tree, dest, symlinks=True)
    _make_writable(dest)
    return dest


def build_ancestor_and_theirs(
    patch_path: str, pristine_tree: str, applied_patches: List[str]
) -> Optional[Tuple[str, str]]:
    """Finds an ancestor `patch_path` still applies to, plus that tree with it applied.

    barborder needs bar, so it won't apply to untouched source. Take the
    shortest prefix of the already-applied patches it fits on top of: that is
    the nearest ancestor shared with the working tree.
    """
    for count in range(len(applied_patches) + 1):
        base = _fresh_copy(pristine_tree)
        if not all(_patch_into(base, prior) for prior in applied_patches[:count]):
            shutil.rmtree(os.path.dirname(base), ignore_errors=True)
            continue
        if not _patch_into(base, patch_path, dry_run=True):
            shutil.rmtree(os.path.dirname(base), ignore_errors=True)
            continue
        theirs = _fresh_copy(base)
        if _patch_into(theirs, patch_path):
            return base, theirs
        shutil.rmtree(os.path.dirname(base), ignore_errors=True)
        shutil.rmtree(os.path.dirname(theirs), ignore_errors=True)
    return None


def _single_point_insertion(base: str, side: str) -> Optional[Tuple[int, str]]:
    """
    If `side` is `base` with one contiguous run of characters inserted,
    returns (offset into base, inserted text). Otherwise None.
    """
    if len(side) <= len(base):
        return None
    prefix = 0
    while prefix < len(base) and base[prefix] == side[prefix]:
        prefix += 1
    suffix = 0
    while (
        suffix < len(base) - prefix
        and base[len(base) - 1 - suffix] == side[len(side) - 1 - suffix]
    ):
        suffix += 1
    if prefix + suffix != len(base):
        return None
    return prefix, side[prefix:len(side) - suffix]


# An additive arithmetic term, e.g. " - borderpx" or " + sidepad".
_ADDITIVE_TERM = re.compile(r'^\s*[-+]\s*[A-Za-z_][A-Za-z0-9_]*\s*$')


def _merge_additive_line(base: str, ours: str, theirs: str) -> Optional[str]:
    """Merges one line both sides extended with an additive term.

    barpadding adds `- sidepad` and barborder `- borderpx` to the same
    expression; keeping one side would drop that patch's offset.
    """
    ins_o = _single_point_insertion(base, ours)
    ins_t = _single_point_insertion(base, theirs)
    if ins_o is None or ins_t is None:
        return None
    pos_o, text_o = ins_o
    pos_t, text_t = ins_t
    if not (_ADDITIVE_TERM.match(text_o) and _ADDITIVE_TERM.match(text_t)):
        return None
    if pos_o == pos_t:
        return base[:pos_o] + text_o + text_t + base[pos_o:]
    merged = base
    for pos, text in sorted(((pos_o, text_o), (pos_t, text_t)), reverse=True):
        merged = merged[:pos] + text + merged[pos:]
    return merged


def _resolve_line_wise(ours: List[str], base: List[str], theirs: List[str]) -> Optional[List[str]]:
    """Resolves a block where both sides edited the region but not the same lines.

    diff3 flags the whole region as soon as the sides touch nearby lines. Going
    line by line against the ancestor takes whichever side changed each line,
    and only gives up where both changed one line incompatibly.
    """
    if not (len(ours) == len(base) == len(theirs)):
        return None
    merged: List[str] = []
    for line_base, line_ours, line_theirs in zip(base, ours, theirs):
        if line_ours == line_theirs:
            merged.append(line_ours)
        elif line_ours == line_base:
            merged.append(line_theirs)
        elif line_theirs == line_base:
            merged.append(line_ours)
        else:
            combined = _merge_additive_line(line_base, line_ours, line_theirs)
            if combined is None:
                return None
            merged.append(combined)
    return merged


def resolve_conflict_markers(
    merged: str, unresolved: Optional[List[List[str]]] = None
) -> Optional[str]:
    """Resolves the diff3 conflict blocks we understand, else returns None.

    Blocks we cannot resolve are appended to `unresolved` as
    [ours, base, theirs] so the caller can explain the failure.
    """
    out: List[str] = []
    lines = merged.split("\n")
    i = 0
    while i < len(lines):
        if not lines[i].startswith("<<<<<<<"):
            out.append(lines[i])
            i += 1
            continue

        ours: List[str] = []
        base: List[str] = []
        theirs: List[str] = []
        section = "ours"
        i += 1
        closed = False
        while i < len(lines):
            line = lines[i]
            if line.startswith("|||||||"):
                section = "base"
            elif line.startswith("======="):
                section = "theirs"
            elif line.startswith(">>>>>>>"):
                closed = True
                i += 1
                break
            else:
                {"ours": ours, "base": base, "theirs": theirs}[section].append(line)
            i += 1
        if not closed:
            return None

        if ours == theirs:
            out.extend(ours)
            continue
        resolved = _resolve_line_wise(ours, base, theirs)
        if resolved is None:
            if unresolved is None:
                return None
            unresolved.append([ours, base, theirs])
            continue
        out.extend(resolved)
    return None if unresolved else "\n".join(out)


def _patch_added_lines(patch_path: str) -> Set[str]:
    """The non-trivial lines a patch introduces, used to attribute a conflict."""
    try:
        with open(patch_path, "r", encoding="utf-8", errors="replace") as f:
            content = f.read()
    except OSError:
        return set()
    added = set()
    for line in content.split("\n"):
        if line.startswith("+") and not line.startswith("+++"):
            stripped = line[1:].strip()
            if len(stripped) > 8:
                added.add(stripped)
    return added


def blame_conflicting_patches(
    conflict_blocks: List[List[List[str]]], applied_patches: List[str]
) -> List[str]:
    """Names applied patches whose own additions appear on our side of a conflict."""
    ours_lines = {
        line.strip() for block in conflict_blocks for line in block[0] if line.strip()
    }
    culprits = []
    for candidate in applied_patches:
        if _patch_added_lines(candidate) & ours_lines:
            culprits.append(patch_display_name(candidate))
    return culprits


def patch_display_name(patch_path: str) -> str:
    """The patch's directory name, which is how users refer to it."""
    parent = os.path.basename(os.path.dirname(os.path.abspath(patch_path)))
    if parent and parent not in ("patches", ".", ""):
        return parent
    return os.path.basename(patch_path)


def format_conflict_report(
    rel_target: str,
    patch_path: str,
    conflict_blocks: List[List[List[str]]],
    applied_patches: List[str],
) -> str:
    """Builds the message shown when a patch cannot be merged automatically."""
    name = patch_display_name(patch_path)
    culprits = blame_conflicting_patches(conflict_blocks, applied_patches)
    lines = []
    if culprits:
        lines.append(
            f"error: cannot combine patch '{name}' with {', '.join(culprits)}"
        )
    else:
        lines.append(f"error: cannot apply patch '{name}' to the patched tree")
    lines.append(
        f"  {len(conflict_blocks)} region(s) of {rel_target} are rewritten "
        f"differently by '{name}' and a patch already applied, so there is no "
        "mechanical merge."
    )
    ours, base, theirs = conflict_blocks[0]
    lines.append("  the first one is:")
    lines.append("    --- already in the tree ---")
    lines.extend(f"    {line}" for line in ours[:8])
    lines.append(f"    --- as '{name}' wants it ---")
    lines.extend(f"    {line}" for line in theirs[:8])
    lines.append(
        "  drop one of the conflicting patches, or supply a pre-merged patch "
        "of your own instead."
    )
    return "\n".join(lines)


def three_way_merge_file(
    rel_target: str,
    patch_path: str,
    pristine_tree: str,
    applied_patches: List[str],
    target_dir: str,
) -> Tuple[bool, bool]:
    """Merges `patch_path`'s `rel_target` changes in against the nearest ancestor.

    Returns (merged, explained); `explained` means the failure was already
    reported in detail, so the caller should not add a generic message.
    """
    ours = os.path.join(target_dir, rel_target)
    if not os.path.exists(ours):
        return False, False

    trees = build_ancestor_and_theirs(patch_path, pristine_tree, applied_patches)
    if trees is None:
        return False, False
    base_tree, theirs_tree = trees
    try:
        base = os.path.join(base_tree, rel_target)
        theirs = os.path.join(theirs_tree, rel_target)
        if not (os.path.exists(base) and os.path.exists(theirs)):
            return False, False
        res = subprocess.run(
            ["diff3", "-m", ours, base, theirs], capture_output=True, text=True
        )
        # diff3 exits 1 when it emitted conflict markers, 2 on trouble.
        if res.returncode > 1:
            return False, False
        merged = res.stdout
        if "<<<<<<<" in merged:
            unresolved: List[List[List[str]]] = []
            resolved = resolve_conflict_markers(merged, unresolved)
            if resolved is None:
                if unresolved:
                    print(
                        format_conflict_report(
                            rel_target, patch_path, unresolved, applied_patches
                        ),
                        file=sys.stderr,
                    )
                    return False, True
                return False, False
            merged = resolved
        with open(ours, "w", encoding="utf-8") as f:
            f.write(merged)
        print(f"note: three-way merged {rel_target} for {patch_display_name(patch_path)}")
        return True, False
    finally:
        shutil.rmtree(os.path.dirname(base_tree), ignore_errors=True)
        shutil.rmtree(os.path.dirname(theirs_tree), ignore_errors=True)
