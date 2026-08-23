#!/usr/bin/env bash
set -euo pipefail
usage(){ echo 'Usage: setup.sh [--work-dir DIR] <remotion.zip> <chrome-headless-shell.zip> <voicevox-parts.json> <7z-linux.tar.xz> [psd-tools-wheel]'; }
die(){ printf 'error: %s\n' "$*" >&2; exit 1; }
WORK_DIR=${VIDEO_KIT_WORK_DIR:-$PWD/.tools/video}; [[ -d /mnt/data ]] && WORK_DIR=${VIDEO_KIT_WORK_DIR:-/mnt/data/video-kit}
inputs=(); while (($#)); do case "$1" in --work-dir) (($# >= 2)) || die '--work-dir requires a directory'; WORK_DIR=$2; shift 2;; -h|--help) usage; exit 0;; -*) die "unknown option: $1";; *) inputs+=("$1"); shift;; esac; done
((${#inputs[@]} >= 4)) || { usage >&2; exit 2; }
REMOTION_ZIP=${inputs[0]}; CHROME_ZIP=${inputs[1]}; VOICEVOX_META=${inputs[2]}; SEVENZIP_TAR=${inputs[3]}; PSD_WHEEL=${inputs[4]:-}
for f in "$REMOTION_ZIP" "$CHROME_ZIP" "$VOICEVOX_META" "$SEVENZIP_TAR"; do [[ -f "$f" ]] || die "missing file: $f"; done
rm -rf "$WORK_DIR"; mkdir -p "$WORK_DIR"/{remotion,chrome,voicevox,7zip}

python3 - "$REMOTION_ZIP" "$WORK_DIR/remotion" <<'PY'
import pathlib, sys, zipfile
src, dst = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
with zipfile.ZipFile(src) as z:
    for info in z.infolist():
        name = info.filename.replace('\\','/').lstrip('/')
        if not name: continue
        out = (dst / name).resolve()
        if dst.resolve() not in out.parents and out != dst.resolve():
            raise SystemExit(f'unsafe zip path: {name}')
        if info.is_dir(): out.mkdir(parents=True, exist_ok=True); continue
        out.parent.mkdir(parents=True, exist_ok=True)
        with z.open(info) as r, out.open('wb') as w: w.write(r.read())
PY
REMOTION_PROJECT=$(find "$WORK_DIR/remotion" -type f -name package.json -printf '%h\n' | head -n1 || true)
[[ -n "$REMOTION_PROJECT" ]] || die 'Remotion package.json not found after extraction'
rm -rf "$REMOTION_PROJECT/node_modules"
( cd "$REMOTION_PROJECT"; npm ci --offline --cache "$REMOTION_PROJECT/npm-cache" --include=optional --no-audit --no-fund )

unzip -q "$CHROME_ZIP" -d "$WORK_DIR/chrome"
BROWSER_BIN=$(find "$WORK_DIR/chrome" -type f -name chrome-headless-shell -print -quit)
[[ -n "$BROWSER_BIN" ]] || die 'chrome-headless-shell not found'; chmod +x "$BROWSER_BIN"; "$BROWSER_BIN" --version

tar -xJf "$SEVENZIP_TAR" -C "$WORK_DIR/7zip"
SEVENZIP=$(find "$WORK_DIR/7zip" -type f \( -name 7zz -o -name 7z \) -print -quit)
[[ -n "$SEVENZIP" ]] || die '7zz not found'; chmod +x "$SEVENZIP"
VOICEVOX_ARCHIVE="$WORK_DIR/voicevox.7z.001"
python3 - "$VOICEVOX_META" "$VOICEVOX_ARCHIVE" <<'PY'
import hashlib, json, pathlib, sys
meta_path, out_path = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
meta=json.loads(meta_path.read_text(encoding='utf-8')); base=meta_path.parent
h=hashlib.sha256()
with out_path.open('wb') as out:
    for p in meta['parts']:
        src=base/p['name']
        if not src.exists() and pathlib.Path(str(src)+'.bin').exists(): src=pathlib.Path(str(src)+'.bin')
        if not src.exists(): raise SystemExit(f'missing VOICEVOX part: {p["name"]}')
        part_h=hashlib.sha256()
        with src.open('rb') as f:
            for chunk in iter(lambda: f.read(8 * 1024 * 1024), b''):
                part_h.update(chunk); h.update(chunk); out.write(chunk)
        actual=part_h.hexdigest()
        if actual.lower()!=p['sha256'].lower(): raise SystemExit(f'part hash mismatch: {src}')
if out_path.stat().st_size != meta['original_size']: raise SystemExit('VOICEVOX reconstructed size mismatch')
if h.hexdigest().lower()!=meta['original_sha256'].lower(): raise SystemExit('VOICEVOX reconstructed SHA-256 mismatch')
print('VOICEVOX SHA-256 OK:', h.hexdigest())
PY
"$SEVENZIP" x -y "$VOICEVOX_ARCHIVE" "-o$WORK_DIR/voicevox" >/dev/null
VOICEVOX_BIN=$(find "$WORK_DIR/voicevox" -type f \( -name run -o -name voicevox_engine \) -print -quit)
[[ -n "$VOICEVOX_BIN" ]] || die 'VOICEVOX executable not found'; chmod +x "$VOICEVOX_BIN"

PSD_PYTHON=
if [[ -n "$PSD_WHEEL" ]]; then
  WHEEL_DIR=$(dirname "$PSD_WHEEL")
  if python3 -m venv "$WORK_DIR/psd-venv" && "$WORK_DIR/psd-venv/bin/pip" install --no-index --find-links "$WHEEL_DIR" 'psd-tools[composite]==1.18.0'; then
    PSD_PYTHON="$WORK_DIR/psd-venv/bin/python"
  else
    echo "warning: psd-tools wheelhouse is incomplete; PSD support was skipped" >&2
    rm -rf "$WORK_DIR/psd-venv"
  fi
fi
cat > "$WORK_DIR/env.sh" <<ENV
export VIDEO_KIT_WORK_DIR=$(printf '%q' "$WORK_DIR")
export REMOTION_PROJECT_DIR=$(printf '%q' "$REMOTION_PROJECT")
export REMOTION_BROWSER_EXECUTABLE=$(printf '%q' "$BROWSER_BIN")
export REMOTION_CHROME_MODE=headless-shell
export VOICEVOX_ENGINE_BIN=$(printf '%q' "$VOICEVOX_BIN")
export PSD_TOOLS_PYTHON=$(printf '%q' "$PSD_PYTHON")
ENV
printf '[video-setup] Remotion: %s\n[video-setup] Browser: %s\n[video-setup] VOICEVOX: %s\n' "$REMOTION_PROJECT" "$BROWSER_BIN" "$VOICEVOX_BIN"
