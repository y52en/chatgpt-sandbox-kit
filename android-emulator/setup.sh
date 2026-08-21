#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  setup.sh [options] <platform-tools.zip> <emulator.zip>
  setup.sh [options] <platform-tools.zip> <emulator.part001> <emulator.part002> [...]

Options:
  --work-dir DIR              Installation workspace. Default: $ANDROID_EMULATOR_WORK_DIR,
                              then /mnt/data/android-emulator-kit when /mnt/data exists,
                              otherwise ./.tools/android-emulator
  --platform-tools-sha256 HEX Expected SHA-256 for the Platform Tools ZIP
  --emulator-sha256 HEX       Expected SHA-256 for the complete/reconstructed Emulator ZIP
  --keep-zips                 Keep copied/reconstructed ZIPs after setup
  -h, --help                  Show this help

This script is offline-only. It never downloads Android SDK components.
The first positional argument must be a Linux Platform Tools ZIP. Remaining
arguments are either one Linux Emulator ZIP or split parts that concatenate to it.
USAGE
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '[android-emulator-setup] %s\n' "$*"; }

if [[ -n "${ANDROID_EMULATOR_WORK_DIR:-}" ]]; then
  WORK_DIR=$ANDROID_EMULATOR_WORK_DIR
elif [[ -d /mnt/data ]]; then
  WORK_DIR=/mnt/data/android-emulator-kit
else
  WORK_DIR="$PWD/.tools/android-emulator"
fi
PT_SHA256=
EMU_SHA256=
KEEP_ZIPS=0
INPUTS=()

while (($#)); do
  case "$1" in
    --work-dir) (($# >= 2)) || die '--work-dir requires a value'; WORK_DIR=$2; shift 2 ;;
    --platform-tools-sha256) (($# >= 2)) || die '--platform-tools-sha256 requires a value'; PT_SHA256=${2,,}; shift 2 ;;
    --emulator-sha256) (($# >= 2)) || die '--emulator-sha256 requires a value'; EMU_SHA256=${2,,}; shift 2 ;;
    --keep-zips) KEEP_ZIPS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; INPUTS+=("$@"); break ;;
    -*) die "unknown option: $1" ;;
    *) INPUTS+=("$1"); shift ;;
  esac
done

((${#INPUTS[@]} >= 2)) || { usage >&2; exit 2; }
command -v unzip >/dev/null || die 'unzip is required'
command -v sha256sum >/dev/null || die 'sha256sum is required'
command -v ldd >/dev/null || die 'ldd is required'

PLATFORM_ZIP_INPUT=${INPUTS[0]}
EMULATOR_INPUTS=("${INPUTS[@]:1}")
[[ -f "$PLATFORM_ZIP_INPUT" ]] || die "Platform Tools ZIP not found: $PLATFORM_ZIP_INPUT"
for input in "${EMULATOR_INPUTS[@]}"; do
  [[ -f "$input" ]] || die "Emulator input not found: $input"
done

mkdir -p "$WORK_DIR"
SDK_ROOT="$WORK_DIR/sdk"
ARCHIVE_DIR="$WORK_DIR/archives"
PLATFORM_ZIP="$ARCHIVE_DIR/platform-tools.zip"
EMULATOR_ZIP="$ARCHIVE_DIR/emulator.zip"
ENV_FILE="$WORK_DIR/env.sh"
mkdir -p "$SDK_ROOT" "$ARCHIVE_DIR"

log 'copying Platform Tools ZIP'
cp -- "$PLATFORM_ZIP_INPUT" "$PLATFORM_ZIP"

if ((${#EMULATOR_INPUTS[@]} == 1)) && [[ "${EMULATOR_INPUTS[0]}" == *.zip ]]; then
  log 'copying Emulator ZIP'
  cp -- "${EMULATOR_INPUTS[0]}" "$EMULATOR_ZIP"
else
  log "reconstructing Emulator ZIP from ${#EMULATOR_INPUTS[@]} local parts"
  mapfile -t SORTED_PARTS < <(printf '%s\n' "${EMULATOR_INPUTS[@]}" | LC_ALL=C sort -V)
  : > "$EMULATOR_ZIP"
  for part in "${SORTED_PARTS[@]}"; do
    log "  + $(basename "$part") ($(stat -c '%s' "$part") bytes)"
    cat -- "$part" >> "$EMULATOR_ZIP"
  done
fi

PT_ACTUAL_SHA256=$(sha256sum "$PLATFORM_ZIP" | awk '{print $1}')
EMU_ACTUAL_SHA256=$(sha256sum "$EMULATOR_ZIP" | awk '{print $1}')
log "Platform Tools ZIP: $(stat -c '%s' "$PLATFORM_ZIP") bytes; SHA-256 $PT_ACTUAL_SHA256"
log "Emulator ZIP: $(stat -c '%s' "$EMULATOR_ZIP") bytes; SHA-256 $EMU_ACTUAL_SHA256"
[[ -z "$PT_SHA256" || "$PT_ACTUAL_SHA256" == "$PT_SHA256" ]] || die "Platform Tools SHA-256 mismatch (expected $PT_SHA256)"
[[ -z "$EMU_SHA256" || "$EMU_ACTUAL_SHA256" == "$EMU_SHA256" ]] || die "Emulator SHA-256 mismatch (expected $EMU_SHA256)"

log 'testing ZIP integrity'
unzip -tq "$PLATFORM_ZIP" >/dev/null || die 'Platform Tools ZIP integrity check failed'
unzip -tq "$EMULATOR_ZIP" >/dev/null || die 'Emulator ZIP integrity check failed'

log 'extracting SDK components'
rm -rf -- "$SDK_ROOT/platform-tools" "$SDK_ROOT/emulator"
unzip -q "$PLATFORM_ZIP" -d "$SDK_ROOT"
unzip -q "$EMULATOR_ZIP" -d "$SDK_ROOT"

ADB="$SDK_ROOT/platform-tools/adb"
EMULATOR="$SDK_ROOT/emulator/emulator"
[[ -f "$ADB" ]] || die "adb not found at expected path: $ADB"
[[ -f "$EMULATOR" ]] || die "emulator not found at expected path: $EMULATOR"
chmod +x "$ADB" "$EMULATOR" 2>/dev/null || true

ADB_LDD=$(ldd "$ADB" 2>&1 || true)
if grep -q 'not found' <<<"$ADB_LDD"; then
  printf '%s\n' "$ADB_LDD" >&2
  die 'adb has missing shared-library dependencies'
fi
EMU_LDD=$(ldd "$EMULATOR" 2>&1 || true)
if grep -q 'not found' <<<"$EMU_LDD"; then
  printf '%s\n' "$EMU_LDD" >&2
  die 'emulator has missing shared-library dependencies'
fi

log 'verifying adb'
ADB_VERSION=$($ADB version)
printf '%s\n' "$ADB_VERSION"
log 'verifying emulator binary'
EMU_VERSION=$($EMULATOR -version 2>&1)
printf '%s\n' "$EMU_VERSION" | sed -n '1,2p'

log 'verifying adb server startup'
$ADB start-server >/dev/null
$ADB devices -l
$ADB kill-server >/dev/null

EMU_HELP=$($EMULATOR -help-all 2>&1 || true)
if grep -q -- '-no-accel' <<<"$EMU_HELP"; then
  log 'software CPU emulation option is available (-no-accel / -accel off)'
else
  die 'emulator does not advertise -no-accel / -accel off support'
fi

if [[ -e /dev/kvm ]]; then
  log '/dev/kvm is available; hardware acceleration may be usable'
else
  log '/dev/kvm is not available; use -accel off (actual AVD boot requires a system image)'
fi

cat > "$ENV_FILE" <<ENV
# Generated by android-emulator/setup.sh
export ANDROID_HOME=$(printf '%q' "$SDK_ROOT")
export ANDROID_SDK_ROOT=$(printf '%q' "$SDK_ROOT")
export PATH=$(printf '%q' "$SDK_ROOT/platform-tools:$SDK_ROOT/emulator"):\$PATH
ENV

if ((KEEP_ZIPS == 0)); then
  rm -f -- "$PLATFORM_ZIP" "$EMULATOR_ZIP"
fi

cat <<EOF2

Setup complete.
  SDK root: $SDK_ROOT
  env:      $ENV_FILE

Use:
  source $(printf '%q' "$ENV_FILE")
  adb version
  emulator -version

An Android system image/AVD is intentionally not created by this script yet.
EOF2
