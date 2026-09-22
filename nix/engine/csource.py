"""Reading C source without being fooled by comments or string literals."""

import re
from typing import List, Optional, Set


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
        r'\btypedef\s+struct(?:\s+[a-zA-Z0-9_]+)?\s*\{'
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
