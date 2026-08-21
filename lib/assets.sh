#!/usr/bin/env bash
# Shared offline asset discovery helpers for chatgpt-sandbox-kit.

sandbox_kit_die() { printf 'error: %s\n' "$*" >&2; exit 1; }
sandbox_kit_log() { printf '[sandbox-kit] %s\n' "$*" >&2; }

sandbox_kit_asset_roots() {
  local value root
  if [[ -n "${SANDBOX_KIT_ASSET_ROOTS:-}" ]]; then
    value=$SANDBOX_KIT_ASSET_ROOTS
    while IFS= read -r root; do
      [[ -n "$root" && -d "$root" ]] && printf '%s\n' "$root"
    done < <(tr ':' '\n' <<<"$value")
    return
  fi
  [[ -d /mnt/data ]] && printf '%s\n' /mnt/data
  printf '%s\n' "$PWD"
}

sandbox_kit_find_matches() {
  local pattern=$1 root
  while IFS= read -r root; do
    find "$root" \
      -type d \( -name '.git' -o -name '.tools' -o -name '*-kit' \) -prune -o \
      -type f \( -name "$pattern" -o -name "$pattern.bin" \) -print 2>/dev/null
  done < <(sandbox_kit_asset_roots) | LC_ALL=C sort -u
}

sandbox_kit_find_one() {
  local pattern=$1 required=${2:-required}
  local -a matches=()
  mapfile -t matches < <(sandbox_kit_find_matches "$pattern")
  if ((${#matches[@]} == 0)); then
    [[ "$required" == optional ]] && return 1
    sandbox_kit_die "asset not found: $pattern (roots: ${SANDBOX_KIT_ASSET_ROOTS:-/mnt/data:$PWD})"
  fi
  ((${#matches[@]} == 1)) || {
    printf 'ambiguous asset pattern %s:\n' "$pattern" >&2
    printf '  %s\n' "${matches[@]}" >&2
    sandbox_kit_die 'remove duplicates or narrow SANDBOX_KIT_ASSET_ROOTS'
  }
  printf '%s\n' "${matches[0]}"
}

sandbox_kit_validate_parts() {
  local start=-1 expected=-1 number path base
  local -a inputs=("$@")
  ((${#inputs[@]} > 0)) || return 1
  for path in "${inputs[@]}"; do
    base=$(basename "$path")
    if [[ "$base" =~ \.part([0-9]+)(\.bin)?$ ]]; then
      number=$((10#${BASH_REMATCH[1]}))
    else
      sandbox_kit_die "cannot parse split-part suffix: $base"
    fi
    if ((start < 0)); then
      start=$number
      expected=$number
      ((start == 0 || start == 1)) || sandbox_kit_die "split parts must start at part000 or part001: $base"
    fi
    ((number == expected)) || sandbox_kit_die "split archive gap: expected part$(printf '%03d' "$expected"), got $base"
    ((expected+=1))
  done
}

# Populate a caller-owned array with either one complete archive or validated split parts.
# Usage: sandbox_kit_collect_archive OUT_ARRAY 'complete*.zip' 'complete*.zip.part*'
sandbox_kit_collect_archive() {
  local out_name=$1 complete_pattern=$2 parts_pattern=$3 required=${4:-required}
  local -n out=$out_name
  local -a complete=() parts=()
  mapfile -t complete < <(sandbox_kit_find_matches "$complete_pattern")
  if ((${#complete[@]} > 1)); then
    printf 'ambiguous complete archive pattern %s:\n' "$complete_pattern" >&2
    printf '  %s\n' "${complete[@]}" >&2
    sandbox_kit_die 'remove duplicate complete archives or narrow SANDBOX_KIT_ASSET_ROOTS'
  fi
  if ((${#complete[@]} == 1)); then
    out=("${complete[0]}")
    return 0
  fi
  mapfile -t parts < <(sandbox_kit_find_matches "$parts_pattern" | LC_ALL=C sort -V)
  if ((${#parts[@]} == 0)); then
    [[ "$required" == optional ]] && { out=(); return 1; }
    sandbox_kit_die "archive not found: $complete_pattern or $parts_pattern"
  fi
  sandbox_kit_validate_parts "${parts[@]}"
  out=("${parts[@]}")
}

sandbox_kit_source_env_if_present() {
  local file=$1
  if [[ -f "$file" ]]; then
    # shellcheck disable=SC1090
    source "$file"
  fi
}
