#!/usr/bin/env bash
set -euo pipefail
usage(){ echo 'Usage: setup.sh [--work-dir DIR] <debs.tar.gz | part000 part001 ...>'; }
die(){ printf 'error: %s\n' "$*" >&2; exit 1; }
WORK_DIR=${LINUX_TOOLS_KIT_WORK_DIR:-$PWD/.tools/linux-tools}; [[ -d /mnt/data ]] && WORK_DIR=${LINUX_TOOLS_KIT_WORK_DIR:-/mnt/data/linux-tools-kit}
inputs=(); while (($#)); do case "$1" in --work-dir) WORK_DIR=$2; shift 2;; -h|--help) usage; exit 0;; -*) die "unknown option: $1";; *) inputs+=("$1"); shift;; esac; done
((${#inputs[@]})) || die 'deb bundle archive/parts required'; command -v dpkg-deb >/dev/null || die 'dpkg-deb is required'
rm -rf "$WORK_DIR"; mkdir -p "$WORK_DIR"; archive="$WORK_DIR/debs.tar.gz"
if ((${#inputs[@]} == 1)) && [[ ${inputs[0]} == *.tar.gz ]]; then cp "${inputs[0]}" "$archive"; else : > "$archive"; mapfile -t sorted < <(printf '%s\n' "${inputs[@]}" | sort -V); for p in "${sorted[@]}"; do [[ -f "$p" ]] || die "missing part: $p"; cat "$p" >> "$archive"; done; fi
tar -tzf "$archive" >/dev/null || die 'deb bundle integrity check failed'; mkdir -p "$WORK_DIR/debs" "$WORK_DIR/root"; tar -xzf "$archive" -C "$WORK_DIR/debs"
mapfile -t debs < <(find "$WORK_DIR/debs" -type f -name '*.deb' | sort); ((${#debs[@]})) || die 'no .deb files found in bundle'
for deb in "${debs[@]}"; do dpkg-deb -x "$deb" "$WORK_DIR/root"; done
cat > "$WORK_DIR/env.sh" <<ENV
export LINUX_TOOLS_ROOT=$(printf '%q' "$WORK_DIR/root")
export PATH=$(printf '%q' "$WORK_DIR/root/usr/bin:$WORK_DIR/root/usr/sbin"):\$PATH
export LD_LIBRARY_PATH=$(printf '%q' "$WORK_DIR/root/usr/lib/x86_64-linux-gnu:$WORK_DIR/root/lib/x86_64-linux-gnu"):\${LD_LIBRARY_PATH:-}
ENV
printf '[linux-tools-setup] extracted %d deb package(s) rootlessly\n' "${#debs[@]}"
for tool in gdb qemu-system-x86_64 strace ltrace clang gcc cmake ninja; do [[ -x "$WORK_DIR/root/usr/bin/$tool" ]] && printf '  %s\n' "$tool" || true; done
printf '[linux-tools-setup] environment file: %s\n' "$WORK_DIR/env.sh"
