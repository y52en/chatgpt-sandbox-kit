#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib/assets.sh
source "$ROOT/lib/assets.sh"
MANIFEST="$ROOT/manifest/artifacts.tsv"
STRICT=0
[[ ${1:-} == --strict ]] && STRICT=1

printf '%-20s %-38s %-10s %s\n' COMPONENT ASSET STATUS MATCH
printf '%-20s %-38s %-10s %s\n' '--------------------' '--------------------------------------' '----------' '-----'
missing=0
while IFS=$'\t' read -r component logical requirement mode pattern drive_folder notes; do
  [[ -z "$component" || "$component" == \#* ]] && continue
  matches=()
  if [[ "$mode" == archive ]]; then
    mapfile -t matches < <(sandbox_kit_find_matches "$pattern")
    if ((${#matches[@]} == 0)); then
      mapfile -t matches < <(sandbox_kit_find_matches "$pattern.part*" | LC_ALL=C sort -V)
      if ((${#matches[@]} > 0)); then
        if sandbox_kit_validate_parts "${matches[@]}"; then status="parts:${#matches[@]}"; else status=broken; fi
      else
        status=missing
      fi
    elif ((${#matches[@]} == 1)); then
      status=ready
    else
      status=duplicate
    fi
  else
    mapfile -t matches < <(sandbox_kit_find_matches "$pattern")
    case ${#matches[@]} in 0) status=missing ;; 1) status=ready ;; *) status=duplicate ;; esac
  fi
  if [[ "$requirement" == required && "$status" != ready && "$status" != parts:* ]]; then ((missing+=1)); fi
  match=${matches[0]:-"Drive/$drive_folder/$pattern"}
  printf '%-20s %-38s %-10s %s\n' "$component" "$logical" "$status" "$match"
done < "$MANIFEST"

if ((STRICT && missing > 0)); then
  printf '\n%d required asset(s) missing.\n' "$missing" >&2
  exit 1
fi
