#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${GHIDRA_WORK_DIR:-}" ]]; then
  WORK_DIR=$GHIDRA_WORK_DIR
elif [[ -d /mnt/data/ghidra-kit ]]; then
  WORK_DIR=/mnt/data/ghidra-kit
else
  WORK_DIR="$PWD/.tools/ghidra"
fi
ENV_FILE="$WORK_DIR/env.sh"
[[ -f "$ENV_FILE" ]] || { echo "error: $ENV_FILE not found; run ghidra/setup.sh first" >&2; exit 1; }
# shellcheck disable=SC1090
source "$ENV_FILE"
exec "$PYGHIDRA_VENV/bin/python" -P "$@"
