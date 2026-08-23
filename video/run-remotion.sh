#!/usr/bin/env bash
set -euo pipefail
WORK=${VIDEO_KIT_WORK_DIR:-/mnt/data/video-kit}; [[ -f "$WORK/env.sh" ]] || { echo "missing $WORK/env.sh; run video/setup.sh first" >&2; exit 1; }
# shellcheck disable=SC1090
source "$WORK/env.sh"
cd "$REMOTION_PROJECT_DIR"
exec npx --no-install remotion "$@" --browser-executable="$REMOTION_BROWSER_EXECUTABLE" --chrome-mode=headless-shell
