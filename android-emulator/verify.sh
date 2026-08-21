#!/usr/bin/env bash
set -euo pipefail

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '[android-emulator-verify] %s\n' "$*"; }

if [[ -n "${ANDROID_EMULATOR_WORK_DIR:-}" ]]; then
  WORK_DIR=$ANDROID_EMULATOR_WORK_DIR
elif [[ -d /mnt/data/android-emulator-kit ]]; then
  WORK_DIR=/mnt/data/android-emulator-kit
else
  WORK_DIR="$PWD/.tools/android-emulator"
fi
SDK_ROOT=${ANDROID_SDK_ROOT:-$WORK_DIR/sdk}
ADB="$SDK_ROOT/platform-tools/adb"
EMULATOR="$SDK_ROOT/emulator/emulator"

[[ -x "$ADB" ]] || die "adb is missing or not executable: $ADB"
[[ -x "$EMULATOR" ]] || die "emulator is missing or not executable: $EMULATOR"

log 'adb version'
$ADB version
log 'emulator version'
$EMULATOR -version 2>&1 | head -n 2

if ldd "$ADB" | grep -q 'not found'; then
  ldd "$ADB" >&2
  die 'adb has missing shared-library dependencies'
fi
if ldd "$EMULATOR" | grep -q 'not found'; then
  ldd "$EMULATOR" >&2
  die 'emulator has missing shared-library dependencies'
fi

log 'adb server smoke test'
$ADB start-server >/dev/null
$ADB devices -l
$ADB kill-server >/dev/null

log 'acceleration status (non-fatal)'
$EMULATOR -accel-check || true
if [[ ! -e /dev/kvm ]]; then
  log 'note: /dev/kvm is absent; launch AVDs with -accel off / -no-accel'
fi

EMU_HELP=$($EMULATOR -help-all 2>&1 || true)
grep -q -- '-no-accel' <<<"$EMU_HELP" || die 'software acceleration-disable option not found'
log 'verification passed'
