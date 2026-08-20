#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${UNICORN_VENV:-}" ]]; then
  VENV_DIR=$UNICORN_VENV
elif [[ -n "${UNICORN_WORK_DIR:-}" ]]; then
  VENV_DIR="$UNICORN_WORK_DIR/venv"
elif [[ -d /mnt/data ]]; then
  VENV_DIR=/mnt/data/unicorn-kit/venv
else
  VENV_DIR="$PWD/.tools/unicorn/venv"
fi

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  printf 'error: Unicorn environment not found: %s\nRun unicorn/setup.sh first.\n' "$VENV_DIR" >&2
  exit 1
fi

exec "$VENV_DIR/bin/python" "$@"
