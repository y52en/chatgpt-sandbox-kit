#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: install-apk.sh [options] <app.apk>

Options:
  --work-dir DIR    Workspace used by setup scripts
  --serial SERIAL   ADB serial. Default: run/serial, then emulator-5554
  --package PKG     Expected package/application id (recommended for TCG)
  --timeout SEC     Overall install confirmation timeout. Default: 900
  --grant           Pass -g to grant runtime permissions
  -h, --help        Show this help

With --package, adb install runs in the background while this script polls the
package path. This avoids waiting for a slow TCG dexopt/client teardown after
PackageManager has already committed the APK under /data/app. For a package
that was already installed, the /data/app path must change unless adb itself
returns Success.
USAGE
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '[android-apk-install] %s\n' "$*"; }

if [[ -n "${ANDROID_EMULATOR_WORK_DIR:-}" ]]; then
  WORK_DIR=$ANDROID_EMULATOR_WORK_DIR
elif [[ -d /mnt/data/android-emulator-kit ]]; then
  WORK_DIR=/mnt/data/android-emulator-kit
else
  WORK_DIR="$PWD/.tools/android-emulator"
fi
SERIAL=
PACKAGE=
INSTALL_TIMEOUT=900
GRANT=0
APK=
while (($#)); do
  case "$1" in
    --work-dir) (($# >= 2)) || die '--work-dir requires a value'; WORK_DIR=$2; shift 2 ;;
    --serial) (($# >= 2)) || die '--serial requires a value'; SERIAL=$2; shift 2 ;;
    --package) (($# >= 2)) || die '--package requires a value'; PACKAGE=$2; shift 2 ;;
    --timeout) (($# >= 2)) || die '--timeout requires a value'; INSTALL_TIMEOUT=$2; shift 2 ;;
    --grant) GRANT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *) [[ -z "$APK" ]] || die 'only one APK may be supplied'; APK=$1; shift ;;
  esac
done
[[ -n "$APK" ]] || { usage >&2; exit 2; }
[[ -f "$APK" ]] || die "APK not found: $APK"
[[ "$INSTALL_TIMEOUT" =~ ^[0-9]+$ ]] || die '--timeout must be an integer'
command -v timeout >/dev/null || die 'timeout is required'

SDK_ROOT=${ANDROID_SDK_ROOT:-$WORK_DIR/sdk}
ADB="$SDK_ROOT/platform-tools/adb"
[[ -x "$ADB" ]] || die "adb is missing or not executable: $ADB"
if [[ -z "$SERIAL" && -f "$WORK_DIR/run/serial" ]]; then SERIAL=$(<"$WORK_DIR/run/serial"); fi
SERIAL=${SERIAL:-emulator-5554}
[[ "$(timeout -k 2s 10s "$ADB" -s "$SERIAL" get-state 2>/dev/null || true)" == device ]] || die "$SERIAL is not an online ADB device"

# Discover the application id when local Android build tools happen to exist.
if [[ -z "$PACKAGE" ]]; then
  if command -v aapt2 >/dev/null; then
    PACKAGE=$(aapt2 dump badging "$APK" 2>/dev/null | sed -n "s/^package: name='\([^']*\)'.*/\1/p" | head -n1 || true)
  elif command -v aapt >/dev/null; then
    PACKAGE=$(aapt dump badging "$APK" 2>/dev/null | sed -n "s/^package: name='\([^']*\)'.*/\1/p" | head -n1 || true)
  elif command -v apkanalyzer >/dev/null; then
    PACKAGE=$(apkanalyzer manifest application-id "$APK" 2>/dev/null | tr -d '\r' || true)
  fi
fi

ARGS=(-r -t --no-streaming)
((GRANT)) && ARGS+=(-g)
RUN_DIR="$WORK_DIR/run"
mkdir -p "$RUN_DIR"
INSTALL_LOG="$RUN_DIR/adb-install-$(date +%Y%m%d-%H%M%S).log"

pm_path() {
  [[ -n "$PACKAGE" ]] || return 0
  timeout -k 2s 10s "$ADB" -s "$SERIAL" shell pm path "$PACKAGE" 2>/dev/null | tr -d '\r' || true
}

BEFORE_PATHS=$(pm_path)
log "installing $(basename "$APK") on $SERIAL${PACKAGE:+ as $PACKAGE}"
setsid "$ADB" -s "$SERIAL" install "${ARGS[@]}" "$APK" </dev/null >"$INSTALL_LOG" 2>&1 &
INSTALL_PID=$!
terminate_client() {
  if [[ "$INSTALL_PID" != 0 ]] && kill -0 "$INSTALL_PID" 2>/dev/null; then
    kill -TERM -- "-$INSTALL_PID" 2>/dev/null || kill -TERM "$INSTALL_PID" 2>/dev/null || true
    sleep 1
    kill -KILL -- "-$INSTALL_PID" 2>/dev/null || kill -KILL "$INSTALL_PID" 2>/dev/null || true
  fi
  disown "$INSTALL_PID" 2>/dev/null || true
  INSTALL_PID=0
}
trap terminate_client EXIT

START=$(date +%s)
DEADLINE=$((START + INSTALL_TIMEOUT))
while (( $(date +%s) < DEADLINE )); do
  if ! kill -0 "$INSTALL_PID" 2>/dev/null; then
    set +e
    wait "$INSTALL_PID"
    STATUS=$?
    set -e
    INSTALL_PID=0
    OUTPUT=$(cat "$INSTALL_LOG")
    printf '%s\n' "$OUTPUT"
    if ((STATUS == 0)) && grep -q '^Success' <<<"$OUTPUT"; then
      trap - EXIT
      log 'install succeeded'
      exit 0
    fi
    die "adb install failed with status $STATUS"
  fi

  if [[ -n "$PACKAGE" ]]; then
    AFTER_PATHS=$(pm_path)
    if grep -q '^package:/data/app/' <<<"$AFTER_PATHS"; then
      if [[ -z "$BEFORE_PATHS" || "$AFTER_PATHS" != "$BEFORE_PATHS" ]]; then
        printf '%s\n' "$AFTER_PATHS"
        log 'PackageManager committed the APK under /data/app; not waiting for slow dexopt/client teardown'
        terminate_client
        trap - EXIT
        exit 0
      fi
    fi
  fi
  ELAPSED=$(( $(date +%s) - START ))
  if ((ELAPSED % 15 < 3)); then
    log "waiting for PackageManager commit (${ELAPSED}s)"
  fi
  sleep 3
done

OUTPUT=$(cat "$INSTALL_LOG" 2>/dev/null || true)
printf '%s\n' "$OUTPUT"
die "APK installation was not confirmed within ${INSTALL_TIMEOUT}s${PACKAGE:+ for $PACKAGE}"
