#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  smoke-test.sh --package PKG [options] <app.apk>
  smoke-test.sh --package PKG --skip-install [options]

Options:
  --work-dir DIR     Workspace used by setup scripts
  --serial SERIAL    ADB serial. Default: run/serial, then emulator-5554
  --package PKG      Package/application id (required)
  --activity COMP    Explicit component for am start, e.g. .MainActivity
  --skip-install     Test an already-installed package
  --install-timeout SEC  Passed to install-apk.sh. Default: 900
  --settle SEC       Seconds to observe after launch. Default: 10
  -h, --help         Show this help

The test clears logcat, launches the app, records a PNG screenshot and logcat,
and fails on package-scoped Java/native crashes or ANRs detected after launch.
USAGE
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '[android-apk-smoke] %s\n' "$*"; }

if [[ -n "${ANDROID_EMULATOR_WORK_DIR:-}" ]]; then
  WORK_DIR=$ANDROID_EMULATOR_WORK_DIR
elif [[ -d /mnt/data/android-emulator-kit ]]; then
  WORK_DIR=/mnt/data/android-emulator-kit
else
  WORK_DIR="$PWD/.tools/android-emulator"
fi
SERIAL=
PACKAGE=
ACTIVITY=
SKIP_INSTALL=0
INSTALL_TIMEOUT=900
SETTLE=10
APK=
while (($#)); do
  case "$1" in
    --work-dir) (($# >= 2)) || die '--work-dir requires a value'; WORK_DIR=$2; shift 2 ;;
    --serial) (($# >= 2)) || die '--serial requires a value'; SERIAL=$2; shift 2 ;;
    --package) (($# >= 2)) || die '--package requires a value'; PACKAGE=$2; shift 2 ;;
    --activity) (($# >= 2)) || die '--activity requires a value'; ACTIVITY=$2; shift 2 ;;
    --skip-install) SKIP_INSTALL=1; shift ;;
    --install-timeout) (($# >= 2)) || die '--install-timeout requires a value'; INSTALL_TIMEOUT=$2; shift 2 ;;
    --settle) (($# >= 2)) || die '--settle requires a value'; SETTLE=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *) [[ -z "$APK" ]] || die 'only one APK may be supplied'; APK=$1; shift ;;
  esac
done
[[ -n "$PACKAGE" ]] || die '--package is required'
((SKIP_INSTALL)) || [[ -n "$APK" ]] || die 'APK is required unless --skip-install is used'
[[ "$SETTLE" =~ ^[0-9]+$ ]] || die '--settle must be an integer'

SDK_ROOT=${ANDROID_SDK_ROOT:-$WORK_DIR/sdk}
ADB="$SDK_ROOT/platform-tools/adb"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ -z "$SERIAL" && -f "$WORK_DIR/run/serial" ]]; then SERIAL=$(<"$WORK_DIR/run/serial"); fi
SERIAL=${SERIAL:-emulator-5554}
[[ -x "$ADB" ]] || die "adb is missing or not executable: $ADB"

if ((SKIP_INSTALL == 0)); then
  "$SCRIPT_DIR/install-apk.sh" --work-dir "$WORK_DIR" --serial "$SERIAL" \
    --package "$PACKAGE" --timeout "$INSTALL_TIMEOUT" "$APK"
fi

RUN_DIR="$WORK_DIR/run"
mkdir -p "$RUN_DIR"
STAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="$RUN_DIR/smoke-$STAMP.logcat.txt"
SCREEN_FILE="$RUN_DIR/smoke-$STAMP.png"

timeout -k 2s 8s "$ADB" -s "$SERIAL" shell 'logcat -c' >/dev/null 2>&1 || true
if [[ -n "$ACTIVITY" ]]; then
  [[ "$ACTIVITY" == */* ]] && COMPONENT=$ACTIVITY || COMPONENT="$PACKAGE/$ACTIVITY"
else
  log "resolving launcher activity for $PACKAGE"
  RESOLVED=$(timeout -k 2s 12s "$ADB" -s "$SERIAL" shell cmd package resolve-activity --brief \
    -a android.intent.action.MAIN -c android.intent.category.LAUNCHER "$PACKAGE" 2>/dev/null | tr -d '\r' || true)
  COMPONENT=$(grep -E '^[A-Za-z0-9_.]+/[A-Za-z0-9_.$]+' <<<"$RESOLVED" | tail -n1 || true)
  [[ -n "$COMPONENT" ]] || die 'could not resolve a launcher activity; pass --activity explicitly'
fi

log "launching $COMPONENT"
set +e
START_OUTPUT=$(timeout -k 2s 12s "$ADB" -s "$SERIAL" shell am start -n "$COMPONENT" 2>&1)
START_STATUS=$?
set -e
printf '%s\n' "$START_OUTPUT" | tr -d '\r'
if ((START_STATUS != 0 && START_STATUS != 124)); then
  die "am start failed with status $START_STATUS"
fi

sleep "$SETTLE"
set +e
timeout -k 2s 15s "$ADB" -s "$SERIAL" exec-out screencap -p > "$SCREEN_FILE"
SCREEN_STATUS=$?
set -e
python3 - "$SCREEN_FILE" <<'PYPNG'
import sys
from pathlib import Path
p = Path(sys.argv[1])
data = p.read_bytes()
if len(data) < 8 or data[:8] != b"\x89PNG\r\n\x1a\n":
    raise SystemExit("screenshot is not a valid PNG stream")
PYPNG
if ((SCREEN_STATUS == 124)); then
  log 'screencap client timed out after receiving a valid PNG; accepting the artifact'
elif ((SCREEN_STATUS != 0)); then
  die "screencap failed with status $SCREEN_STATUS"
fi

timeout -k 2s 15s "$ADB" -s "$SERIAL" shell 'logcat -d -t 2000' > "$LOG_FILE" 2>/dev/null || true

python3 - "$LOG_FILE" "$PACKAGE" <<'PY'
import sys
from pathlib import Path
log = Path(sys.argv[1]).read_text(errors="replace").splitlines()
pkg = sys.argv[2]
hits = []
for i, line in enumerate(log):
    if f"ANR in {pkg}" in line or f">>> {pkg} <<<" in line:
        hits.append("\n".join(log[max(0, i-3):min(len(log), i+8)]))
    if "FATAL EXCEPTION" in line:
        window = log[i:min(len(log), i+15)]
        if any(f"Process: {pkg}" in x for x in window):
            hits.append("\n".join(window))
if hits:
    print("\n\n".join(hits), file=sys.stderr)
    raise SystemExit(1)
PY

log "passed"
log "screenshot: $SCREEN_FILE"
log "logcat:     $LOG_FILE"
