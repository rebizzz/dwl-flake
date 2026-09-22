"""Command line entry point used by the package's patchPhase."""

import argparse
import os
import sys
from typing import List

from .apply import apply_single_patch_file, reconcile_layout_keybindings
from .configmerge import convert_all_rules_to_designated
from .csource import locate_struct_definition, parse_existing_members
from .ordering import sort_patches
from .tagmacros import reconcile_tag_macros
from .threeway import snapshot_pristine


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

    # Only combined patch sets can conflict with each other, and the snapshot is
    # only useful as a merge ancestor, so skip the copy for a single patch.
    pristine_tree = None if is_single_patch else snapshot_pristine(args.target)

    applied: List[str] = []
    for p in sorted_patch_list:
        apply_single_patch_file(
            p,
            channel=args.channel,
            target_dir=args.target,
            is_single=is_single_patch,
            pristine_tree=pristine_tree,
            applied_patches=list(applied),
        )
        applied.append(p)

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
