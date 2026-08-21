#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  setup.sh [options] <chrome-linux64.zip> [chromedriver-linux64.zip]

Options:
  --work-dir DIR       Workspace. Default: /mnt/data/chrome-kit when available,
                       otherwise ./.tools/chrome
  --chrome-sha256 HEX  Expected SHA-256 for Chrome ZIP
  --driver-sha256 HEX  Expected SHA-256 for ChromeDriver ZIP
  -h, --help           Show this help

No network access is used. The script extracts Chrome for Testing, checks its
version, runs a headless data: URL smoke test, and optionally verifies that the
ChromeDriver version exactly matches Chrome.
USAGE
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '[chrome-setup] %s\n' "$*"; }

if [[ -d /mnt/data ]]; then WORK_DIR=/mnt/data/chrome-kit; else WORK_DIR="$PWD/.tools/chrome"; fi
CHROME_SHA256=
DRIVER_SHA256=
CHROME_ZIP=
DRIVER_ZIP=

while (($#)); do
  case "$1" in
    --work-dir) (($# >= 2)) || die '--work-dir requires a value'; WORK_DIR=$2; shift 2 ;;
    --chrome-sha256) (($# >= 2)) || die '--chrome-sha256 requires a value'; CHROME_SHA256=${2,,}; shift 2 ;;
    --driver-sha256) (($# >= 2)) || die '--driver-sha256 requires a value'; DRIVER_SHA256=${2,,}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *)
      case "$(basename "$1")" in
        chrome-linux64.zip) [[ -z "$CHROME_ZIP" ]] || die 'multiple Chrome ZIPs supplied'; CHROME_ZIP=$1 ;;
        chromedriver-linux64.zip) [[ -z "$DRIVER_ZIP" ]] || die 'multiple ChromeDriver ZIPs supplied'; DRIVER_ZIP=$1 ;;
        *) die "unrecognized artifact: $1" ;;
      esac
      shift
      ;;
  esac
done

[[ -n "$CHROME_ZIP" ]] || die 'chrome-linux64.zip is required'
[[ -f "$CHROME_ZIP" ]] || die "file not found: $CHROME_ZIP"
[[ -z "$DRIVER_ZIP" || -f "$DRIVER_ZIP" ]] || die "file not found: $DRIVER_ZIP"
for cmd in unzip sha256sum stat; do command -v "$cmd" >/dev/null || die "$cmd is required"; done

verify_hash() {
  local label=$1 path=$2 expected=$3 actual
  actual=$(sha256sum "$path" | awk '{print $1}')
  log "$label: $(basename "$path") ($(stat -c '%s' "$path") bytes)"
  log "$label SHA-256: $actual"
  [[ -z "$expected" || "$actual" == "$expected" ]] || die "$label SHA-256 mismatch (expected $expected)"
}

verify_hash Chrome "$CHROME_ZIP" "$CHROME_SHA256"
[[ -z "$DRIVER_ZIP" ]] || verify_hash ChromeDriver "$DRIVER_ZIP" "$DRIVER_SHA256"
unzip -tq "$CHROME_ZIP" >/dev/null
[[ -z "$DRIVER_ZIP" ]] || unzip -tq "$DRIVER_ZIP" >/dev/null

rm -rf -- "$WORK_DIR"
mkdir -p "$WORK_DIR"
unzip -q "$CHROME_ZIP" -d "$WORK_DIR"
CHROME="$WORK_DIR/chrome-linux64/chrome"
[[ -x "$CHROME" ]] || die "Chrome binary not found: $CHROME"
CHROME_VERSION=$("$CHROME" --version | awk '{print $NF}')
log "Chrome version: $CHROME_VERSION"

DOM=$("$CHROME" --headless=new --no-sandbox --disable-gpu \
  --dump-dom 'data:text/html,<title>sandbox-kit</title><h1>chrome-smoke-ok</h1>' 2>/dev/null)
grep -q '<h1>chrome-smoke-ok</h1>' <<<"$DOM" || die 'headless DOM smoke test failed'
log 'headless DOM smoke test: OK'

if [[ -n "$DRIVER_ZIP" ]]; then
  unzip -q "$DRIVER_ZIP" -d "$WORK_DIR"
  DRIVER="$WORK_DIR/chromedriver-linux64/chromedriver"
  [[ -x "$DRIVER" ]] || die "ChromeDriver binary not found: $DRIVER"
  DRIVER_VERSION=$("$DRIVER" --version | awk '{print $2}')
  log "ChromeDriver version: $DRIVER_VERSION"
  [[ "$DRIVER_VERSION" == "$CHROME_VERSION" ]] || die "Chrome/ChromeDriver version mismatch"
  log 'Chrome/ChromeDriver version match: OK'
fi

cat > "$WORK_DIR/env.sh" <<ENV
export CHROME_BIN=$(printf '%q' "$CHROME")
${DRIVER:+export CHROMEDRIVER_BIN=$(printf '%q' "$DRIVER")}
ENV
log "environment file: $WORK_DIR/env.sh"
