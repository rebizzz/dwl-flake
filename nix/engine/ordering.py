"""Order patches so each one is applied after whatever it builds on."""

import os
import re
from typing import List

# Phases, applied in this order. bar has to come first because its addons,
# the gaps patches and pertag all edit the code it introduces.
PHASES = [
    ["bar"],
    [
        "bar-awesomebar", "bar-notitle", "awesomebar", "notitle", "barborder",
        "barcolors", "barconfig", "barpadding", "bartruecenteredtitle",
        "hide_vacant_tags", "zerotag",
    ],
    ["vanitygaps", "genericgaps", "borders", "smartborders", "simpleborders"],
    [
        "bottomstack", "centeredmaster", "decklayout", "gaplessgrid", "btrtile",
        "dwindle", "snail",
    ],
    [
        "movestack", "attachbottom", "attachtop", "attachfocused", "customfloat",
        "focusonurgent", "follow", "zoomswap", "swapfocus", "swapandfocusdir",
    ],
    ["pertag", "shifttag", "shiftview", "reorganizetags", "singletagset", "rotatetags"],
    ["autostart", "setupenv", "systemd", "ipc", "kblayout"],
]

RANKS = {name: rank for rank, names in enumerate(PHASES) for name in names}
UNRANKED = len(PHASES)


def patch_names(patch_path: str) -> List[str]:
    """dwl-patches keeps each patch in a directory named after it, but a patch
    given as a bare path is only identifiable by its file name."""
    names = []
    parent = os.path.basename(os.path.dirname(os.path.abspath(patch_path))).lower()
    if parent not in ("patches", ".", ""):
        names.append(parent)
    names.append(re.sub(r"(\.patch|-v?[0-9].*|\.diff)$", "", os.path.basename(patch_path).lower()))
    return names


def get_patch_rank(patch_path: str) -> int:
    return min((RANKS.get(name, UNRANKED) for name in patch_names(patch_path)), default=UNRANKED)


def sort_patches(patch_paths: List[str]) -> List[str]:
    """Sorts by phase, keeping the given order within a phase."""
    return sorted(patch_paths, key=get_patch_rank)
