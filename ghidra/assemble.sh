#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  cat <<'EOF'
Usage: assemble.sh --manifest PATH [--parts-dir DIR] [--output PATH]

Reassembles a Ghidra ZIP from a ghidra-dist manifest. Parts can already be in a
local directory, or the script can download missing parts from
GHIDRA_DIST_BASE_URL.
EOF
}

manifest=''
parts_dir=''
output=''
while (($#)); do
  case "$1" in
    --manifest) manifest="${2:?missing path}"; shift 2 ;;
    --parts-dir) parts_dir="${2:?missing directory}"; shift 2 ;;
    --output) output="${2:?missing path}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done
[[ -n "$manifest" && -f "$manifest" ]] || die '--manifest must point to a manifest.json file'
require_command python3

filename="$(manifest_value "$manifest" filename)"
expected="$(manifest_value "$manifest" sha256)"
parts_dir="${parts_dir:-$(dirname "$manifest") }"
parts_dir="${parts_dir% }"
output="${output:-$GHIDRA_DOWNLOADS_DIR/$filename}"
mkdir -p "$parts_dir" "$(dirname "$output")"

mapfile -t records < <(python3 - "$manifest" <<'PY'
import json, sys
m = json.load(open(sys.argv[1], encoding='utf-8'))
for p in m['chunks']:
    print(f"{p['file']}\t{p['size']}\t{p['sha256']}")
PY
)

for record in "${records[@]}"; do
  IFS=$'\t' read -r name size digest <<<"$record"
  path="$parts_dir/$name"
  if [[ ! -f "$path" ]]; then
    [[ -n "${GHIDRA_DIST_BASE_URL:-}" ]] || die "missing chunk and GHIDRA_DIST_BASE_URL is unset: $name"
    require_command curl
    log "downloading chunk $name"
    curl --fail --location --silent --show-error --retry 3 \
      --output "${path}.partial" "${GHIDRA_DIST_BASE_URL%/}/$name"
    mv "${path}.partial" "$path"
  fi
  [[ "$(wc -c < "$path" | tr -d ' ')" == "$size" ]] || die "chunk size mismatch: $name"
  [[ "$(sha256_file "$path")" == "$digest" ]] || die "chunk SHA-256 mismatch: $name"
done

tmp="${output}.partial"
: > "$tmp"
for record in "${records[@]}"; do
  IFS=$'\t' read -r name _ <<<"$record"
  cat "$parts_dir/$name" >> "$tmp"
done
actual="$(sha256_file "$tmp")"
[[ "$actual" == "$expected" ]] || {
  rm -f "$tmp"
  die "reassembled SHA-256 mismatch: expected $expected, got $actual"
}
mv "$tmp" "$output"
log "verified archive: $output"
printf '%s\n' "$output"
