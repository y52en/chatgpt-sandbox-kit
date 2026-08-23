#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
WORK=${VIDEO_KIT_WORK_DIR:-/mnt/data/video-kit}; [[ -f "$WORK/env.sh" ]] || { echo "missing $WORK/env.sh; run video/setup.sh first" >&2; exit 1; }
# shellcheck disable=SC1090
source "$WORK/env.sh"
"$REMOTION_BROWSER_EXECUTABLE" --version
TMP=$(mktemp -d); PORT=${VIDEO_SMOKE_PORT:-18765}; SERVER_PID=
cleanup(){ [[ -z "$SERVER_PID" ]] || kill "$SERVER_PID" >/dev/null 2>&1 || true; rm -rf "$TMP"; }; trap cleanup EXIT
printf '<!doctype html><title>video-kit</title><p>VIDEO_KIT_LOCALHOST_OK</p>\n' > "$TMP/index.html"
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$TMP" >/dev/null 2>&1 & SERVER_PID=$!; sleep 0.5
out=$("$REMOTION_BROWSER_EXECUTABLE" --no-sandbox --disable-gpu --dump-dom "http://127.0.0.1:$PORT/index.html" 2>/dev/null || true)
grep -q VIDEO_KIT_LOCALHOST_OK <<<"$out" || { echo 'dedicated browser could not load localhost' >&2; exit 1; }
echo '[video-smoke] localhost browser test: OK'
bash "$ROOT/run-remotion.sh" compositions
echo '[video-smoke] Remotion compositions: OK'
