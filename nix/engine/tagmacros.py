"""Bridging TAGCOUNT and LENGTH(tags) between patches that disagree."""

import os
import re


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
