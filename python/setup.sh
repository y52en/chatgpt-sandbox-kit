#!/usr/bin/env bash
set -euo pipefail
usage(){ echo 'Usage: setup.sh [--work-dir DIR] [--python CMD] <wheelhouse.tar.gz | part000 part001 ...>'; }
die(){ printf 'error: %s\n' "$*" >&2; exit 1; }
WORK_DIR=${PYTHON_KIT_WORK_DIR:-$PWD/.tools/python}; [[ -d /mnt/data ]] && WORK_DIR=${PYTHON_KIT_WORK_DIR:-/mnt/data/python-kit}
PYTHON=python3; inputs=()
while (($#)); do case "$1" in --work-dir) WORK_DIR=$2; shift 2;; --python) PYTHON=$2; shift 2;; -h|--help) usage; exit 0;; -*) die "unknown option: $1";; *) inputs+=("$1"); shift;; esac; done
((${#inputs[@]})) || die 'wheelhouse archive/parts required'; command -v "$PYTHON" >/dev/null || die "Python not found: $PYTHON"
rm -rf "$WORK_DIR"; mkdir -p "$WORK_DIR"; archive="$WORK_DIR/wheelhouse.tar.gz"
if ((${#inputs[@]} == 1)) && [[ ${inputs[0]} == *.tar.gz ]]; then cp "${inputs[0]}" "$archive"; else : > "$archive"; mapfile -t sorted < <(printf '%s\n' "${inputs[@]}" | sort -V); for p in "${sorted[@]}"; do [[ -f "$p" ]] || die "missing part: $p"; cat "$p" >> "$archive"; done; fi
tar -tzf "$archive" >/dev/null || die 'wheelhouse archive integrity check failed'; mkdir -p "$WORK_DIR/wheelhouse"; tar -xzf "$archive" -C "$WORK_DIR/wheelhouse"
mapfile -t wheels < <(find "$WORK_DIR/wheelhouse" -type f -name '*.whl'); ((${#wheels[@]})) || die 'no wheels found in wheelhouse'
"$PYTHON" -m venv "$WORK_DIR/venv"; "$WORK_DIR/venv/bin/python" -m pip --version >/dev/null
cat > "$WORK_DIR/env.sh" <<ENV
export PYTHON_KIT_VENV=$(printf '%q' "$WORK_DIR/venv")
export PIP_NO_INDEX=1
export PIP_FIND_LINKS=$(printf '%q' "$WORK_DIR/wheelhouse")
export PATH=$(printf '%q' "$WORK_DIR/venv/bin"):\$PATH
ENV
printf '[python-setup] wheelhouse: %d wheel(s)\n' "${#wheels[@]}"
printf '[python-setup] offline install example: pip install <package>\n'
