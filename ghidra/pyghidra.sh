#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

[[ -x "$GHIDRA_PYGHIDRA_VENV/bin/python" ]] || die 'PyGhidra venv is missing; run ghidra/setup.sh first'
export GHIDRA_INSTALL_DIR="$GHIDRA_HOME"
if (($#)); then
  exec "$GHIDRA_PYGHIDRA_VENV/bin/python" "$@"
else
  exec "$GHIDRA_PYGHIDRA_VENV/bin/python"
fi
