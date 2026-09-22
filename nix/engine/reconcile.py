"""Per-hunk reconcilers for the conflicts that show up in dwl.c."""

import os
import re
import subprocess
from typing import List, Tuple

from .csource import extract_member_names, insert_field_into_struct
from .diffs import Hunk


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

    return layouts, keys, rules, decls

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
        line_clean = re.sub(r'/\*.*?\*/', '', line).strip()
        line_clean = re.sub(r'//.*$', '', line_clean).strip()
        if not line_clean.endswith(";"):
            continue
        if any(k in line_clean for k in ("if ", "for ", "while ", "return ", "switch ", "case ")) or "=" in line_clean:
            continue
        names = extract_member_names(line_clean)
        if names:
            updated_code = insert_field_into_struct(updated_code, target_struct, line_clean)
            applied_any = True
            print(f"note: inserted member {names} into struct {target_struct}")

    if target_struct == "Client" and "struct Client {" in updated_code:
        updated_code = re.sub(r'(\}\s*)Client\s*;', r'\1;', updated_code, count=1)

    return updated_code, applied_any

def reconcile_dwl_c_macro_hunk(c_code: str, hunk: Hunk) -> Tuple[str, bool]:
    """
    Reconciles macro modifications in dwl.c (e.g. VISIBLEON and BORDERPX additions).
    """
    hunk_text = "\n".join(hunk.lines)
    if re.search(r'#\s*define\s+VISIBLEON\b', hunk_text) or re.search(r'#\s*define\s+BORDERPX\b', hunk_text):
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
    Applies pure addition hunks (e.g. forward function declarations or function implementations)
    by anchoring each added block to uniquely-matching context lines.
    """
    if hunk.removed_lines:
        return c_code, False

    added_lines = hunk.added_lines
    if not added_lines:
        return c_code, False
    added_text = "\n".join(added_lines) + "\n"

    lines = hunk.lines
    added_indices = [idx for idx, l in enumerate(lines) if l.startswith("+") and not l.startswith("+++")]
    if not added_indices:
        return c_code, False
    first_add = added_indices[0]
    last_add = added_indices[-1]

    prec_lines = [lines[k][1:] for k in range(first_add) if lines[k].startswith(" ")]
    succ_lines = [lines[k][1:] for k in range(last_add + 1, len(lines)) if lines[k].startswith(" ")]

    prec_block = "\n".join(prec_lines).strip()
    succ_block = "\n".join(succ_lines).strip()

    # 1. Try anchoring before succ_block if unique
    if succ_block and c_code.count(succ_block) == 1:
        idx = c_code.find(succ_block)
        print("note: applied pure addition hunk anchored before succeeding block")
        return c_code[:idx] + added_text + "\n" + c_code[idx:], True

    # 2. Try anchoring after prec_block if unique
    if prec_block and c_code.count(prec_block) == 1:
        idx = c_code.find(prec_block) + len(prec_block)
        if c_code[idx:idx+1] == "\n":
            idx += 1
        print("note: applied pure addition hunk anchored after preceding block")
        return c_code[:idx] + added_text + "\n" + c_code[idx:], True

    # 3. Fallback to single non-trivial anchor lines (> 5 chars to avoid matching '}' or 'void')
    for line in reversed(prec_lines):
        s = line.strip()
        if len(s) > 5 and c_code.count(s) == 1:
            idx = c_code.find(s) + len(s)
            if c_code[idx:idx+1] == "\n":
                idx += 1
            print(f"note: applied pure addition hunk anchored after '{s[:30]}'")
            return c_code[:idx] + added_text + "\n" + c_code[idx:], True

    for line in succ_lines:
        s = line.strip()
        if len(s) > 5 and c_code.count(s) == 1:
            idx = c_code.find(s)
            print(f"note: applied pure addition hunk anchored before '{s[:30]}'")
            return c_code[:idx] + added_text + "\n" + c_code[idx:], True

    return c_code, False
