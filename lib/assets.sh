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
  local expected_start= expected_count=
  while (($#)); do
    case "$1" in
      --expected-start) (($# >= 2)) || { printf 'error: --expected-start requires a value\n' >&2; return 1; }; expected_start=$2; shift 2 ;;
      --expected-count) (($# >= 2)) || { printf 'error: --expected-count requires a value\n' >&2; return 1; }; expected_count=$2; shift 2 ;;
      --) shift; break ;;
      *) break ;;
    esac
  done

  local start=-1 expected=-1 number path base width=0
  local -a inputs=("$@")
  ((${#inputs[@]} > 0)) || { printf 'error: no split parts supplied\n' >&2; return 1; }

  for path in "${inputs[@]}"; do
    base=$(basename "$path")
    if [[ "$base" =~ \.part([0-9]+)(\.bin)?$ ]]; then
      number=$((10#${BASH_REMATCH[1]}))
      ((width == 0)) && width=${#BASH_REMATCH[1]}
      if ((${#BASH_REMATCH[1]} != width)); then
        printf 'error: inconsistent split-part number width: %s\n' "$base" >&2
        return 1
      fi
    else
      printf 'error: cannot parse split-part suffix: %s\n' "$base" >&2
      return 1
    fi
    if ((start < 0)); then
      start=$number
      expected=$number
      ((start == 0 || start == 1)) || { printf 'error: split parts must start at part000 or part001: %s\n' "$base" >&2; return 1; }
      if [[ -n "$expected_start" ]] && ((start != expected_start)); then
        printf 'error: split archive starts at part%0*d; expected part%0*d\n' "$width" "$start" "$width" "$expected_start" >&2
        return 1
      fi
    fi
    if ((number != expected)); then
      printf 'error: split archive gap: expected part%0*d, got %s\n' "$width" "$expected" "$base" >&2
      return 1
    fi
    expected=$((expected + 1))
  done

  if [[ -n "$expected_count" ]] && ((${#inputs[@]} != expected_count)); then
    printf 'error: split archive has %d part(s); expected %d\n' "${#inputs[@]}" "$expected_count" >&2
    return 1
  fi
}

# Populate a caller-owned array with either one complete archive or validated split parts.
# Usage: sandbox_kit_collect_archive OUT complete_pattern parts_pattern [required] [expected_start] [expected_count]
sandbox_kit_collect_archive() {
  local out_name=$1 complete_pattern=$2 parts_pattern=$3 required=${4:-required}
  local expected_start=${5:-} expected_count=${6:-}
  local -n out=$out_name
  local -a complete=() parts=() validate_args=()
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
  [[ -z "$expected_start" ]] || validate_args+=(--expected-start "$expected_start")
  [[ -z "$expected_count" ]] || validate_args+=(--expected-count "$expected_count")
  sandbox_kit_validate_parts "${validate_args[@]}" -- "${parts[@]}" || sandbox_kit_die "invalid split archive: $parts_pattern"
  out=("${parts[@]}")
}

sandbox_kit_source_env_if_present() {
  local file=$1
  if [[ -f "$file" ]]; then
    # shellcheck disable=SC1090
    source "$file"
  fi
}
