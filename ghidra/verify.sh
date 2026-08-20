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
[[ -x "$GHIDRA_INSTALL_DIR/support/analyzeHeadless" ]] || { echo 'error: analyzeHeadless missing' >&2; exit 1; }
[[ -x "$PYGHIDRA_VENV/bin/python" ]] || { echo 'error: PyGhidra venv missing' >&2; exit 1; }

java -version
HEADLESS_OUTPUT=$("$GHIDRA_INSTALL_DIR/support/analyzeHeadless" 2>&1 || true)
grep -Fq 'Usage:' <<<"$HEADLESS_OUTPUT" || { echo 'error: analyzeHeadless did not start correctly' >&2; exit 1; }
GHIDRA_INSTALL_DIR="$GHIDRA_INSTALL_DIR" "$PYGHIDRA_VENV/bin/python" -P - <<'PYCODE'
import jpype
import pyghidra
pyghidra.start()
from ghidra.framework import Application
from ghidra.program.model.address import Address
print('PyGhidra:', pyghidra.__version__)
print('JPype:', jpype.__version__)
print('Ghidra:', Application.getApplicationVersion())
print('Ghidra Java class:', Address)
PYCODE
