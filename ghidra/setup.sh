#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  setup.sh [options] <ghidra.zip>
  setup.sh [options] <part001> <part002> [part003 ...]

Options:
  --work-dir DIR       Installation workspace. Default: $GHIDRA_WORK_DIR,
                       then /mnt/data/ghidra-kit when /mnt/data exists,
                       otherwise ./.tools/ghidra
  --python CMD         Python interpreter to use. Default: python3
  --sha256 HEX         Expected SHA-256 for the reconstructed ZIP
  --keep-zip           Keep the reconstructed ZIP after setup
  -h, --help           Show this help

The script never downloads Ghidra or Python packages from the network.
PyGhidra is installed only from wheels bundled inside the supplied Ghidra ZIP.
USAGE
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '[ghidra-setup] %s\n' "$*"; }

if [[ -n "${GHIDRA_WORK_DIR:-}" ]]; then
  WORK_DIR=$GHIDRA_WORK_DIR
elif [[ -d /mnt/data ]]; then
  WORK_DIR=/mnt/data/ghidra-kit
else
  WORK_DIR="$PWD/.tools/ghidra"
fi
PYTHON=python3
EXPECTED_SHA256=
KEEP_ZIP=0
INPUTS=()

while (($#)); do
  case "$1" in
    --work-dir) (($# >= 2)) || die '--work-dir requires a value'; WORK_DIR=$2; shift 2 ;;
    --python) (($# >= 2)) || die '--python requires a value'; PYTHON=$2; shift 2 ;;
    --sha256) (($# >= 2)) || die '--sha256 requires a value'; EXPECTED_SHA256=${2,,}; shift 2 ;;
    --keep-zip) KEEP_ZIP=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; INPUTS+=("$@"); break ;;
    -*) die "unknown option: $1" ;;
    *) INPUTS+=("$1"); shift ;;
  esac
done

((${#INPUTS[@]} > 0)) || { usage >&2; exit 2; }
command -v unzip >/dev/null || die 'unzip is required'
command -v sha256sum >/dev/null || die 'sha256sum is required'
command -v java >/dev/null || die 'Java is required'
command -v "$PYTHON" >/dev/null || die "Python interpreter not found: $PYTHON"

mkdir -p "$WORK_DIR"
ZIP_PATH="$WORK_DIR/ghidra.zip"
EXTRACT_DIR="$WORK_DIR/install"
VENV_DIR="$WORK_DIR/venv"
ENV_FILE="$WORK_DIR/env.sh"

for input in "${INPUTS[@]}"; do
  [[ -f "$input" ]] || die "input file not found: $input"
done

if ((${#INPUTS[@]} == 1)) && [[ "${INPUTS[0]}" == *.zip ]]; then
  log "copying local ZIP"
  cp -- "${INPUTS[0]}" "$ZIP_PATH"
else
  log "reconstructing ZIP from ${#INPUTS[@]} local parts"
  mapfile -t SORTED_INPUTS < <(printf '%s\n' "${INPUTS[@]}" | LC_ALL=C sort -V)
  : > "$ZIP_PATH"
  for part in "${SORTED_INPUTS[@]}"; do
    log "  + $(basename "$part") ($(stat -c '%s' "$part") bytes)"
    cat -- "$part" >> "$ZIP_PATH"
  done
fi

ACTUAL_SHA256=$(sha256sum "$ZIP_PATH" | awk '{print $1}')
log "ZIP size: $(stat -c '%s' "$ZIP_PATH") bytes"
log "SHA-256: $ACTUAL_SHA256"
if [[ -n "$EXPECTED_SHA256" && "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
  die "SHA-256 mismatch (expected $EXPECTED_SHA256)"
fi

log 'testing ZIP integrity'
unzip -tq "$ZIP_PATH" >/dev/null || die 'ZIP integrity check failed'

log 'extracting Ghidra'
rm -rf -- "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"
unzip -q "$ZIP_PATH" -d "$EXTRACT_DIR"

mapfile -t GHIDRA_RUNS < <(find "$EXTRACT_DIR" -mindepth 1 -maxdepth 3 -type f -name ghidraRun -print)
((${#GHIDRA_RUNS[@]} == 1)) || die "expected exactly one ghidraRun, found ${#GHIDRA_RUNS[@]}"
GHIDRA_HOME=$(dirname "${GHIDRA_RUNS[0]}")
PROPERTIES="$GHIDRA_HOME/Ghidra/application.properties"
[[ -f "$PROPERTIES" ]] || die "missing Ghidra/application.properties under $GHIDRA_HOME"
chmod +x "$GHIDRA_HOME/ghidraRun" "$GHIDRA_HOME/support/analyzeHeadless" 2>/dev/null || true

prop() { sed -n "s/^$1=//p" "$PROPERTIES" | head -n1; }
GHIDRA_VERSION=$(prop application.version)
JAVA_MIN=$(prop application.java.min)
PYTHON_SUPPORTED=$(prop application.python.supported)
[[ -n "$GHIDRA_VERSION" ]] || die 'could not read Ghidra version'

JAVA_VERSION=$(java -version 2>&1 | sed -n '1s/.*version "\([^"]*\)".*/\1/p')
JAVA_MAJOR=${JAVA_VERSION%%.*}
if [[ "$JAVA_MAJOR" == 1 ]]; then JAVA_MAJOR=$(cut -d. -f2 <<<"$JAVA_VERSION"); fi
[[ "$JAVA_MAJOR" =~ ^[0-9]+$ ]] || die "could not determine Java version from: $JAVA_VERSION"
if [[ -n "$JAVA_MIN" && "$JAVA_MAJOR" -lt "$JAVA_MIN" ]]; then
  die "Ghidra $GHIDRA_VERSION requires Java >= $JAVA_MIN; found $JAVA_VERSION"
fi

PYTHON_VERSION=$($PYTHON -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
if [[ -n "$PYTHON_SUPPORTED" ]]; then
  case ", ${PYTHON_SUPPORTED//,/ ,} ," in
    *", $PYTHON_VERSION ,"*) ;;
    *) die "Ghidra $GHIDRA_VERSION does not list Python $PYTHON_VERSION as supported (supported: $PYTHON_SUPPORTED)" ;;
  esac
fi

DIST_DIR="$GHIDRA_HOME/Ghidra/Features/PyGhidra/pypkg/dist"
[[ -d "$DIST_DIR" ]] || die 'this Ghidra distribution does not contain the bundled PyGhidra package directory'
mapfile -t PYGHIDRA_WHEELS < <(find "$DIST_DIR" -maxdepth 1 -type f -name 'pyghidra-*.whl' -print | sort -V)
((${#PYGHIDRA_WHEELS[@]} > 0)) || die 'bundled PyGhidra wheel not found'
PYGHIDRA_WHEEL=${PYGHIDRA_WHEELS[-1]}

log "Ghidra: $GHIDRA_VERSION"
log "Java: $JAVA_VERSION (minimum: ${JAVA_MIN:-unknown})"
log "Python: $PYTHON_VERSION"
log 'creating isolated Python environment'
rm -rf -- "$VENV_DIR"
"$PYTHON" -m venv "$VENV_DIR"

log 'installing PyGhidra from bundled wheels only (network disabled)'
"$VENV_DIR/bin/python" -m pip install \
  --disable-pip-version-check \
  --no-index \
  --find-links "$DIST_DIR" \
  "$PYGHIDRA_WHEEL"

cat > "$ENV_FILE" <<ENV
# Generated by ghidra/setup.sh
export GHIDRA_INSTALL_DIR=$(printf '%q' "$GHIDRA_HOME")
export PYGHIDRA_VENV=$(printf '%q' "$VENV_DIR")
ENV

log 'starting PyGhidra/JVM smoke test'
GHIDRA_INSTALL_DIR="$GHIDRA_HOME" "$VENV_DIR/bin/python" -P - <<'PY'
import pyghidra
pyghidra.start()
from ghidra.framework import Application
print(f"PyGhidra {pyghidra.__version__}; Ghidra {Application.getApplicationVersion()}")
PY

if ((KEEP_ZIP == 0)); then
  rm -f -- "$ZIP_PATH"
fi

cat <<EOF

Setup complete.
  Ghidra:  $GHIDRA_HOME
  venv:    $VENV_DIR
  env:     $ENV_FILE

Use:
  GHIDRA_WORK_DIR=$(printf '%q' "$WORK_DIR") ./ghidra/pyghidra.sh --help
  GHIDRA_WORK_DIR=$(printf '%q' "$WORK_DIR") ./ghidra/python.sh your_script.py
EOF
