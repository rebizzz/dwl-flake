"""Merging patch additions into the arrays in config.def.h."""

import re
from typing import Dict, List, Tuple

from .csource import find_matching_brace, is_symbol_declared, strip_comments_and_strings


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
