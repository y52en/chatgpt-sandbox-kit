#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  cat <<'EOF'
Usage: setup.sh [--archive PATH] [--skip-pyghidra]

Installs Ghidra into .tools/ghidra and verifies the archive before extraction.
If --archive is omitted, fetch.sh is used. A sibling <archive>.manifest.json
from ghidra-dist makes setup use that release's version, digest, and Java
requirement dynamically.
EOF
}

archive=''
skip_pyghidra=false
while (($#)); do
  case "$1" in
    --archive) archive="${2:?missing path}"; shift 2 ;;
    --skip-pyghidra) skip_pyghidra=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

require_command unzip
require_command java
require_command python3

if [[ -z "$archive" ]]; then
  archive="$($GHIDRA_KIT_DIR/fetch.sh)"
fi
[[ -f "$archive" ]] || die "archive not found: $archive"
load_archive_metadata "$archive"

actual="$(sha256_file "$archive")"
[[ "$actual" == "$GHIDRA_ACTIVE_SHA256" ]] || die "archive SHA-256 mismatch: expected $GHIDRA_ACTIVE_SHA256, got $actual"

java_major="$(java_major_version)"
[[ -n "$java_major" && "$java_major" -ge "$GHIDRA_ACTIVE_JAVA_MIN" ]] || \
  die "Ghidra $GHIDRA_ACTIVE_VERSION requires JDK $GHIDRA_ACTIVE_JAVA_MIN+; found ${java_major:-unknown}"

mkdir -p "$GHIDRA_INSTALLS_DIR"
install_dir="$GHIDRA_INSTALLS_DIR/$GHIDRA_ACTIVE_VERSION"
if [[ ! -x "$install_dir/support/analyzeHeadless" ]]; then
  stage="$(mktemp -d "$GHIDRA_INSTALLS_DIR/.stage.XXXXXX")"
  trap 'rm -rf "$stage"' EXIT
  log "extracting verified Ghidra $GHIDRA_ACTIVE_VERSION"
  unzip -q "$archive" -d "$stage"
  mapfile -t roots < <(find "$stage" -mindepth 1 -maxdepth 1 -type d -print)
  [[ ${#roots[@]} -eq 1 ]] || die 'unexpected archive layout: expected exactly one top-level directory'
  [[ -x "${roots[0]}/support/analyzeHeadless" ]] || die 'archive is missing support/analyzeHeadless'
  rm -rf "$install_dir"
  mv "${roots[0]}" "$install_dir"
  rm -rf "$stage"
  trap - EXIT
else
  log "Ghidra $GHIDRA_ACTIVE_VERSION is already installed"
fi

ln -sfn "$install_dir" "$GHIDRA_HOME"

if [[ "$skip_pyghidra" == false ]]; then
  pyver="$(python_version_tuple)"
  py_ok="$(python3 - "$pyver" "$GHIDRA_PYTHON_MIN" "$GHIDRA_PYTHON_MAX" <<'PY'
import sys
v, lo, hi = (tuple(map(int, x.split('.'))) for x in sys.argv[1:])
print(int(lo <= v <= hi))
PY
)"
  if [[ "$py_ok" == 1 ]]; then
    dist="$GHIDRA_HOME/Ghidra/Features/PyGhidra/pypkg/dist"
    if [[ -d "$dist" ]]; then
      if [[ ! -x "$GHIDRA_PYGHIDRA_VENV/bin/python" ]]; then
        log 'creating offline PyGhidra virtual environment'
        python3 -m venv "$GHIDRA_PYGHIDRA_VENV"
      fi
      "$GHIDRA_PYGHIDRA_VENV/bin/python" -m pip install --disable-pip-version-check \
        --no-index -f "$dist" pyghidra >/dev/null
    else
      warn 'PyGhidra wheel directory was not found in this distribution'
    fi
  else
    warn "Python $pyver is outside the pinned PyGhidra range $GHIDRA_PYTHON_MIN-$GHIDRA_PYTHON_MAX; skipping PyGhidra venv"
  fi
fi

log "installed Ghidra $GHIDRA_ACTIVE_VERSION at $install_dir"
printf '%s\n' "$GHIDRA_HOME"
