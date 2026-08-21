#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: boot.sh [options]

Options:
  --work-dir DIR    Workspace used by setup scripts
  --avd-name NAME   AVD name. Default: ci-api30
  --port PORT       Emulator console/ADB port. Default: 5554
  --timeout SEC     Ready timeout. Default: 1200
  --wipe-data       Reset userdata before boot
  --fresh           Kill an existing emulator on the selected port first
  -h, --help        Show this help

The script launches a headless emulator, uses software CPU emulation when
/dev/kvm is unavailable, and waits for Android to remain healthy across two probes five seconds apart
(boot properties + package/activity/window services).
USAGE
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '[android-emulator-boot] %s\n' "$*"; }

if [[ -n "${ANDROID_EMULATOR_WORK_DIR:-}" ]]; then
  WORK_DIR=$ANDROID_EMULATOR_WORK_DIR
elif [[ -d /mnt/data/android-emulator-kit ]]; then
  WORK_DIR=/mnt/data/android-emulator-kit
else
  WORK_DIR="$PWD/.tools/android-emulator"
fi
AVD_NAME=ci-api30
PORT=5554
READY_TIMEOUT=1200
WIPE_DATA=0
FRESH=0

while (($#)); do
  case "$1" in
    --work-dir) (($# >= 2)) || die '--work-dir requires a value'; WORK_DIR=$2; shift 2 ;;
    --avd-name) (($# >= 2)) || die '--avd-name requires a value'; AVD_NAME=$2; shift 2 ;;
    --port) (($# >= 2)) || die '--port requires a value'; PORT=$2; shift 2 ;;
    --timeout) (($# >= 2)) || die '--timeout requires a value'; READY_TIMEOUT=$2; shift 2 ;;
    --wipe-data) WIPE_DATA=1; shift ;;
    --fresh) FRESH=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

[[ "$PORT" =~ ^[0-9]+$ ]] || die '--port must be an integer'
[[ "$READY_TIMEOUT" =~ ^[0-9]+$ ]] || die '--timeout must be an integer'
command -v timeout >/dev/null || die 'timeout is required'

SDK_ROOT=${ANDROID_SDK_ROOT:-$WORK_DIR/sdk}
AVD_HOME=${ANDROID_AVD_HOME:-$WORK_DIR/avd}
ADB="$SDK_ROOT/platform-tools/adb"
EMULATOR="$SDK_ROOT/emulator/emulator"
SERIAL="emulator-$PORT"
RUN_DIR="$WORK_DIR/run"
LOG_FILE="$RUN_DIR/emulator-$PORT.log"
PID_FILE="$RUN_DIR/emulator-$PORT.pid"
mkdir -p "$RUN_DIR"
[[ -x "$ADB" ]] || die "adb is missing or not executable: $ADB"
[[ -x "$EMULATOR" ]] || die "emulator is missing or not executable: $EMULATOR"
[[ -f "$AVD_HOME/$AVD_NAME.ini" ]] || die "AVD not found: $AVD_HOME/$AVD_NAME.ini"

adb_state() { timeout -k 5s 10s "$ADB" -s "$SERIAL" get-state 2>/dev/null || true; }

if ((FRESH)); then
  if [[ -n "$(adb_state)" ]]; then
    log "stopping existing $SERIAL"
    timeout -k 5s 15s "$ADB" -s "$SERIAL" emu kill >/dev/null 2>&1 || true
    sleep 2
  fi
fi

if [[ -z "$(adb_state)" ]]; then
  ACCEL_ARGS=()
  if [[ ! -e /dev/kvm ]]; then
    ACCEL_ARGS=(-accel off)
    log '/dev/kvm is unavailable; using software CPU emulation (-accel off)'
  else
    log '/dev/kvm is available; using Emulator default acceleration'
  fi
  WIPE_ARGS=()
  ((WIPE_DATA)) && WIPE_ARGS=(-wipe-data)

  log "starting AVD $AVD_NAME as $SERIAL"
  nohup env \
    ANDROID_HOME="$SDK_ROOT" \
    ANDROID_SDK_ROOT="$SDK_ROOT" \
    ANDROID_AVD_HOME="$AVD_HOME" \
    "$EMULATOR" -avd "$AVD_NAME" -port "$PORT" \
      -no-window -no-audio -no-boot-anim -no-snapshot -no-metrics -no-cache \
      -gpu swiftshader_indirect \
      "${ACCEL_ARGS[@]}" "${WIPE_ARGS[@]}" \
      >"$LOG_FILE" 2>&1 &
  echo $! > "$PID_FILE"
else
  log "reusing existing $SERIAL"
fi

health_snapshot() {
  timeout -k 5s 45s "$ADB" -s "$SERIAL" shell '
    for n in 1 2; do
      echo probe=$n
      echo sys=$(getprop sys.boot_completed)
      echo dev=$(getprop dev.bootcomplete)
      echo bootanim=$(getprop init.svc.bootanim)
      service check package
      service check activity
      service check window
      echo release=$(getprop ro.build.version.release)
      echo sdk=$(getprop ro.build.version.sdk)
      echo abi=$(getprop ro.product.cpu.abi)
      [ "$n" = 1 ] && sleep 5
    done
  ' 2>/dev/null | tr -d '\r' || true
}

healthy_snapshot() {
  local snapshot=$1
  [[ $(grep -c '^probe=' <<<"$snapshot") -eq 2 ]] || return 1
  [[ $(grep -c '^sys=1$' <<<"$snapshot") -eq 2 ]] || return 1
  [[ $(grep -c '^dev=1$' <<<"$snapshot") -eq 2 ]] || return 1
  [[ $(grep -c '^bootanim=stopped$' <<<"$snapshot") -eq 2 ]] || return 1
  [[ $(grep -c '^Service package: found$' <<<"$snapshot") -eq 2 ]] || return 1
  [[ $(grep -c '^Service activity: found$' <<<"$snapshot") -eq 2 ]] || return 1
  [[ $(grep -c '^Service window: found$' <<<"$snapshot") -eq 2 ]] || return 1
}

START=$(date +%s)
DEADLINE=$((START + READY_TIMEOUT))
LAST_REPORT=0
LAST_HEALTH=
READY=0
while (( $(date +%s) < DEADLINE )); do
  NOW=$(date +%s)
  STATE=$(adb_state)
  if [[ "$STATE" == device ]]; then
    LAST_HEALTH=$(health_snapshot)
    if healthy_snapshot "$LAST_HEALTH"; then
      READY=1
      log 'stable health check passed (2 probes, 5 seconds apart)'
      break
    fi
  fi

  if ((NOW - LAST_REPORT >= 30)); then
    SYS=$(sed -n 's/^sys=//p' <<<"$LAST_HEALTH" | tail -n1)
    log "waiting: adb=${STATE:-absent}, sys.boot_completed=${SYS:-?}, elapsed=$((NOW - START))s"
    LAST_REPORT=$NOW
  fi
  sleep 5
done

if ((READY == 0)); then
  printf '\n--- emulator log tail ---\n' >&2
  tail -n 120 "$LOG_FILE" >&2 2>/dev/null || true
  die "Android did not become stably ready within ${READY_TIMEOUT}s"
fi

# UI animation tuning is intentionally left to the test harness; avoid an extra
# ADB round trip here because software-emulated guests can stall briefly.

RELEASE=$(sed -n 's/^release=//p' <<<"$LAST_HEALTH" | tail -n1)
SDK=$(sed -n 's/^sdk=//p' <<<"$LAST_HEALTH" | tail -n1)
ABI=$(sed -n 's/^abi=//p' <<<"$LAST_HEALTH" | tail -n1)
log "ready: Android ${RELEASE:-?} / API ${SDK:-?} / ${ABI:-?} / $SERIAL"
printf '%s\n' "$SERIAL" > "$RUN_DIR/serial"
