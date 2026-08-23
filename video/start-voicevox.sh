#!/usr/bin/env bash
set -euo pipefail
WORK=${VIDEO_KIT_WORK_DIR:-/mnt/data/video-kit}; [[ -f "$WORK/env.sh" ]] || { echo "missing $WORK/env.sh; run video/setup.sh first" >&2; exit 1; }
# shellcheck disable=SC1090
source "$WORK/env.sh"
exec "$VOICEVOX_ENGINE_BIN" --host "${VOICEVOX_HOST:-127.0.0.1}" --port "${VOICEVOX_PORT:-50021}"
