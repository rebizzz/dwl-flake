#!/usr/bin/env bash
set -euo pipefail

runHook prePatch 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON="${PYTHON:-python3}"

# The build calls conflict-engine.py directly; this wrapper is for running the
# same pipeline by hand from a checkout, where the engine sits alongside it.
ENGINE="${CONFLICT_ENGINE:-$SCRIPT_DIR/conflict-engine.py}"
if [ ! -f "$ENGINE" ]; then
  echo "error: conflict engine not found at $ENGINE (set CONFLICT_ENGINE to override)" >&2
  exit 1
fi

PATCH_LIST=()
if [ -n "${patches+x}" ] && [ ${#patches[@]} -gt 0 ]; then
  PATCH_LIST=("${patches[@]}")
elif [ "$#" -gt 0 ]; then
  PATCH_LIST=("$@")
fi

if [ ${#PATCH_LIST[@]} -gt 0 ]; then
  "$PYTHON" "$SCRIPT_DIR/conflict-engine.py" --target . "${PATCH_LIST[@]}"
fi

runHook postPatch 2>/dev/null || true
