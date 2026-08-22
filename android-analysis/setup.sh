#!/usr/bin/env bash
set -euo pipefail
usage(){ echo 'Usage: setup.sh [--work-dir DIR] <apktool.jar> <jadx.zip>'; }
die(){ printf 'error: %s\n' "$*" >&2; exit 1; }
WORK_DIR=${ANDROID_ANALYSIS_WORK_DIR:-$PWD/.tools/android-analysis}; [[ -d /mnt/data ]] && WORK_DIR=${ANDROID_ANALYSIS_WORK_DIR:-/mnt/data/android-analysis-kit}
APKTOOL= JADX=
while (($#)); do case "$1" in --work-dir) WORK_DIR=$2; shift 2;; -h|--help) usage; exit 0;; -*) die "unknown option: $1";; *) case "$(basename "$1")" in apktool_*.jar) APKTOOL=$1;; jadx-*.zip) JADX=$1;; *) die "unrecognized artifact: $1";; esac; shift;; esac; done
[[ -f "$APKTOOL" && -f "$JADX" ]] || die 'apktool jar and JADX zip are required'; command -v java >/dev/null || die 'Java is required'; command -v unzip >/dev/null || die 'unzip is required'
rm -rf "$WORK_DIR"; mkdir -p "$WORK_DIR/bin" "$WORK_DIR/jadx"; cp "$APKTOOL" "$WORK_DIR/apktool.jar"; unzip -q "$JADX" -d "$WORK_DIR/jadx"
JADX_BIN=$(find "$WORK_DIR/jadx" -type f -path '*/bin/jadx' | head -n1); [[ -n "$JADX_BIN" ]] || die 'jadx launcher not found'; chmod +x "$JADX_BIN"
cat > "$WORK_DIR/bin/apktool" <<SCRIPT
#!/usr/bin/env bash
exec java -jar $(printf '%q' "$WORK_DIR/apktool.jar") "\$@"
SCRIPT
cat > "$WORK_DIR/bin/jadx" <<SCRIPT
#!/usr/bin/env bash
exec $(printf '%q' "$JADX_BIN") "\$@"
SCRIPT
chmod +x "$WORK_DIR/bin/apktool" "$WORK_DIR/bin/jadx"
"$WORK_DIR/bin/apktool" --version >/dev/null; "$WORK_DIR/bin/jadx" --version >/dev/null
cat > "$WORK_DIR/env.sh" <<ENV
export ANDROID_ANALYSIS_HOME=$(printf '%q' "$WORK_DIR")
export PATH=$(printf '%q' "$WORK_DIR/bin"):\$PATH
ENV
printf '[android-analysis] apktool=%s, jadx=%s\n' "$("$WORK_DIR/bin/apktool" --version)" "$("$WORK_DIR/bin/jadx" --version)"
