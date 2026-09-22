"""Applying one patch, falling back through the reconcilers as needed."""

import os
import re
import subprocess
import sys
from typing import Dict, List, Optional, Tuple

from .configmerge import (
    merge_keys_array,
    merge_layouts_array,
    merge_rules_array,
    merge_top_level_declarations,
)
from .csource import (
    find_matching_brace,
    locate_struct_definition,
    parse_existing_members,
    strip_comments_and_strings,
)
from .diffs import normalize_patch_paths, parse_patch_content
from .reconcile import (
    apply_patch_direct,
    apply_patch_file_direct,
    apply_pure_addition_hunk,
    extract_declarations_from_hunk,
    reconcile_c_struct_hunk,
    reconcile_dwl_c_drawbar_hunk,
    reconcile_dwl_c_enum_hunk,
    reconcile_dwl_c_macro_hunk,
    try_patch_dry_run,
    try_patch_file_dry_run,
)
from .threeway import patch_display_name, three_way_merge_file


def apply_single_patch_file(
    patch_path: str,
    channel: str = "main",
    target_dir: str = ".",
    is_single: bool = False,
    pristine_tree: Optional[str] = None,
    applied_patches: Optional[List[str]] = None,
) -> None:
    """Applies one patch, falling back from plain `patch` to the reconcilers."""
    print(f"applying {patch_path}")
    with open(patch_path, "r", encoding="utf-8", errors="replace") as f:
        raw_content = f.read()

    normalized = normalize_patch_paths(raw_content, target_dir)

    # Fast path 0: direct raw patch application (exact byte-for-byte upstream Codeberg parity)
    if try_patch_file_dry_run(patch_path, target_dir=target_dir):
        if apply_patch_file_direct(patch_path, target_dir=target_dir):
            return

    # Fast path 1: normalized patch with default patch -p1
    cmd_dry = ["patch", "-p1", "-f", "-s", "--dry-run"]
    res = subprocess.run(cmd_dry, input=normalized, text=True, cwd=target_dir, capture_output=True)
    if res.returncode == 0:
        cmd_apply = ["patch", "-p1", "-f", "-s"]
        res_apply = subprocess.run(cmd_apply, input=normalized, text=True, cwd=target_dir, capture_output=True)
        if res_apply.returncode == 0:
            return

    # Fast path 2: patch -p1 -F3
    if is_single:
        if try_patch_dry_run(normalized, fuzz=3, target_dir=target_dir):
            if apply_patch_direct(normalized, fuzz=3, target_dir=target_dir):
                return
    else:
        touches_config = "config.def.h" in normalized or "config.h" in normalized
        if not touches_config and try_patch_dry_run(normalized, fuzz=3, target_dir=target_dir):
            if apply_patch_direct(normalized, fuzz=3, target_dir=target_dir):
                return

    # Conflict path: parse into file diffs
    file_diffs = parse_patch_content(normalized)
    if not file_diffs:
        apply_patch_direct(normalized, fuzz=3, target_dir=target_dir)
        sys.exit(1)

    # 1. Process all non-config files first (dwl.c, drwl.h, etc.)
    for fd in file_diffs:
        rel_target = fd.target_file()
        if rel_target in ("config.def.h", "config.h"):
            continue

        file_path = os.path.join(target_dir, rel_target)
        if not os.path.exists(file_path):
            apply_patch_direct(fd.to_patch_string(), fuzz=3, target_dir=target_dir)
            continue

        fd_patch = fd.to_patch_string()
        if try_patch_dry_run(fd_patch, fuzz=0, target_dir=target_dir):
            apply_patch_direct(fd_patch, fuzz=0, target_dir=target_dir)
            continue
        elif try_patch_dry_run(fd_patch, fuzz=3, target_dir=target_dir):
            apply_patch_direct(fd_patch, fuzz=3, target_dir=target_dir)
            continue

        with open(file_path, "r", encoding="utf-8", errors="replace") as f:
            file_code = f.read()
        code_before_hunks = file_code

        for hunk in fd.hunks:
            hunk_patch = hunk.to_patch_string(rel_target)
            if try_patch_dry_run(hunk_patch, fuzz=0, target_dir=target_dir):
                apply_patch_direct(hunk_patch, fuzz=0, target_dir=target_dir)
                with open(file_path, "r", encoding="utf-8", errors="replace") as f:
                    file_code = f.read()
            else:
                # A. Struct reconciliation
                updated_code, handled = reconcile_c_struct_hunk(file_code, hunk)
                if handled:
                    with open(file_path, "w", encoding="utf-8") as f:
                        f.write(updated_code)
                    file_code = updated_code
                    continue

                # B. Enum reconciliation (e.g. SchemeHid)
                updated_code, handled = reconcile_dwl_c_enum_hunk(file_code, hunk)
                if handled:
                    with open(file_path, "w", encoding="utf-8") as f:
                        f.write(updated_code)
                    file_code = updated_code
                    continue

                # C. Macro reconciliation (e.g. VISIBLEON / BORDERPX)
                updated_code, handled = reconcile_dwl_c_macro_hunk(file_code, hunk)
                if handled:
                    with open(file_path, "w", encoding="utf-8") as f:
                        f.write(updated_code)
                    file_code = updated_code
                    continue

                # C. Drawbar title reconciliation (e.g. awesomebar / bartruecenteredtitle / bar-notitle)
                updated_code, handled = reconcile_dwl_c_drawbar_hunk(file_code, hunk, target_dir=target_dir)
                if handled:
                    with open(file_path, "w", encoding="utf-8") as f:
                        f.write(updated_code)
                    file_code = updated_code
                    continue

                # D. Pure addition hunk anchoring (e.g. forward declarations)
                updated_code, handled = apply_pure_addition_hunk(file_code, hunk)
                if handled:
                    with open(file_path, "w", encoding="utf-8") as f:
                        f.write(updated_code)
                    file_code = updated_code
                    continue

                # E. Try fuzz=3 only after semantic AST reconcilers
                if try_patch_dry_run(hunk_patch, fuzz=3, target_dir=target_dir):
                    apply_patch_direct(hunk_patch, fuzz=3, target_dir=target_dir)
                    with open(file_path, "r", encoding="utf-8", errors="replace") as f:
                        file_code = f.read()
                    continue

                # F. Scope-bounded / fuzzy line replacement
                old_block = "\n".join(hunk.old_lines)
                new_block = "\n".join(hunk.new_lines)
                if file_code.count(old_block) == 1:
                    file_code = file_code.replace(old_block, new_block, 1)
                    with open(file_path, "w", encoding="utf-8") as f:
                        f.write(file_code)
                    print(f"note: applied hunk with exact context replacement in {rel_target}")
                else:
                    # The per-hunk reconcilers cannot place this hunk. Rewind the
                    # file and let a three-way merge against the pristine source
                    # reconcile the whole patch at once.
                    if pristine_tree is not None:
                        with open(file_path, "w", encoding="utf-8") as f:
                            f.write(code_before_hunks)
                        merged, explained = three_way_merge_file(
                            rel_target, patch_path, pristine_tree,
                            applied_patches or [], target_dir,
                        )
                        if merged:
                            break
                        if explained:
                            sys.exit(1)
                    print(
                        f"error: unresolvable conflict in {rel_target} for patch "
                        f"{patch_display_name(patch_path)}",
                        file=sys.stderr,
                    )
                    print(hunk_patch, file=sys.stderr)
                    sys.exit(1)

    # 2. Process config.def.h / config.h
    for fd in file_diffs:
        rel_target = fd.target_file()
        if rel_target not in ("config.def.h", "config.h"):
            continue

        config_path = os.path.join(target_dir, "config.def.h")
        if not os.path.exists(config_path):
            config_path = os.path.join(target_dir, "config.h")
        if not os.path.exists(config_path):
            continue

        fd_patch = fd.to_patch_string()
        if try_patch_dry_run(fd_patch, fuzz=0, target_dir=target_dir):
            apply_patch_direct(fd_patch, fuzz=0, target_dir=target_dir)
            continue

        with open(config_path, "r", encoding="utf-8", errors="replace") as f:
            config_code = f.read()

        pending_layouts: List[Tuple[str, str]] = []
        pending_keys: List[str] = []
        pending_rules: List[str] = []
        pending_decls: List[str] = []

        for hunk in fd.hunks:
            hunk_patch = hunk.to_patch_string(os.path.basename(config_path))
            if try_patch_dry_run(hunk_patch, fuzz=0, target_dir=target_dir):
                apply_patch_direct(hunk_patch, fuzz=0, target_dir=target_dir)
                with open(config_path, "r", encoding="utf-8", errors="replace") as f:
                    config_code = f.read()
            else:
                l, k, r, d = extract_declarations_from_hunk(hunk)
                pending_layouts.extend(l)
                pending_keys.extend(k)
                pending_rules.extend(r)
                pending_decls.extend(d)

        layout_map: Dict[str, int] = {}
        if pending_layouts:
            config_code, layout_map = merge_layouts_array(config_code, [f'{{ "{sym}", {fn} }}' for sym, fn in pending_layouts])
            print(f"note: merged layouts {list(layout_map.keys())} into layouts[] array")

        if pending_keys:
            config_code = merge_keys_array(config_code, pending_keys, layout_map)
            print("note: merged keybindings into keys[] array")

        dwl_c_path = os.path.join(target_dir, "dwl.c")
        rule_fields = ["id", "title", "tags", "isfloating", "monitor"]
        if os.path.exists(dwl_c_path):
            with open(dwl_c_path, "r", encoding="utf-8", errors="replace") as f:
                r_loc = locate_struct_definition(f.read(), "Rule")
                if r_loc:
                    rule_fields = list(parse_existing_members(r_loc.raw_body))

        if pending_rules:
            config_code = merge_rules_array(config_code, pending_rules, rule_fields)
            print("note: merged rules into rules[] array with designated initializers")

        if pending_decls:
            config_code = merge_top_level_declarations(config_code, pending_decls)
            print("note: merged top-level declarations into config.def.h")

        with open(config_path, "w", encoding="utf-8") as f:
            f.write(config_code)

LAYOUT_KEYS = {
    "centeredmaster": "XKB_KEY_c",
    "gaplessgrid": "XKB_KEY_g",
    "deck": "XKB_KEY_a",
    "bstack": "XKB_KEY_u",
    "bstackhoriz": "XKB_KEY_o",
    "btrtile": "XKB_KEY_r",
    "dwindle": "XKB_KEY_d",
    "spiral": "XKB_KEY_s",
    "snail": "XKB_KEY_s",
    "stairs": "XKB_KEY_s",
    "tile": "XKB_KEY_t",
    "monocle": "XKB_KEY_m",
}

def reconcile_layout_keybindings(target_dir: str = ".") -> None:
    """
    Ensures that layout keybindings in keys[] point to the exact index of their
    corresponding arrange function in layouts[].
    """
    config_path = os.path.join(target_dir, "config.def.h")
    if not os.path.exists(config_path):
        config_path = os.path.join(target_dir, "config.h")
    if not os.path.exists(config_path):
        return

    with open(config_path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()

    clean = strip_comments_and_strings(content)
    match_layouts = re.search(r'\bstatic\s+const\s+Layout\s+layouts\[\]\s*=\s*\{', clean)
    if not match_layouts:
        return

    open_pos = match_layouts.end() - 1
    close_pos = find_matching_brace(clean, open_pos)
    if close_pos == -1:
        return

    layouts_body = content[open_pos+1:close_pos]
    entries = re.findall(r'\{\s*"([^"]+)"\s*,\s*([a-zA-Z0-9_]+)\s*\}', layouts_body)
    custom_layouts = [func for _, func in entries if func not in ("tile", "NULL", "monocle")]
    if not custom_layouts:
        return

    func_to_index = {func: idx for idx, (_, func) in enumerate(entries)}

    match_keys = re.search(r'\bstatic\s+const\s+Key\s+keys\[\]\s*=\s*\{', clean)
    if not match_keys:
        return

    open_k = match_keys.end() - 1
    close_k = find_matching_brace(clean, open_k)
    if close_k == -1:
        return

    keys_body = content[open_k+1:close_k]
    lines = keys_body.splitlines()
    new_lines = []
    modified = False

    for line in lines:
        line_str = line.strip()
        if "setlayout" in line_str and "&layouts[" in line_str:
            key_match = re.search(r'XKB_KEY_([a-zA-Z0-9_]+)', line_str)
            if key_match:
                key_sym = f"XKB_KEY_{key_match.group(1)}"
                target_func = None
                for func, mapped_key in LAYOUT_KEYS.items():
                    if mapped_key == key_sym and func in func_to_index:
                        target_func = func
                        break
                if target_func:
                    idx = func_to_index[target_func]
                    new_line = re.sub(r'&layouts\[\d+\]', f'&layouts[{idx}]', line)
                    if new_line != line:
                        modified = True
                        line = new_line
        new_lines.append(line)

    if not modified:
        return

    new_keys_body = "\n".join(new_lines)
    if not new_keys_body.endswith("\n"):
        new_keys_body += "\n"

    content = content[:open_k+1] + "\n" + new_keys_body.lstrip("\n") + content[close_k:]
    with open(config_path, "w", encoding="utf-8") as f:
        f.write(content)
