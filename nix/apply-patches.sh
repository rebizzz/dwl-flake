#!/usr/bin/env bash
# Runs the patch engine by hand from a checkout; the build calls it directly.
set -euo pipefail

runHook prePatch 2>/dev/null || true

NIX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -d "$NIX_DIR/engine" ]; then
  echo "error: patch engine not found at $NIX_DIR/engine" >&2
  exit 1
fi

PATCH_LIST=()
if [ -n "${patches+x}" ] && [ ${#patches[@]} -gt 0 ]; then
  PATCH_LIST=("${patches[@]}")
elif [ "$#" -gt 0 ]; then
  PATCH_LIST=("$@")
fi

if [ ${#PATCH_LIST[@]} -gt 0 ]; then
  PYTHONPATH="$NIX_DIR" "${PYTHON:-python3}" -m engine --target . "${PATCH_LIST[@]}"
fi

runHook postPatch 2>/dev/null || true
