#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  echo 'Usage: decompile.sh BINARY [OUTPUT_FILE]'
}

(($# >= 1 && $# <= 2)) || { usage >&2; exit 2; }
binary="$(realpath "$1")"
[[ -f "$binary" ]] || die "binary not found: $binary"
output="${2:-$PWD/$(basename "$binary").decompiled.c}"
output="$(realpath -m "$output")"
mkdir -p "$(dirname "$output")"
[[ -x "$GHIDRA_HOME/support/analyzeHeadless" ]] || die 'Ghidra is not installed; run ghidra/setup.sh first'

project_root="$(mktemp -d)"
trap 'rm -rf "$project_root"' EXIT
project_name='SandboxDecompile'

GHIDRA_HEADLESS_MAXMEM="${GHIDRA_HEADLESS_MAXMEM:-2G}" \
  "$GHIDRA_HOME/support/analyzeHeadless" \
  "$project_root" "$project_name" \
  -import "$binary" \
  -overwrite \
  -scriptPath "$GHIDRA_KIT_DIR/scripts" \
  -postScript ExportDecompilation.java "$output"

[[ -s "$output" ]] || die "Ghidra did not produce decompiler output: $output"
log "decompiled output: $output"
printf '%s\n' "$output"
