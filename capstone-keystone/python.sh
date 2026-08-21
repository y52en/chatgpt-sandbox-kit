#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${CAPSTONE_KEYSTONE_VENV:-}" ]]; then
  VENV_DIR=$CAPSTONE_KEYSTONE_VENV
elif [[ -n "${CAPSTONE_KEYSTONE_WORK_DIR:-}" ]]; then
  VENV_DIR="$CAPSTONE_KEYSTONE_WORK_DIR/venv"
elif [[ -d /mnt/data ]]; then
  VENV_DIR=/mnt/data/capstone-keystone-kit/venv
else
  VENV_DIR="$PWD/.tools/capstone-keystone/venv"
fi

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  printf 'error: Capstone/Keystone environment not found: %s\nRun capstone-keystone/setup.sh first.\n' "$VENV_DIR" >&2
  exit 1
fi

exec "$VENV_DIR/bin/python" "$@"
