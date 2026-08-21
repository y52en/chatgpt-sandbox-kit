#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  install-system-image.sh [options] <system-image.zip>
  install-system-image.sh [options] <part001> <part002> [...]

Options:
  --work-dir DIR       Workspace. Default: $ANDROID_EMULATOR_WORK_DIR,
                       then /mnt/data/android-emulator-kit when /mnt/data exists,
                       otherwise ./.tools/android-emulator
  --sha256 HEX         Expected SHA-256 for the complete/reconstructed ZIP
  --avd-name NAME      AVD name. Default: ci-api30
  --memory MB          AVD RAM. Default: 2048
  --cores N            AVD virtual CPU count. Default: 2
  --data-size BYTES    AVD data partition size. Default: 4294967296 (4 GiB)
  --keep-zip           Keep the reconstructed ZIP after installation
  -h, --help           Show this help

The script never downloads Android SDK components. It reads source.properties
from the supplied system-image ZIP, installs the image below ANDROID_SDK_ROOT,
and creates an AVD directly without requiring sdkmanager/avdmanager.
USAGE
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '[android-system-image] %s\n' "$*"; }

if [[ -n "${ANDROID_EMULATOR_WORK_DIR:-}" ]]; then
  WORK_DIR=$ANDROID_EMULATOR_WORK_DIR
elif [[ -d /mnt/data ]]; then
  WORK_DIR=/mnt/data/android-emulator-kit
else
  WORK_DIR="$PWD/.tools/android-emulator"
fi
EXPECTED_SHA256=
AVD_NAME=ci-api30
MEMORY=2048
CORES=2
DATA_SIZE=4294967296
KEEP_ZIP=0
INPUTS=()

while (($#)); do
  case "$1" in
    --work-dir) (($# >= 2)) || die '--work-dir requires a value'; WORK_DIR=$2; shift 2 ;;
    --sha256) (($# >= 2)) || die '--sha256 requires a value'; EXPECTED_SHA256=${2,,}; shift 2 ;;
    --avd-name) (($# >= 2)) || die '--avd-name requires a value'; AVD_NAME=$2; shift 2 ;;
    --memory) (($# >= 2)) || die '--memory requires a value'; MEMORY=$2; shift 2 ;;
    --cores) (($# >= 2)) || die '--cores requires a value'; CORES=$2; shift 2 ;;
    --data-size) (($# >= 2)) || die '--data-size requires a value'; DATA_SIZE=$2; shift 2 ;;
    --keep-zip) KEEP_ZIP=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; INPUTS+=("$@"); break ;;
    -*) die "unknown option: $1" ;;
    *) INPUTS+=("$1"); shift ;;
  esac
done

((${#INPUTS[@]} > 0)) || { usage >&2; exit 2; }
[[ "$AVD_NAME" =~ ^[A-Za-z0-9._-]+$ ]] || die 'AVD name contains unsupported characters'
[[ "$MEMORY" =~ ^[0-9]+$ ]] || die '--memory must be an integer'
[[ "$CORES" =~ ^[0-9]+$ ]] || die '--cores must be an integer'
[[ "$DATA_SIZE" =~ ^[0-9]+$ ]] || die '--data-size must be an integer'
command -v unzip >/dev/null || die 'unzip is required'
command -v sha256sum >/dev/null || die 'sha256sum is required'

SDK_ROOT=${ANDROID_SDK_ROOT:-$WORK_DIR/sdk}
AVD_HOME=${ANDROID_AVD_HOME:-$WORK_DIR/avd}
ARCHIVE_DIR="$WORK_DIR/archives"
SYSTEM_ZIP="$ARCHIVE_DIR/system-image.zip"
STAGE_DIR="$WORK_DIR/.system-image-stage"
ENV_FILE="$WORK_DIR/env.sh"
mkdir -p "$SDK_ROOT" "$AVD_HOME" "$ARCHIVE_DIR"

for input in "${INPUTS[@]}"; do
  [[ -f "$input" ]] || die "system-image input not found: $input"
done

if ((${#INPUTS[@]} == 1)) && [[ "${INPUTS[0]}" == *.zip ]]; then
  log 'copying system-image ZIP'
  cp -- "${INPUTS[0]}" "$SYSTEM_ZIP"
else
  log "reconstructing system-image ZIP from ${#INPUTS[@]} local parts"
  mapfile -t SORTED_INPUTS < <(printf '%s\n' "${INPUTS[@]}" | LC_ALL=C sort -V)
  : > "$SYSTEM_ZIP"
  for part in "${SORTED_INPUTS[@]}"; do
    log "  + $(basename "$part") ($(stat -c '%s' "$part") bytes)"
    cat -- "$part" >> "$SYSTEM_ZIP"
  done
fi

ACTUAL_SHA256=$(sha256sum "$SYSTEM_ZIP" | awk '{print $1}')
log "ZIP size: $(stat -c '%s' "$SYSTEM_ZIP") bytes"
log "SHA-256: $ACTUAL_SHA256"
[[ -z "$EXPECTED_SHA256" || "$ACTUAL_SHA256" == "$EXPECTED_SHA256" ]] || \
  die "SHA-256 mismatch (expected $EXPECTED_SHA256)"

log 'testing ZIP integrity'
unzip -tq "$SYSTEM_ZIP" >/dev/null || die 'system-image ZIP integrity check failed'

mapfile -t PROP_ENTRIES < <(unzip -Z1 "$SYSTEM_ZIP" | grep -E '(^|/)source\.properties$' || true)
((${#PROP_ENTRIES[@]} == 1)) || die "expected exactly one source.properties, found ${#PROP_ENTRIES[@]}"
PROP_ENTRY=${PROP_ENTRIES[0]}
PROPS=$(unzip -p "$SYSTEM_ZIP" "$PROP_ENTRY")
prop() { sed -n "s/^$1=//p" <<<"$PROPS" | head -n1; }
API=$(prop AndroidVersion.ApiLevel)
ABI=$(prop SystemImage.Abi)
TAG=$(prop SystemImage.TagId)
TAG_DISPLAY=$(prop SystemImage.TagDisplay)
REVISION=$(prop Pkg.Revision)
[[ "$API" =~ ^[0-9]+$ ]] || die 'could not read AndroidVersion.ApiLevel'
[[ -n "$ABI" ]] || die 'could not read SystemImage.Abi'
[[ -n "$TAG" ]] || die 'could not read SystemImage.TagId'

IMAGE_REL="system-images/android-$API/$TAG/$ABI"
IMAGE_DEST="$SDK_ROOT/$IMAGE_REL"
IMAGE_SOURCE_REL=$(dirname "$PROP_ENTRY")
log "system image: API $API, tag $TAG, ABI $ABI, revision ${REVISION:-unknown}"

log 'extracting system image'
rm -rf -- "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
unzip -q "$SYSTEM_ZIP" -d "$STAGE_DIR"
IMAGE_SOURCE="$STAGE_DIR/$IMAGE_SOURCE_REL"
[[ -f "$IMAGE_SOURCE/source.properties" ]] || die 'extracted source.properties not found at expected path'
rm -rf -- "$IMAGE_DEST"
mkdir -p "$(dirname "$IMAGE_DEST")"
mv -- "$IMAGE_SOURCE" "$IMAGE_DEST"
rm -rf -- "$STAGE_DIR"

for required in source.properties system.img vendor.img userdata.img ramdisk.img; do
  [[ -f "$IMAGE_DEST/$required" ]] || die "system image is missing $required"
done
if [[ ! -f "$IMAGE_DEST/kernel-ranchu" && ! -f "$IMAGE_DEST/kernel-ranchu-64" ]]; then
  die 'system image is missing kernel-ranchu/kernel-ranchu-64'
fi

AVD_DIR="$AVD_HOME/$AVD_NAME.avd"
AVD_INI="$AVD_HOME/$AVD_NAME.ini"
rm -rf -- "$AVD_DIR"
mkdir -p "$AVD_DIR"
cat > "$AVD_DIR/config.ini" <<CFG
AvdId = $AVD_NAME
PlayStore.enabled = false
avd.ini.displayname = $AVD_NAME
avd.ini.encoding = UTF-8
abi.type = $ABI
disk.dataPartition.size = $DATA_SIZE
fastboot.forceColdBoot = yes
hw.audioInput = no
hw.cpu.arch = $ABI
hw.cpu.ncore = $CORES
hw.gpu.enabled = yes
hw.gpu.mode = swiftshader_indirect
hw.keyboard = yes
hw.lcd.density = 320
hw.lcd.height = 1280
hw.lcd.width = 720
hw.ramSize = $MEMORY
runtime.network.latency = none
runtime.network.speed = full
showDeviceFrame = no
tag.display = ${TAG_DISPLAY:-$TAG}
tag.id = $TAG
vm.heapSize = 256
image.sysdir.1 = $IMAGE_REL/
CFG
cat > "$AVD_INI" <<CFG
avd.ini.encoding=UTF-8
path=$AVD_DIR
path.rel=$(basename "$AVD_HOME")/$AVD_NAME.avd
target=android-$API
CFG

cat > "$ENV_FILE" <<ENV
# Generated by android-emulator scripts
export ANDROID_HOME=$(printf '%q' "$SDK_ROOT")
export ANDROID_SDK_ROOT=$(printf '%q' "$SDK_ROOT")
export ANDROID_AVD_HOME=$(printf '%q' "$AVD_HOME")
export PATH=$(printf '%q' "$SDK_ROOT/platform-tools:$SDK_ROOT/emulator"):\$PATH
ENV

if ((KEEP_ZIP == 0)); then
  rm -f -- "$SYSTEM_ZIP"
fi

cat <<EOF2

System image / AVD setup complete.
  API:       $API
  tag:       $TAG
  ABI:       $ABI
  image:     $IMAGE_DEST
  AVD:       $AVD_NAME
  AVD home:  $AVD_HOME
  env:       $ENV_FILE

Next:
  source $(printf '%q' "$ENV_FILE")
  ./android-emulator/boot.sh --avd-name $(printf '%q' "$AVD_NAME")
EOF2
