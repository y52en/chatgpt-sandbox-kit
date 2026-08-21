#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  setup.sh [options] <commandlinetools-linux-*_latest.zip> [platform-tools-latest-linux.zip]

Options:
  --work-dir DIR       SDK workspace. Default: /mnt/data/android-tools-kit when
                       available, otherwise ./.tools/android-tools
  --cmdline-sha256 HEX Expected SHA-256 for command-line tools ZIP
  --platform-sha256 HEX Expected SHA-256 for platform-tools ZIP
  -h, --help           Show this help

The script is offline-only. It lays command-line tools out at
<SDK>/cmdline-tools/latest and verifies sdkmanager. It deliberately does not
invoke the newer `android` launcher because current packages bootstrap the
standalone Android CLI from dl.google.com on first use.
USAGE
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '[android-tools-setup] %s\n' "$*"; }

if [[ -d /mnt/data ]]; then WORK_DIR=/mnt/data/android-tools-kit; else WORK_DIR="$PWD/.tools/android-tools"; fi
CMDLINE_SHA256=
PLATFORM_SHA256=
CMDLINE_ZIP=
PLATFORM_ZIP=

while (($#)); do
  case "$1" in
    --work-dir) (($# >= 2)) || die '--work-dir requires a value'; WORK_DIR=$2; shift 2 ;;
    --cmdline-sha256) (($# >= 2)) || die '--cmdline-sha256 requires a value'; CMDLINE_SHA256=${2,,}; shift 2 ;;
    --platform-sha256) (($# >= 2)) || die '--platform-sha256 requires a value'; PLATFORM_SHA256=${2,,}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *)
      case "$(basename "$1")" in
        commandlinetools-linux-*_latest.zip) [[ -z "$CMDLINE_ZIP" ]] || die 'multiple command-line tools ZIPs'; CMDLINE_ZIP=$1 ;;
        platform-tools-latest-linux.zip) [[ -z "$PLATFORM_ZIP" ]] || die 'multiple platform-tools ZIPs'; PLATFORM_ZIP=$1 ;;
        *) die "unrecognized artifact: $1" ;;
      esac
      shift
      ;;
  esac
done

[[ -n "$CMDLINE_ZIP" ]] || die 'Android command-line tools ZIP is required'
[[ -f "$CMDLINE_ZIP" ]] || die "file not found: $CMDLINE_ZIP"
[[ -z "$PLATFORM_ZIP" || -f "$PLATFORM_ZIP" ]] || die "file not found: $PLATFORM_ZIP"
for cmd in unzip sha256sum stat java; do command -v "$cmd" >/dev/null || die "$cmd is required"; done

verify_hash() {
  local label=$1 path=$2 expected=$3 actual
  actual=$(sha256sum "$path" | awk '{print $1}')
  log "$label: $(basename "$path") ($(stat -c '%s' "$path") bytes)"
  log "$label SHA-256: $actual"
  [[ -z "$expected" || "$actual" == "$expected" ]] || die "$label SHA-256 mismatch (expected $expected)"
}
verify_hash 'command-line tools' "$CMDLINE_ZIP" "$CMDLINE_SHA256"
[[ -z "$PLATFORM_ZIP" ]] || verify_hash 'platform tools' "$PLATFORM_ZIP" "$PLATFORM_SHA256"
unzip -tq "$CMDLINE_ZIP" >/dev/null
[[ -z "$PLATFORM_ZIP" ]] || unzip -tq "$PLATFORM_ZIP" >/dev/null

rm -rf -- "$WORK_DIR"
mkdir -p "$WORK_DIR/cmdline-tools/latest"
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
unzip -q "$CMDLINE_ZIP" -d "$TMP"
[[ -d "$TMP/cmdline-tools" ]] || die 'unexpected command-line tools ZIP layout'
cp -a "$TMP/cmdline-tools/." "$WORK_DIR/cmdline-tools/latest/"
if [[ -n "$PLATFORM_ZIP" ]]; then unzip -q "$PLATFORM_ZIP" -d "$WORK_DIR"; fi

SDKMANAGER="$WORK_DIR/cmdline-tools/latest/bin/sdkmanager"
[[ -x "$SDKMANAGER" ]] || die "sdkmanager not found: $SDKMANAGER"
# ChatGPT sandboxes may expose proxy variables that Java's URL parser rejects.
SDK_VERSION=$(env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy \
  "$SDKMANAGER" --sdk_root="$WORK_DIR" --version 2>/dev/null | awk 'NF { line=$0 } END { print line }')
[[ -n "$SDK_VERSION" ]] || die 'sdkmanager version smoke test failed'
log "sdkmanager version: $SDK_VERSION"

if [[ -x "$WORK_DIR/platform-tools/adb" ]]; then
  log "adb: $("$WORK_DIR/platform-tools/adb" version | head -n1)"
fi

cat > "$WORK_DIR/env.sh" <<ENV
export ANDROID_SDK_ROOT=$(printf '%q' "$WORK_DIR")
export ANDROID_HOME=$(printf '%q' "$WORK_DIR")
export PATH=$(printf '%q' "$WORK_DIR/cmdline-tools/latest/bin:$WORK_DIR/platform-tools"):\$PATH
ENV
log "environment file: $WORK_DIR/env.sh"
