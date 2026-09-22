#!/usr/bin/env python3
"""
Intelligent Conflict Resolution Engine for dwl-flake.
Reconciles C-level diffs, merges config.def.h declarations and arrays,
bridges tag macros dynamically, and handles AST struct extensions.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from typing import Optional, List, Tuple, Dict, Set

# ==============================================================================
# Architectural Ranking & Topological Ordering
# ==============================================================================

def get_patch_rank(patch_path: str) -> int:
    """
    Returns architectural phase rank for a patch file.
    Lower rank = applied earlier.
    """
    basename = os.path.basename(patch_path).lower()
    stem = re.sub(r'(\.patch|-v?[0-9].*|\.diff)$', '', basename)
    parent = os.path.basename(os.path.dirname(os.path.abspath(patch_path))).lower()
    name = parent if parent not in ("patches", ".", "") else stem

    # Rank 0: Base Foundation
    if name == "bar" or stem == "bar":
        return 0
    # Rank 10: Base Addons
    elif any(k in (name, stem) for k in (
        "awesomebar", "notitle", "barborder", "barcolors", "barconfig",
        "barpadding", "bartruecenteredtitle", "hide_vacant_tags", "zerotag"
    )):
        return 10
    # Rank 20: Window Geometry & Gaps
    elif any(k in (name, stem) for k in (
        "vanitygaps", "genericgaps", "borders", "smartborders", "simpleborders"
    )):
        return 20
    # Rank 30: Custom Layout Engines
    elif any(k in (name, stem) for k in (
        "bottomstack", "centeredmaster", "decklayout", "gaplessgrid",
        "btrtile", "dwindle", "snail"
    )):
        return 30
    # Rank 40: Stack Manipulation
    elif any(k in (name, stem) for k in (
        "movestack", "attachbottom", "attachtop", "attachfocused", "customfloat",
        "focusonurgent", "follow", "zoomswap", "swapfocus", "swapandfocusdir"
    )):
        return 40
    # Rank 50: Tagging & State Wrappers
    elif any(k in (name, stem) for k in (
        "pertag", "shifttag", "shiftview", "reorganizetags", "singletagset", "rotatetags"
    )):
        return 50
    # Rank 60: Startup & System Integrations
    elif any(k in (name, stem) for k in (
        "autostart", "setupenv", "systemd", "ipc", "kblayout"
    )):
        return 60
    return 70

def sort_patches(patch_paths: List[str]) -> List[str]:
    """Sorts patch file paths by architectural rank (stable sort)."""
    return sorted(patch_paths, key=get_patch_rank)

# ==============================================================================
# C Lexer, Comment Stripper & AST Helpers
# ==============================================================================

def strip_comments_and_strings(text: str) -> str:
    """
    Replaces C comments and string/char literals with whitespace of identical length,
    preserving exact byte/character offsets for AST insertions.
    """
    chars = list(text)
    n = len(chars)
    i = 0
    while i < n:
        if i + 1 < n and chars[i] == '/' and chars[i+1] == '*':
            chars[i] = ' '
            chars[i+1] = ' '
            j = i + 2
            while j + 1 < n and not (chars[j] == '*' and chars[j+1] == '/'):
                if chars[j] != '\n':
                    chars[j] = ' '
                j += 1
            if j + 1 < n:
                chars[j] = ' '
                chars[j+1] = ' '
                i = j + 2
            else:
                i = n
        elif i + 1 < n and chars[i] == '/' and chars[i+1] == '/':
            chars[i] = ' '
            chars[i+1] = ' '
            j = i + 2
            while j < n and chars[j] != '\n':
                chars[j] = ' '
                j += 1
            i = j
        elif chars[i] == '"':
            chars[i] = ' '
            j = i + 1
            while j < n and chars[j] != '"':
                if chars[j] == '\\' and j + 1 < n:
                    chars[j] = ' '
                    j += 1
                if chars[j] != '\n':
                    chars[j] = ' '
                j += 1
            if j < n:
                chars[j] = ' '
                i = j + 1
            else:
                i = n
        elif chars[i] == "'":
            chars[i] = ' '
            j = i + 1
            while j < n and chars[j] != "'":
                if chars[j] == '\\' and j + 1 < n:
                    chars[j] = ' '
                    j += 1
                if chars[j] != '\n':
                    chars[j] = ' '
                j += 1
            if j < n:
                chars[j] = ' '
                i = j + 1
            else:
                i = n
        else:
            i += 1
    return "".join(chars)

def find_matching_brace(clean_text: str, open_brace_idx: int) -> int:
    """
    Given the index of an opening '{', returns the index of the matching '}'.
    """
    depth = 0
    for idx in range(open_brace_idx, len(clean_text)):
        char = clean_text[idx]
        if char == '{':
            depth += 1
        elif char == '}':
            depth -= 1
            if depth == 0:
                return idx
    return -1

class StructLocation:
    def __init__(self, name: str, start_pos: int, open_brace_pos: int, close_brace_pos: int, end_pos: int, raw_body: str):
        self.name = name
        self.start_pos = start_pos
        self.open_brace_pos = open_brace_pos
        self.close_brace_pos = close_brace_pos
        self.end_pos = end_pos
        self.raw_body = raw_body

def locate_struct_definition(c_code: str, struct_name: str) -> Optional[StructLocation]:
    """
    Locates struct declaration ('Client', 'Monitor', or 'Rule') in c_code.
    Handles both 'typedef struct { ... } Name;' and 'struct Name { ... };'.
    """
    clean = strip_comments_and_strings(c_code)
    patterns = [
        rf'\bstruct\s+{struct_name}\s*\{{',
        rf'\btypedef\s+struct(?:\s+[a-zA-Z0-9_]+)?\s*\{{'
    ]
    for pat in patterns:
        for match in re.finditer(pat, clean):
            open_pos = match.end() - 1
            close_pos = find_matching_brace(clean, open_pos)
            if close_pos == -1:
                continue
            after_brace = clean[close_pos+1:close_pos+120]
            if re.match(rf'^\s*{struct_name}\s*;', after_brace) or (
                struct_name in match.group(0) and re.match(r'^\s*;', after_brace)
            ):
                end_pos = close_pos + 1 + after_brace.find(';') + 1
                raw_body = c_code[open_pos+1:close_pos]
                return StructLocation(struct_name, match.start(), open_pos, close_pos, end_pos, raw_body)
    return None

def extract_member_names(decl_stmt: str) -> List[str]:
    """
    Parses a single C struct member declaration statement (ending in ';')
    and extracts the bare member identifier names.
    """
    stmt = re.sub(r'/\*.*?\*/', '', decl_stmt, flags=re.DOTALL)
    stmt = re.sub(r'//.*$', '', stmt, flags=re.MULTILINE).strip()
    if not stmt or not stmt.endswith(';'):
        return []
    stmt = stmt[:-1].strip()

    # Case 1: Nested union/struct
    nested_match = re.search(r'\}\s*([a-zA-Z_][a-zA-Z0-9_]*)(?:\s*\[[^\]]*\])*\s*$', stmt)
    if nested_match:
        return [nested_match.group(1)]

    # Case 2: Function pointer
    fn_match = re.search(r'\(\s*\*\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\)\s*\(', stmt)
    if fn_match:
        return [fn_match.group(1)]

    # Case 3: Standard declarations
    type_match = re.match(
        r'^(?:(?:const|volatile|static|unsigned|signed|struct\s+\w+|union\s+\w+|enum\s+\w+|\w+)\s+)+[*]*\s*',
        stmt
    )
    if not type_match:
        return []
    declarators_part = stmt[type_match.end():]
    names = []
    for piece in declarators_part.split(','):
        piece = piece.strip()
        piece = re.sub(r':\s*\d+\s*$', '', piece).strip()
        piece = re.sub(r'\[[^\]]*\]', '', piece).strip()
        piece = piece.lstrip('*').strip()
        ident_match = re.search(r'\b([a-zA-Z_][a-zA-Z0-9_]*)$', piece)
        if ident_match:
            names.append(ident_match.group(1))
    return names

def parse_existing_members(body_text: str) -> Set[str]:
    """Returns set of all member identifiers currently declared in a struct body."""
    members = set()
    for stmt in body_text.split(';'):
        stmt = stmt.strip()
        if stmt:
            for name in extract_member_names(stmt + ';'):
                members.add(name)
    return members

def insert_field_into_struct(c_code: str, struct_name: str, field_decl: str) -> str:
    """
    Inserts field_decl immediately preceding the closing brace '}' of struct_name in c_code.
    Deduplicates members: if all members exist, no change is made.
    """
    loc = locate_struct_definition(c_code, struct_name)
    if not loc:
        return c_code

    existing = parse_existing_members(loc.raw_body)
    incoming_names = extract_member_names(field_decl)
    if not incoming_names:
        return c_code

    new_names = [name for name in incoming_names if name not in existing]
    if not new_names:
        return c_code

    decl_to_insert = field_decl.strip()
    if len(new_names) < len(incoming_names):
        type_prefix_match = re.match(r'^(.*?)\s*[*]*\s*' + re.escape(incoming_names[0]), decl_to_insert)
        if type_prefix_match:
            base_type = type_prefix_match.group(1).strip()
            decl_to_insert = f"{base_type} {', '.join(new_names)};"

    if not decl_to_insert.startswith('\t'):
        decl_to_insert = '\t' + decl_to_insert
    if not decl_to_insert.endswith('\n'):
        decl_to_insert += '\n'

    insert_idx = loc.close_brace_pos
    prefix = c_code[:insert_idx]
    suffix = c_code[insert_idx:]
    if not prefix.endswith('\n'):
        decl_to_insert = '\n' + decl_to_insert

    return prefix + decl_to_insert + suffix

def is_symbol_declared(name: str, c_code: str) -> bool:
    """
    Checks whether a macro, variable, array, or struct is declared in C code,
    preventing false matches inside comments or strings.
    """
    clean = strip_comments_and_strings(c_code)
    escaped_name = re.escape(name)
    if re.search(rf'^\s*#\s*define\s+{escaped_name}\b', clean, re.MULTILINE):
        return True
    decl_pattern = rf'(?:^|;|\{{|\}})\s*(?:static\s+|const\s+|unsigned\s+|signed\s+|extern\s+|typedef\s+|struct\s+|enum\s+|\w+\s+)+(?:\*+\s*)*\b{escaped_name}\b\s*(?:\[|;|=|,\s*\w)'
    if re.search(decl_pattern, clean, re.MULTILINE):
        return True
    return False

# ==============================================================================
# Diff and Hunk Parser
# ==============================================================================

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
                while i < n and not lines[i].startswith("@@ ") and not lines[i].startswith("diff --git ") and not (lines[i].startswith("--- ") and i + 1 < n and lines[i+1].startswith("+++ ")):
                    hunk_lines.append(lines[i])
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

# ==============================================================================
# Stage 4 & 5: config.def.h Reconciler (Arrays, Rules, Decls)
# ==============================================================================

def merge_layouts_array(config_h: str, added_lines: List[str]) -> Tuple[str, Dict[str, int]]:
    """
    Extracts new layouts from added_lines, appends them before the closing '};'
    of layouts[] in config.def.h, and returns updated text and a mapping of
    layout function name -> new array index.
    """
    clean = strip_comments_and_strings(config_h)
    match = re.search(r'\bstatic\s+const\s+Layout\s+layouts\[\]\s*=\s*\{', clean)
    if not match:
        return config_h, {}

    open_pos = match.end() - 1
    close_pos = find_matching_brace(clean, open_pos)
    if close_pos == -1:
        return config_h, {}

    body = config_h[open_pos+1:close_pos]
    existing_entries = re.findall(r'\{\s*"([^"]+)"\s*,\s*([a-zA-Z0-9_]+)\s*\}', body)
    existing_funcs = {func for _, func in existing_entries}
    current_index = len(existing_entries)

    layout_index_map: Dict[str, int] = {}
    new_entries_text = ""

    for line in added_lines:
        entries = re.findall(r'\{\s*"([^"]+)"\s*,\s*([a-zA-Z0-9_]+)\s*\}', line)
        for symbol, func in entries:
            if func not in existing_funcs:
                existing_funcs.add(func)
                layout_index_map[func] = current_index
                new_entries_text += f'\t{{ "{symbol}",      {func} }},\n'
                current_index += 1

    if not new_entries_text:
        return config_h, layout_index_map

    prefix = config_h[:close_pos]
    suffix = config_h[close_pos:]
    if not prefix.endswith('\n'):
        new_entries_text = '\n' + new_entries_text

    return prefix + new_entries_text + suffix, layout_index_map

def merge_keys_array(config_h: str, added_lines: List[str], layout_map: Dict[str, int]) -> str:
    """
    Appends non-duplicate keybindings into keys[] before the closing '};'.
    Remaps &layouts[N] to the actual layout index assigned in layout_map.
    """
    clean = strip_comments_and_strings(config_h)
    match = re.search(r'\bstatic\s+const\s+Key\s+keys\[\]\s*=\s*\{', clean)
    if not match:
        return config_h

    open_pos = match.end() - 1
    close_pos = find_matching_brace(clean, open_pos)
    if close_pos == -1:
        return config_h

    keys_body = config_h[open_pos+1:close_pos]
    new_keys_text = ""

    layout_indices = list(layout_map.values())

    for line in added_lines:
        line_clean = line.strip()
        if not (line_clean.startswith('{') and 'XKB_KEY_' in line_clean):
            continue

        if 'setlayout' in line_clean and '&layouts[' in line_clean and layout_indices:
            idx_match = re.search(r'&layouts\[(\d+)\]', line_clean)
            if idx_match:
                orig_idx = int(idx_match.group(1))
                rel = orig_idx - 3
                if 0 <= rel < len(layout_indices):
                    target_idx = layout_indices[rel]
                else:
                    target_idx = layout_indices[0]
                line_clean = re.sub(r'&layouts\[\d+\]', f'&layouts[{target_idx}]', line_clean)

        if line_clean in keys_body:
            continue

        if not line_clean.endswith(','):
            line_clean += ','
        new_keys_text += f"\t{line_clean}\n"

    if not new_keys_text:
        return config_h

    prefix = config_h[:close_pos]
    suffix = config_h[close_pos:]
    if not prefix.endswith('\n'):
        new_keys_text = '\n' + new_keys_text

    return prefix + new_keys_text + suffix

def convert_rule_to_designated(entry_text: str, rule_fields: List[str]) -> str:
    """
    Converts a positional rule '{ "app", NULL, 0, 1, -1 }'
    into C99 designated initializer:
    '{ .id = "app", .title = NULL, .tags = 0, .isfloating = 1, .monitor = -1 }'
    """
    entry_clean = entry_text.strip().lstrip('{').rstrip('},;').strip()
    tokens = []
    current = []
    in_quote = False
    for c in entry_clean:
        if c == '"':
            in_quote = not in_quote
            current.append(c)
        elif c == ',' and not in_quote:
            tokens.append("".join(current).strip())
            current = []
        else:
            current.append(c)
    if current:
        tokens.append("".join(current).strip())

    if not tokens:
        return entry_text

    if any(tok.startswith('.') for tok in tokens):
        joined = ", ".join(tokens)
        return f"\t{{ {joined} }},"

    field_map = {}
    num_toks = len(tokens)
    if num_toks == 5:
        field_map['id'] = tokens[0]
        field_map['title'] = tokens[1]
        field_map['tags'] = tokens[2]
        field_map['isfloating'] = tokens[3]
        field_map['monitor'] = tokens[4]
    elif num_toks > 5:
        field_map['id'] = tokens[0]
        field_map['title'] = tokens[1]
        field_map['tags'] = tokens[2]
        field_map['isfloating'] = tokens[3]
        field_map['monitor'] = tokens[-1]
        extra_fields = [f for f in rule_fields if f not in ('id', 'title', 'tags', 'isfloating', 'monitor')]
        for i, extra_tok in enumerate(tokens[4:-1]):
            if i < len(extra_fields):
                field_map[extra_fields[i]] = extra_tok

    designated_parts = [f".{k} = {v}" for k, v in field_map.items()]
    joined = ", ".join(designated_parts)
    return f"\t{{ {joined} }},"

def convert_all_rules_to_designated(config_h: str, rule_fields: List[str]) -> str:
    """Converts all entries in rules[] array to designated initializers."""
    clean = strip_comments_and_strings(config_h)
    match = re.search(r'\bstatic\s+const\s+Rule\s+rules\[\]\s*=\s*\{', clean)
    if not match:
        return config_h

    open_pos = match.end() - 1
    close_pos = find_matching_brace(clean, open_pos)
    if close_pos == -1:
        return config_h

    body = config_h[open_pos+1:close_pos]
    lines = body.splitlines()
    new_lines = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith('{') and (stripped.endswith('},') or stripped.endswith('}')):
            new_lines.append(convert_rule_to_designated(stripped, rule_fields))
        else:
            new_lines.append(line)

    new_body = "\n".join(new_lines)
    if new_body and not new_body.endswith('\n'):
        new_body += '\n'
    return config_h[:open_pos+1] + new_body + config_h[close_pos:]

def merge_rules_array(config_h: str, added_lines: List[str], rule_fields: List[str]) -> str:
    """Appends new rules to rules[] before closing '};'."""
    clean = strip_comments_and_strings(config_h)
    match = re.search(r'\bstatic\s+const\s+Rule\s+rules\[\]\s*=\s*\{', clean)
    if not match:
        return config_h

    open_pos = match.end() - 1
    close_pos = find_matching_brace(clean, open_pos)
    if close_pos == -1:
        return config_h

    body = config_h[open_pos+1:close_pos]
    new_rules_text = ""

    for line in added_lines:
        line_clean = line.strip()
        if line_clean.startswith('{') and (line_clean.endswith('},') or line_clean.endswith('}')):
            designated = convert_rule_to_designated(line_clean, rule_fields)
            if designated.strip() in body:
                continue
            new_rules_text += f"{designated}\n"

    if not new_rules_text:
        return config_h

    prefix = config_h[:close_pos]
    suffix = config_h[close_pos:]
    if not prefix.endswith('\n'):
        new_rules_text = '\n' + new_rules_text

    return prefix + new_rules_text + suffix

def merge_top_level_declarations(config_h: str, added_blocks: List[str]) -> str:
    """
    Extracts top-level '#define' macros and 'static' definitions from rejected hunks,
    extracts the clean symbol name (avoiding bracket regex bugs like colors[][3]),
    and appends them if not already declared.
    """
    clean_config = strip_comments_and_strings(config_h)
    new_decls = []

    for block in added_blocks:
        block_clean = block.strip()
        if not block_clean:
            continue

        # Case A: #define MACRO
        macro_match = re.match(r'^#\s*define\s+([a-zA-Z0-9_]+)\b', block_clean)
        if macro_match:
            symbol = macro_match.group(1)
            if not is_symbol_declared(symbol, config_h):
                new_decls.append(block_clean)
            continue

        # Case B: static [const] type [*]name [bracket]* = ...
        static_match = re.match(
            r'^static\s+(?:const\s+)?(?:unsigned\s+|signed\s+)?(?:struct\s+\w+\s+|enum\s+\w+\s+|\w+)\s*[*]*\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*(?:\[[^\]]*\])*\s*=',
            block_clean
        )
        if static_match:
            symbol = static_match.group(1)
            if not is_symbol_declared(symbol, config_h):
                new_decls.append(block_clean)
            continue

    if not new_decls:
        return config_h

    insert_block = "\n/* Declarations merged by conflict-engine */\n" + "\n\n".join(new_decls) + "\n"
    return config_h + insert_block

# ==============================================================================
# Stage 6: Dynamic Tag Macro Bridge
# ==============================================================================

def reconcile_tag_macros(target_dir: str = ".") -> None:
    """
    Dynamically bridges TAGCOUNT and LENGTH(tags) only when dwl.c references
    TAGCOUNT while it is undefined, ensuring single-patch derivations remain
    100% clean and identical to Codeberg upstream hand-patching.
    """
    dwl_c_path = os.path.join(target_dir, "dwl.c")
    config_def_path = os.path.join(target_dir, "config.def.h")
    if not os.path.exists(config_def_path):
        config_def_path = os.path.join(target_dir, "config.h")

    if not os.path.exists(dwl_c_path) or not os.path.exists(config_def_path):
        return

    with open(dwl_c_path, "r", encoding="utf-8", errors="replace") as f:
        dwl_c = f.read()

    with open(config_def_path, "r", encoding="utf-8", errors="replace") as f:
        config_def = f.read()

    uses_tagcount = bool(re.search(r'\bTAGCOUNT\b', dwl_c))
    defs_tagcount = bool(
        re.search(r'#\s*define\s+TAGCOUNT\b', config_def) or
        re.search(r'#\s*define\s+TAGCOUNT\b', dwl_c)
    )
    has_tags_array = bool(
        re.search(r'\btags\s*\[', config_def) or
        re.search(r'\btags\s*\[', dwl_c) or
        re.search(r'\*tags\s*\[', config_def)
    )

    if uses_tagcount and not defs_tagcount:
        if has_tags_array:
            bridge = (
                "\n/* Dynamic Tag Macro Bridge: map TAGCOUNT to LENGTH(tags) */\n"
                "#ifndef TAGCOUNT\n"
                "#define TAGCOUNT LENGTH(tags)\n"
                "#endif\n"
            )
            inc_pattern = r'(#include\s+["<]config\.h[">])'
            if re.search(inc_pattern, dwl_c):
                dwl_c = re.sub(inc_pattern, r'\1' + bridge, dwl_c, count=1)
                with open(dwl_c_path, "w", encoding="utf-8") as f:
                    f.write(dwl_c)
                print("note: dynamically bridged TAGCOUNT -> LENGTH(tags) in dwl.c")
            else:
                with open(config_def_path, "a", encoding="utf-8") as f:
                    f.write("\n#ifndef TAGCOUNT\n#define TAGCOUNT LENGTH(tags)\n#endif\n")
                print("note: dynamically bridged TAGCOUNT -> LENGTH(tags) in config.def.h")
        else:
            bridge = (
                "\n/* Dynamic Tag Macro Bridge: fallback TAGCOUNT declaration */\n"
                "#ifndef TAGCOUNT\n"
                "#define TAGCOUNT 9\n"
                "#endif\n"
            )
            inc_pattern = r'(#include\s+["<]config\.h[">])'
            if re.search(inc_pattern, dwl_c):
                dwl_c = re.sub(inc_pattern, r'\1' + bridge, dwl_c, count=1)
                with open(dwl_c_path, "w", encoding="utf-8") as f:
                    f.write(dwl_c)
            else:
                with open(config_def_path, "a", encoding="utf-8") as f:
                    f.write(bridge)
            print("note: fallback defined TAGCOUNT as 9")

    uses_length_tags = bool(re.search(r'\bLENGTH\s*\(\s*tags\s*\)', dwl_c))
    uses_tags_index = bool(re.search(r'\btags\s*\[', dwl_c))

    if (uses_length_tags or uses_tags_index) and not has_tags_array:
        tags_decl = (
            "\n/* Dynamic Tag Macro Bridge: declare default tags[] */\n"
            "#ifndef LENGTH\n"
            "#define LENGTH(X) (sizeof(X) / sizeof(X)[0])\n"
            "#endif\n"
            "static char *tags[] = { \"1\", \"2\", \"3\", \"4\", \"5\", \"6\", \"7\", \"8\", \"9\" };\n"
        )
        inc_pattern = r'(#include\s+["<]config\.h[">])'
        if re.search(inc_pattern, dwl_c):
            dwl_c = re.sub(inc_pattern, r'\1' + tags_decl, dwl_c, count=1)
            with open(dwl_c_path, "w", encoding="utf-8") as f:
                f.write(dwl_c)
            print("note: dynamically declared default tags[] in dwl.c")

# ==============================================================================
# Patch Application & Hunk Reconciliation Engine
# ==============================================================================

def try_patch_file_dry_run(patch_path: str, target_dir: str = ".") -> bool:
    """Tests if raw patch applies cleanly via default patch -p1 -f -s."""
    cmd = ["patch", "-p1", "-f", "-s", "--dry-run"]
    with open(patch_path, "rb") as f:
        res = subprocess.run(cmd, stdin=f, cwd=target_dir, capture_output=True)
    return res.returncode == 0

def apply_patch_file_direct(patch_path: str, target_dir: str = ".") -> bool:
    """Applies raw patch directly via default patch -p1 -f -s."""
    cmd = ["patch", "-p1", "-f", "-s"]
    with open(patch_path, "rb") as f:
        res = subprocess.run(cmd, stdin=f, cwd=target_dir, capture_output=True)
    return res.returncode == 0

def try_patch_dry_run(patch_text: str, fuzz: int = 0, target_dir: str = ".") -> bool:
    """Tests if patch_text applies cleanly via patch -p1."""
    cmd = ["patch", "-p1", "-f", "-s", f"-F{fuzz}", "--dry-run"]
    res = subprocess.run(cmd, input=patch_text, text=True, cwd=target_dir, capture_output=True)
    return res.returncode == 0

def apply_patch_direct(patch_text: str, fuzz: int = 0, target_dir: str = ".") -> bool:
    """Applies patch_text via patch -p1."""
    cmd = ["patch", "-p1", "-f", "-s", f"-F{fuzz}"]
    res = subprocess.run(cmd, input=patch_text, text=True, cwd=target_dir, capture_output=True)
    return res.returncode == 0

def extract_declarations_from_hunk(hunk: Hunk) -> Tuple[List[Tuple[str, str]], List[str], List[str], List[str]]:
    """
    Parses added lines from a config.def.h hunk into:
    (layouts, keys, rules, top_level_decls)
    """
    layouts: List[Tuple[str, str]] = []
    keys: List[str] = []
    rules: List[str] = []
    decls: List[str] = []

    current_decl: List[str] = []
    in_decl = False

    for line in hunk.added_lines:
        line_str = line.strip()

        # Layout entry
        layout_matches = re.findall(r'\{\s*"([^"]+)"\s*,\s*([a-zA-Z0-9_]+)\s*\}', line)
        for sym, fn in layout_matches:
            if fn not in ("NULL", "tile", "monocle") and not line_str.startswith("{ MODKEY") and not line_str.startswith("{ 0"):
                layouts.append((sym, fn))

        # Key entry
        if "XKB_KEY_" in line_str and line_str.startswith("{"):
            keys.append(line)
            continue

        # Rule entry
        if ("Gimp" in line_str or "firefox" in line_str or line_str.startswith('{ .id =') or
            (line_str.startswith('{ "') and not "XKB_KEY_" in line_str and not layout_matches)):
            rules.append(line)
            continue

        # Macro
        if line_str.startswith("#define ") or line_str.startswith("# define "):
            decls.append(line_str)
            continue

        # Static declaration
        if line_str.startswith("static "):
            if current_decl:
                decls.append("\n".join(current_decl))
                current_decl = []
            current_decl.append(line)
            if line_str.endswith(";") or line_str.endswith("};"):
                decls.append("\n".join(current_decl))
                current_decl = []
            else:
                in_decl = True
            continue

        if in_decl:
            current_decl.append(line)
            if line_str.endswith(";") or line_str.endswith("};"):
                decls.append("\n".join(current_decl))
                current_decl = []
                in_decl = False

    if current_decl:
        decls.append("\n".join(current_decl))

def reconcile_scheme_enum(c_code: str, hunk: Hunk) -> Tuple[str, bool]:
    """
    Reconciles conflicting modifications to enum { SchemeNorm, SchemeSel, ... }.
    Extracts any newly added Scheme* identifiers and adds them into the enum definition.
    """
    hunk_text = "\n".join(hunk.lines)
    if "/* color schemes */" not in hunk_text and "SchemeNorm" not in hunk_text:
        return c_code, False

    added_schemes = []
    for line in hunk.added_lines:
        schemes = re.findall(r'\b(Scheme[a-zA-Z0-9_]+)\b', line)
        for s in schemes:
            if s not in ("SchemeNorm", "SchemeSel", "SchemeUrg"):
                added_schemes.append(s)

    if not added_schemes:
        return c_code, False

    match = re.search(r'enum\s*\{([^}]+)\}\s*;\s*/\*\s*color schemes\s*\*/', c_code)
    if not match:
        match = re.search(r'enum\s*\{([^}]+)\}\s*;', c_code)
        if not match or "SchemeNorm" not in match.group(1):
            return c_code, False

    enum_body = match.group(1)
    current_schemes = [s.strip() for s in enum_body.split(",") if s.strip()]
    changed = False
    for s in added_schemes:
        if s not in current_schemes:
            current_schemes.append(s)
            changed = True

    if not changed:
        return c_code, True

    new_enum = "enum { " + ", ".join(current_schemes) + " }; /* color schemes */"
    c_code = c_code[:match.start()] + new_enum + c_code[match.end():]
    print(f"note: reconciled color scheme enum with {added_schemes}")
    return c_code, True

def reconcile_c_struct_hunk(c_code: str, hunk: Hunk) -> Tuple[str, bool]:
    """
    Checks if a rejected hunk in dwl.c targets Client, Monitor, or Rule structs.
    If so, extracts added fields and inserts them into the struct before '}'.
    """
    # Struct fields cannot contain control flow or expressions with '='
    for line in hunk.added_lines:
        s = line.strip()
        if re.search(r'\b(if|for|while|return|case|switch|break|continue)\b', s):
            return c_code, False
        if "=" in s:
            return c_code, False

    header_and_context = hunk.header + "\n" + "\n".join(hunk.lines)
    hunk_header = hunk.header.strip()

    target_struct = None
    if re.search(r'\bstruct\s+Client\b', hunk_header) or "} Client;" in header_and_context or "struct Client {" in header_and_context:
        target_struct = "Client"
    elif re.search(r'\bstruct\s+Monitor\b', hunk_header) or "} Monitor;" in header_and_context or "struct Monitor {" in header_and_context:
        target_struct = "Monitor"
    elif re.search(r'\bstruct\s+Rule\b', hunk_header) or "} Rule;" in header_and_context or ("typedef struct" in header_and_context and "Rule;" in header_and_context):
        target_struct = "Rule"
    else:
        for line in hunk.context_lines:
            if "int gamma_lut_changed;" in line or "char ltsymbol[16];" in line:
                target_struct = "Monitor"
                break
            elif "unsigned int bw;" in line or "uint32_t tags;" in line or "int isfloating, isurgent" in line:
                target_struct = "Client"
                break
            elif "const char *id;" in line or "const char *title;" in line:
                target_struct = "Rule"
                break

    if not target_struct:
        return c_code, False

    updated_code = c_code
    applied_any = False

    for line in hunk.added_lines:
        line_clean = line.strip()
        if not line_clean.endswith(";"):
            continue
        if any(k in line_clean for k in ("if ", "for ", "while ", "return ", "switch ", "case ")) or "=" in line_clean:
            continue
        names = extract_member_names(line_clean)
        if names:
            updated_code = insert_field_into_struct(updated_code, target_struct, line_clean)
            applied_any = True
            print(f"note: inserted member {names} into struct {target_struct}")

    return updated_code, applied_any

def reconcile_dwl_c_macro_hunk(c_code: str, hunk: Hunk) -> Tuple[str, bool]:
    """
    Reconciles macro modifications in dwl.c (e.g. VISIBLEON and BORDERPX additions).
    """
    hunk_text = "\n".join(hunk.lines)
    if "VISIBLEON" in hunk_text:
        if "!(C)->swallowedby" in hunk_text and "!(C)->swallowedby" not in c_code:
            v_match = re.search(r'^(#\s*define\s+VISIBLEON\s*\([^)]+\)\s+)(.+)$', c_code, re.MULTILINE)
            if v_match:
                prefix = v_match.group(1)
                body = v_match.group(2).strip()
                new_body = f"({body} && !(C)->swallowedby)"
                c_code = c_code[:v_match.start()] + f"{prefix}{new_body}" + c_code[v_match.end():]
        elif "(C)->issticky" in hunk_text and "(C)->issticky" not in c_code:
            v_match = re.search(r'^(#\s*define\s+VISIBLEON\s*\([^)]+\)\s+)(.+)$', c_code, re.MULTILINE)
            if v_match:
                prefix = v_match.group(1)
                body = v_match.group(2).strip()
                new_body = f"({body} || (C)->issticky)"
                c_code = c_code[:v_match.start()] + f"{prefix}{new_body}" + c_code[v_match.end():]
        elif "!(C)->ishidden" in hunk_text and "!(C)->ishidden" not in c_code:
            v_match = re.search(r'^(#\s*define\s+VISIBLEON\s*\([^)]+\)\s+)(.+)$', c_code, re.MULTILINE)
            if v_match:
                prefix = v_match.group(1)
                body = v_match.group(2).strip()
                new_body = f"({body} && !(C)->ishidden)"
                c_code = c_code[:v_match.start()] + f"{prefix}{new_body}" + c_code[v_match.end():]
            if "#define VISIBLE(" not in c_code:
                vis_def = "#define VISIBLE(C, M)           ((M) && (C)->mon == (M) && ((C)->tags & (M)->tagset[(M)->seltags])\n"
                v_match = re.search(r'^#\s*define\s+VISIBLEON\b.*$', c_code, re.MULTILINE)
                if v_match:
                    c_code = c_code[:v_match.end()] + "\n" + vis_def + c_code[v_match.end():]

        if "BORDERPX" in hunk_text and not re.search(r'#\s*define\s+BORDERPX\b', c_code):
            borderpx_line = None
            for l in hunk.added_lines:
                if "BORDERPX" in l:
                    borderpx_line = l
                    break
            if borderpx_line:
                v_match = re.search(r'^#\s*define\s+VISIBLEON\b.*$', c_code, re.MULTILINE)
                if v_match:
                    insert_pos = v_match.end()
                    c_code = c_code[:insert_pos] + "\n" + borderpx_line + c_code[insert_pos:]
        return c_code, True
    return c_code, False

def reconcile_dwl_c_enum_hunk(c_code: str, hunk: Hunk) -> Tuple[str, bool]:
    """
    Reconciles enum modifications in dwl.c (e.g. SchemeHid addition in color schemes enum).
    """
    return reconcile_scheme_enum(c_code, hunk)

def reconcile_dwl_c_drawbar_hunk(c_code: str, hunk: Hunk, target_dir: str = ".") -> Tuple[str, bool]:
    """
    Reconciles conflicting bar title drawing hunks in drawbar() (e.g. awesomebar vs bartruecenteredtitle vs bar-notitle).
    """
    hunk_text = "\n".join(hunk.lines)

    # Case 0: bar-awesomebar n variable declaration
    if "int x, w, tw = 0, n = 0;" in hunk_text:
        if "int x, w, tw = 0, n = 0;" not in c_code:
            if "int x, w, tw = 0;" in c_code:
                c_code = c_code.replace("int x, w, tw = 0;", "int x, w, tw = 0, n = 0;", 1)
                print("note: reconciled n variable declaration in drawbar()")
                return c_code, True
        else:
            return c_code, True

    # Case 1: bar-awesomebar client count / n++ loop
    if "VISIBLE(c, m)" in hunk_text and "n++" in hunk_text:
        if "int x, w, tw = 0;" in c_code and "int x, w, tw = 0, n = 0;" not in c_code:
            c_code = c_code.replace("int x, w, tw = 0;", "int x, w, tw = 0, n = 0;", 1)
        drawbar_match = re.search(
            r'(drawbar\s*\(\s*Monitor\s*\*m\s*\)[\s\S]*?if\s*\(\s*c->mon\s*!=\s*m\s*\)\s*\n\s*continue\s*;\s*\n)',
            c_code
        )
        if drawbar_match:
            prefix = drawbar_match.group(1)
            if "n++;" not in prefix:
                c_code = c_code[:drawbar_match.end()] + "\t\tif (VISIBLE(c, m))\n\t\t\tn++;\n" + c_code[drawbar_match.end():]
                print("note: reconciled awesomebar client count loop in drawbar()")
                return c_code, True
            else:
                return c_code, True
        else:
            target = "if (c->mon != m)\n\t\t\tcontinue;\n"
            if target in c_code and "n++;" not in c_code:
                c_code = c_code.replace(target, target + "\t\tif (VISIBLE(c, m))\n\t\t\tn++;\n", 1)
                print("note: reconciled awesomebar client count loop in drawbar()")
                return c_code, True

    # Case A: bar-awesomebar title drawing loop
    if "enum" not in hunk_text and ("base = w / n" in hunk_text or ("SchemeHid" in hunk_text and "drwl_text" in hunk_text)):
        awesome_replacement = """        if (n > 0) {
            int base = w / n;
            int remainder = w % n;
            int tabw;
            int idx = 0;

            wl_list_for_each(c, &clients, link) {
                if (!VISIBLE(c, m))
                    continue;
                if (c == focustop(m))
                    drwl_setscheme(m->drw, colors[SchemeSel]);
                else if (c->ishidden)
                    drwl_setscheme(m->drw, colors[SchemeHid]);
                else
                    drwl_setscheme(m->drw, colors[SchemeNorm]);
\t\t        tabw = base + (idx < remainder ? 1 : 0);
\t\t        idx++;
                drwl_text(m->drw, x, 0, tabw, m->b.height, m->lrpad / 2, client_get_title(c), 0);
                x += tabw;
            }
\t\t} else {"""
        pattern = r'if\s*\(\s*\(w\s*=\s*m->b\.width\s*-\s*tw\s*-\s*x\)\s*>\s*m->b\.height\)\s*\{\s*if\s*\([^)]+\)\s*\{.*?\}\s*else\s*\{'
        new_code, count = re.subn(pattern, "if ((w = m->b.width - tw - x) > m->b.height) {\n" + awesome_replacement, c_code, count=1, flags=re.DOTALL)
        if count > 0:
            if "m->b.bt = n;" not in new_code:
                new_code = new_code.replace(
                    "wlr_scene_buffer_set_dest_size(m->scene_buffer,",
                    "    m->b.bt = n;\n    m->b.btw = w;\n\n\twlr_scene_buffer_set_dest_size(m->scene_buffer,",
                    1
                )
            config_path = os.path.join(target_dir, "config.def.h")
            if not os.path.exists(config_path):
                config_path = os.path.join(target_dir, "config.h")
            if os.path.exists(config_path):
                with open(config_path, "r", encoding="utf-8", errors="replace") as f:
                    if "window_title" in f.read():
                        new_code = new_code.replace("if (n > 0)", "if (n > 0 && window_title)", 1)
            print("note: reconciled awesomebar title loop in drawbar()")
            return new_code, True

    # Case B: bar-notitle window_title check
    if "window_title" in hunk_text and ("if (c)" in hunk_text or "if (c && window_title)" in hunk_text):
        if "if (n > 0)" in c_code:
            c_code = c_code.replace("if (n > 0)", "if (n > 0 && window_title)", 1)
            print("note: reconciled bar-notitle with awesomebar in drawbar()")
            return c_code, True
        elif "if (c)" in c_code and "window_title" not in c_code:
            c_code = re.sub(r'if\s*\(\s*c\s*\)', 'if (c && window_title)', c_code, count=1)
            print("note: reconciled bar-notitle in drawbar()")
            return c_code, True

    return c_code, False

def apply_pure_addition_hunk(c_code: str, hunk: Hunk) -> Tuple[str, bool]:
    """
    Applies pure addition hunks (e.g. forward function declarations) by anchoring
    each added block to its nearest uniquely-matching context line.
    """
    if hunk.removed_lines:
        return c_code, False

    lines = hunk.lines
    i = 0
    n = len(lines)
    updated_code = c_code
    applied_any = False

    while i < n:
        if lines[i].startswith("+") and not lines[i].startswith("+++"):
            added_group = []
            while i < n and lines[i].startswith("+"):
                added_group.append(lines[i][1:])
                i += 1
            added_text = "\n".join(added_group) + "\n"

            preceding_anchor = None
            for j in range(i - len(added_group) - 1, -1, -1):
                if lines[j].startswith(" "):
                    preceding_anchor = lines[j][1:].strip()
                    break

            succeeding_anchor = None
            for j in range(i, n):
                if lines[j].startswith(" "):
                    succeeding_anchor = lines[j][1:].strip()
                    break

            if preceding_anchor and updated_code.count(preceding_anchor) == 1:
                idx = updated_code.find(preceding_anchor) + len(preceding_anchor)
                if not preceding_anchor.endswith("\n") and updated_code[idx:idx+1] == "\n":
                    idx += 1
                updated_code = updated_code[:idx] + added_text + updated_code[idx:]
                applied_any = True
            elif succeeding_anchor and updated_code.count(succeeding_anchor) == 1:
                idx = updated_code.find(succeeding_anchor)
                updated_code = updated_code[:idx] + added_text + updated_code[idx:]
                applied_any = True
        else:
            i += 1

    return updated_code, applied_any

def apply_single_patch_file(patch_path: str, channel: str = "main", target_dir: str = ".", is_single: bool = False) -> None:
    """
    Applies a single patch file using the 6-stage architecture:
    1. Normalize patch.
    2. Fast-path dry run (-p1, then -F3).
    3. Hunk-level separation.
    4. AST Struct Reconciler for dwl.c.
    5. Array & Declaration Reconciler for config.def.h.
    """
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
                    print(f"error: unresolvable conflict in {rel_target} for patch {patch_path}", file=sys.stderr)
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

def main() -> None:
    parser = argparse.ArgumentParser(description="Intelligent C Conflict Engine for dwl-flake")
    parser.add_argument("--channel", default="main", help="Target dwl channel (stable or main)")
    parser.add_argument("--target", default=".", help="Target source directory")
    parser.add_argument("patches", nargs="*", help="List of patch files to apply")

    args = parser.parse_args()

    if not args.patches:
        return

    sorted_patch_list = sort_patches(args.patches)
    is_single_patch = len(args.patches) <= 1

    for p in sorted_patch_list:
        if not os.path.exists(p):
            print(f"error: patch file not found: {p}", file=sys.stderr)
            sys.exit(1)
        apply_single_patch_file(p, channel=args.channel, target_dir=args.target, is_single=is_single_patch)

    if len(args.patches) > 1:
        reconcile_tag_macros(target_dir=args.target)
        reconcile_layout_keybindings(target_dir=args.target)

        config_path = os.path.join(args.target, "config.def.h")
        if not os.path.exists(config_path):
            config_path = os.path.join(args.target, "config.h")

        dwl_c_path = os.path.join(args.target, "dwl.c")
        if os.path.exists(config_path) and os.path.exists(dwl_c_path):
            with open(dwl_c_path, "r", encoding="utf-8", errors="replace") as f:
                dwl_c_code = f.read()
            r_loc = locate_struct_definition(dwl_c_code, "Rule")
            if r_loc:
                rule_fields = list(parse_existing_members(r_loc.raw_body))
                if len(rule_fields) > 5:
                    with open(config_path, "r", encoding="utf-8", errors="replace") as f:
                        c_code = f.read()
                    updated_c = convert_all_rules_to_designated(c_code, rule_fields)
                    with open(config_path, "w", encoding="utf-8") as f:
                        f.write(updated_c)

if __name__ == "__main__":
    main()
