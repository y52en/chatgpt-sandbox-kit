#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib/assets.sh
source "$ROOT/lib/assets.sh"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/Drive/re"
printf a > "$tmp/Drive/re/demo.zip.part000"
printf b > "$tmp/Drive/re/demo.zip.part001"
export SANDBOX_KIT_ASSET_ROOTS="$tmp"
mapfile -t p < <(sandbox_kit_find_matches 'demo.zip.part*' | sort -V)
((${#p[@]} == 2))
sandbox_kit_validate_parts "${p[@]}"
printf x > "$tmp/Drive/re/one.whl"
[[ $(sandbox_kit_find_one 'one.whl') == "$tmp/Drive/re/one.whl" ]]
for f in "$ROOT"/*.sh "$ROOT"/*/*.sh; do [[ -f "$f" ]] && bash -n "$f"; done
printf 'self-test: OK\n'
