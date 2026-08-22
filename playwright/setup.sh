#!/usr/bin/env bash
set -euo pipefail
usage(){ echo 'Usage: setup.sh [--work-dir DIR] <playwright-bundle.tar.gz | part000 part001 ...>'; }
die(){ printf 'error: %s\n' "$*" >&2; exit 1; }
WORK_DIR=${PLAYWRIGHT_KIT_WORK_DIR:-$PWD/.tools/playwright}; [[ -d /mnt/data ]] && WORK_DIR=${PLAYWRIGHT_KIT_WORK_DIR:-/mnt/data/playwright-kit}
inputs=(); while (($#)); do case "$1" in --work-dir) WORK_DIR=$2; shift 2;; -h|--help) usage; exit 0;; -*) die "unknown option: $1";; *) inputs+=("$1"); shift;; esac; done
((${#inputs[@]})) || die 'browser bundle archive/parts required'; rm -rf "$WORK_DIR"; mkdir -p "$WORK_DIR"; archive="$WORK_DIR/browsers.tar.gz"
if ((${#inputs[@]} == 1)) && [[ ${inputs[0]} == *.tar.gz ]]; then cp "${inputs[0]}" "$archive"; else : > "$archive"; mapfile -t sorted < <(printf '%s\n' "${inputs[@]}" | sort -V); for p in "${sorted[@]}"; do [[ -f "$p" ]] || die "missing part: $p"; cat "$p" >> "$archive"; done; fi
tar -tzf "$archive" >/dev/null || die 'Playwright bundle integrity check failed'; mkdir -p "$WORK_DIR/extracted"; tar -xzf "$archive" -C "$WORK_DIR/extracted"
# Prefer a directory that directly contains Playwright browser revision folders.
BROWSERS=$(find "$WORK_DIR/extracted" -type d \( -name 'chromium-*' -o -name 'firefox-*' -o -name 'webkit-*' \) -printf '%h\n' | sort -u | head -n1 || true)
[[ -n "$BROWSERS" ]] || BROWSERS="$WORK_DIR/extracted"
cat > "$WORK_DIR/env.sh" <<ENV
export PLAYWRIGHT_BROWSERS_PATH=$(printf '%q' "$BROWSERS")
ENV
printf '[playwright-setup] PLAYWRIGHT_BROWSERS_PATH=%s\n' "$BROWSERS"
find "$BROWSERS" -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' | sort | head -50
