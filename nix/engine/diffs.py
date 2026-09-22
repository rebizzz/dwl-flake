"""Parsing unified diffs into hunks we can reason about individually."""

import os
import re
from typing import List


class Hunk:
    def __init__(self, old_start: int, old_count: int, new_start: int, new_count: int, header: str, lines: List[str]):
        self.old_start = old_start
        self.old_count = old_count
        self.new_start = new_start
        self.new_count = new_count
        self.header = header
        self.lines = lines

    @property
    def added_lines(self) -> List[str]:
        return [line[1:] for line in self.lines if line.startswith('+') and not line.startswith('+++')]

    @property
    def removed_lines(self) -> List[str]:
        return [line[1:] for line in self.lines if line.startswith('-') and not line.startswith('---')]

    @property
    def context_lines(self) -> List[str]:
        return [line[1:] for line in self.lines if line.startswith(' ')]

    @property
    def old_lines(self) -> List[str]:
        return [line[1:] for line in self.lines if line.startswith(' ') or line.startswith('-')]

    @property
    def new_lines(self) -> List[str]:
        return [line[1:] for line in self.lines if line.startswith(' ') or line.startswith('+')]

    def to_patch_string(self, file_path: str) -> str:
        header_text = f" {self.header.strip()}" if self.header.strip() else ""
        lines = [
            f"--- a/{file_path}",
            f"+++ b/{file_path}",
            f"@@ -{self.old_start},{self.old_count} +{self.new_start},{self.new_count} @@{header_text}"
        ]
        lines.extend(self.lines)
        return "\n".join(lines) + "\n"

class FileDiff:
    def __init__(self, old_path: str, new_path: str, headers: List[str], hunks: List[Hunk]):
        self.old_path = old_path
        self.new_path = new_path
        self.headers = headers
        self.hunks = hunks

    def target_file(self) -> str:
        path = self.new_path if self.new_path != "/dev/null" else self.old_path
        if path.startswith("a/") or path.startswith("b/"):
            return path[2:]
        return path

    def to_patch_string(self) -> str:
        out = list(self.headers)
        for h in self.hunks:
            header_text = f" {h.header.strip()}" if h.header.strip() else ""
            out.append(f"@@ -{h.old_start},{h.old_count} +{h.new_start},{h.new_count} @@{header_text}")
            out.extend(h.lines)
        return "\n".join(out) + "\n"

def parse_patch_content(patch_content: str) -> List[FileDiff]:
    """Parses unified diff text into a list of FileDiff objects."""
    file_diffs: List[FileDiff] = []
    lines = patch_content.splitlines()
    i = 0
    n = len(lines)

    while i < n:
        line = lines[i]
        if line.startswith("diff --git ") or line.startswith("--- "):
            headers = []
            old_path = ""
            new_path = ""
            while i < n and not lines[i].startswith("@@ "):
                cur = lines[i]
                headers.append(cur)
                if cur.startswith("--- "):
                    parts = cur.split()
                    if len(parts) >= 2:
                        old_path = parts[1]
                elif cur.startswith("+++ "):
                    parts = cur.split()
                    if len(parts) >= 2:
                        new_path = parts[1]
                i += 1

            hunks: List[Hunk] = []
            while i < n and lines[i].startswith("@@ "):
                hunk_line = lines[i]
                hunk_match = re.match(r'^@@\s+-(\d+)(?:,(\d+))?\s+\+(\d+)(?:,(\d+))?\s+@@(.*)$', hunk_line)
                if not hunk_match:
                    i += 1
                    continue
                old_start = int(hunk_match.group(1))
                old_count = int(hunk_match.group(2)) if hunk_match.group(2) else 1
                new_start = int(hunk_match.group(3))
                new_count = int(hunk_match.group(4)) if hunk_match.group(4) else 1
                header = hunk_match.group(5) or ""

                i += 1
                hunk_lines = []
                while i < n:
                    cur = lines[i]
                    if cur.startswith("@@ ") or cur.startswith("diff --git ") or (cur.startswith("--- ") and i + 1 < n and lines[i+1].startswith("+++ ")):
                        break
                    if cur.startswith("From ") or cur.startswith("-- "):
                        break
                    if not (cur.startswith(" ") or cur.startswith("+") or cur.startswith("-") or cur.startswith("\\")):
                        if cur == "" and (i + 1 == n or lines[i+1].startswith("From ") or lines[i+1].startswith("diff --git ") or lines[i+1].startswith("@@ ")):
                            break
                    hunk_lines.append(cur)
                    i += 1

                hunks.append(Hunk(old_start, old_count, new_start, new_count, header, hunk_lines))

            file_diffs.append(FileDiff(old_path, new_path, headers, hunks))
        else:
            i += 1

    return file_diffs

# ==============================================================================
# Stage 1: Path Normalization
# ==============================================================================

def normalize_patch_paths(content: str, target_dir: str = ".") -> str:
    """
    Normalizes patch paths (e.g. config.h -> config.def.h) and CRLF line endings.
    """
    content = content.replace("\r\n", "\n")

    has_config_h = os.path.exists(os.path.join(target_dir, "config.h"))
    has_config_def_h = os.path.exists(os.path.join(target_dir, "config.def.h"))

    if not has_config_h and has_config_def_h:
        content = re.sub(r'^(---|\+\+\+)\s+([ab]/)?config\.h\b', r'\1 \2config.def.h', content, flags=re.MULTILINE)
        content = re.sub(r'^(diff --git\s+[ab]/config\.h\s+[ab]/)config\.h\b', r'\1config.def.h', content, flags=re.MULTILINE)
        content = re.sub(r'^(diff --git\s+[ab]/)config\.h(\s+[ab]/config\.def\.h\b)', r'\1config.def.h\2', content, flags=re.MULTILINE)

    return content
