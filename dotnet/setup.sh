#!/usr/bin/env bash
set -euo pipefail
usage(){ echo 'Usage: setup.sh [--work-dir DIR] <dotnet-sdk-linux-x64.tar.gz>'; }
die(){ printf 'error: %s\n' "$*" >&2; exit 1; }
WORK_DIR=${DOTNET_KIT_WORK_DIR:-$PWD/.tools/dotnet}; [[ -d /mnt/data ]] && WORK_DIR=${DOTNET_KIT_WORK_DIR:-/mnt/data/dotnet-kit}
SDK=
while (($#)); do case "$1" in --work-dir) WORK_DIR=$2; shift 2;; -h|--help) usage; exit 0;; -*) die "unknown option: $1";; *) [[ -z "$SDK" ]] || die 'only one SDK archive may be supplied'; SDK=$1; shift;; esac; done
[[ -f "$SDK" ]] || die '.NET SDK archive is required'
rm -rf "$WORK_DIR"; mkdir -p "$WORK_DIR/sdk"; tar -xzf "$SDK" -C "$WORK_DIR/sdk"
DOTNET_ROOT="$WORK_DIR/sdk"; [[ -x "$DOTNET_ROOT/dotnet" ]] || die 'dotnet binary not found after extraction'
DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 "$DOTNET_ROOT/dotnet" --info
cat > "$WORK_DIR/env.sh" <<ENV
export DOTNET_ROOT=$(printf '%q' "$DOTNET_ROOT")
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1
export PATH=$(printf '%q' "$DOTNET_ROOT"):\$PATH
ENV
