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
sandbox_kit_validate_parts --expected-start 0 --expected-count 2 -- "${p[@]}"

# A missing final part must be detected even though the remaining prefix is contiguous.
rm "$tmp/Drive/re/demo.zip.part001"
mapfile -t p < <(sandbox_kit_find_matches 'demo.zip.part*' | sort -V)
if sandbox_kit_validate_parts --expected-start 0 --expected-count 2 -- "${p[@]}" >/dev/null 2>&1; then
  printf 'self-test: missing tail part was not detected\n' >&2
  exit 1
fi

# Connector-added .bin suffixes remain discoverable.
printf b > "$tmp/Drive/re/demo.zip.part001.bin"
mapfile -t p < <(sandbox_kit_find_matches 'demo.zip.part*' | sort -V)
sandbox_kit_validate_parts --expected-start 0 --expected-count 2 -- "${p[@]}"

printf x > "$tmp/Drive/re/one.whl"
[[ $(sandbox_kit_find_one 'one.whl') == "$tmp/Drive/re/one.whl" ]]
for f in "$ROOT"/*.sh "$ROOT"/*/*.sh; do [[ -f "$f" ]] && bash -n "$f"; done
printf 'self-test: OK\n'
