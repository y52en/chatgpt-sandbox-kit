#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  echo 'Usage: analyze.sh BINARY [extra analyzeHeadless arguments...]'
}

(($# >= 1)) || { usage >&2; exit 2; }
binary="$(realpath "$1")"
shift
[[ -f "$binary" ]] || die "binary not found: $binary"
[[ -x "$GHIDRA_HOME/support/analyzeHeadless" ]] || die 'Ghidra is not installed; run ghidra/setup.sh first'

project_root="$(mktemp -d)"
trap 'rm -rf "$project_root"' EXIT
project_name='SandboxAnalysis'

GHIDRA_HEADLESS_MAXMEM="${GHIDRA_HEADLESS_MAXMEM:-2G}" \
  "$GHIDRA_HOME/support/analyzeHeadless" \
  "$project_root" "$project_name" \
  -import "$binary" \
  -overwrite \
  "$@"
