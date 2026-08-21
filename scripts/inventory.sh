#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib/assets.sh
source "$ROOT/lib/assets.sh"
MANIFEST="$ROOT/manifest/artifacts.tsv"
STRICT=0
[[ ${1:-} == --strict ]] && STRICT=1

printf '%-20s %-38s %-12s %s\n' COMPONENT ASSET STATUS MATCH
printf '%-20s %-38s %-12s %s\n' '--------------------' '--------------------------------------' '------------' '-----'
problems=0
while IFS=$'\t' read -r component logical requirement mode pattern drive_folder part_start part_count notes; do
  [[ -z "$component" || "$component" == \#* ]] && continue
  matches=()
  if [[ "$mode" == archive ]]; then
    mapfile -t matches < <(sandbox_kit_find_matches "$pattern")
    if ((${#matches[@]} == 0)); then
      mapfile -t matches < <(sandbox_kit_find_matches "$pattern.part*" | LC_ALL=C sort -V)
      if ((${#matches[@]} > 0)); then
        validate_args=()
        [[ -z "$part_start" ]] || validate_args+=(--expected-start "$part_start")
        [[ -z "$part_count" ]] || validate_args+=(--expected-count "$part_count")
        if sandbox_kit_validate_parts "${validate_args[@]}" -- "${matches[@]}"; then status="parts:${#matches[@]}"; else status=broken; fi
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

  if [[ "$status" == broken || "$status" == duplicate || ( "$requirement" == required && "$status" == missing ) ]]; then
    problems=$((problems + 1))
  fi
  match=${matches[0]:-"Drive/$drive_folder/$pattern"}
  printf '%-20s %-38s %-12s %s\n' "$component" "$logical" "$status" "$match"
done < "$MANIFEST"

if ((STRICT && problems > 0)); then
  printf '\n%d required/ambiguous asset issue(s) found.\n' "$problems" >&2
  exit 1
fi
