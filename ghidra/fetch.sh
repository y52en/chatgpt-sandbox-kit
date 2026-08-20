#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  cat <<'EOF'
Usage: fetch.sh [--output PATH] [--official]

Downloads a verified Ghidra archive.

By default this script first tries the sandbox-friendly split distribution on
this repository's ghidra-dist branch. If it is unavailable, it falls back to
the pinned upstream release in version.env.

Options:
  --output PATH  Destination archive path.
  --official     Skip ghidra-dist and fetch the pinned upstream release.

Environment:
  GHIDRA_DIST_BASE_URL  Override split-distribution base URL.
  GHIDRA_DOWNLOAD_URL   Override the direct fallback URL. The expected SHA-256
                        remains pinned, so mirrors/proxies cannot silently
                        replace the file.
EOF
}

output=''
official=false
while (($#)); do
  case "$1" in
    --output) output="${2:?missing path after --output}"; shift 2 ;;
    --official) official=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

require_command python3
require_command curl
mkdir -p "$GHIDRA_DOWNLOADS_DIR"

repo_slug="${GITHUB_REPOSITORY:-y52en/chatgpt-sandbox-kit}"
dist_base="${GHIDRA_DIST_BASE_URL:-https://raw.githubusercontent.com/${repo_slug}/ghidra-dist/current}"

fetch_dist() {
  local manifest tmpdir archive filename expected actual
  tmpdir="$(mktemp -d "$GHIDRA_DOWNLOADS_DIR/.dist.XXXXXX")"
  trap 'rm -rf "$tmpdir"' RETURN
  manifest="$tmpdir/manifest.json"

  log "trying split distribution: $dist_base/manifest.json"
  if ! curl --fail --location --silent --show-error --retry 2 \
      --output "$manifest" "$dist_base/manifest.json"; then
    return 1
  fi

  filename="$(manifest_value "$manifest" filename)"
  archive="${output:-$GHIDRA_DOWNLOADS_DIR/$filename}"

  GHIDRA_DIST_BASE_URL="$dist_base" "$GHIDRA_KIT_DIR/assemble.sh" \
    --manifest "$manifest" --output "$archive"
  cp "$manifest" "${archive}.manifest.json"
  printf '%s\n' "$archive"
}

fetch_direct() {
  local url archive actual
  url="${GHIDRA_DOWNLOAD_URL:-$GHIDRA_URL}"
  archive="${output:-$GHIDRA_DOWNLOADS_DIR/$GHIDRA_FILENAME}"
  log "downloading direct release: $url"
  curl --fail --location --show-error --retry 3 --retry-all-errors \
    --output "${archive}.partial" "$url"
  actual="$(sha256_file "${archive}.partial")"
  [[ "$actual" == "$GHIDRA_SHA256" ]] || {
    rm -f "${archive}.partial"
    die "SHA-256 mismatch: expected $GHIDRA_SHA256, got $actual"
  }
  mv "${archive}.partial" "$archive"
  rm -f "${archive}.manifest.json"
  printf '%s\n' "$archive"
}

if [[ "$official" == false ]]; then
  if archive="$(fetch_dist)"; then
    printf '%s\n' "$archive"
    exit 0
  fi
  warn 'split distribution unavailable; falling back to direct upstream download'
fi
fetch_direct
