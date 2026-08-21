#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  setup.sh [options] <unity-cli-linux-amd64.deb> [Unity.tar.xz | Unity.tar.xz.partNNN[.bin] ...]

Options:
  --work-dir DIR          Workspace. Default: /mnt/data/unity-kit when available,
                          otherwise ./.tools/unity
  --cli-sha256 HEX        Expected SHA-256 for the Unity CLI .deb
  --editor-sha256 HEX     Expected SHA-256 for the reconstructed Editor archive
  --editor-sha256-file F  sha256sum-format file for the complete Editor archive
  --verify-only           Reconstruct/hash/index-check Editor but do not extract it
  -h, --help              Show this help

No downloads are performed. Split parts may have an extra .bin suffix added by
connector materialization. Parts are sorted by their numeric part suffix before
concatenation.
USAGE
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '[unity-setup] %s\n' "$*"; }

if [[ -d /mnt/data ]]; then WORK_DIR=/mnt/data/unity-kit; else WORK_DIR="$PWD/.tools/unity"; fi
CLI_SHA256=
EDITOR_SHA256=
EDITOR_SHA256_FILE=
VERIFY_ONLY=0
CLI_DEB=
EDITOR_ARCHIVE=
PARTS=()

while (($#)); do
  case "$1" in
    --work-dir) (($# >= 2)) || die '--work-dir requires a value'; WORK_DIR=$2; shift 2 ;;
    --cli-sha256) (($# >= 2)) || die '--cli-sha256 requires a value'; CLI_SHA256=${2,,}; shift 2 ;;
    --editor-sha256) (($# >= 2)) || die '--editor-sha256 requires a value'; EDITOR_SHA256=${2,,}; shift 2 ;;
    --editor-sha256-file) (($# >= 2)) || die '--editor-sha256-file requires a value'; EDITOR_SHA256_FILE=$2; shift 2 ;;
    --verify-only) VERIFY_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *)
      base=$(basename "$1")
      case "$base" in
        unity-cli-linux-amd64.deb) [[ -z "$CLI_DEB" ]] || die 'multiple Unity CLI packages'; CLI_DEB=$1 ;;
        *.tar.xz) [[ -z "$EDITOR_ARCHIVE" ]] || die 'multiple complete Editor archives'; EDITOR_ARCHIVE=$1 ;;
        *.part[0-9][0-9][0-9]|*.part[0-9][0-9][0-9].bin) PARTS+=("$1") ;;
        *) die "unrecognized artifact: $1" ;;
      esac
      shift
      ;;
  esac
done

[[ -n "$CLI_DEB" ]] || die 'unity-cli-linux-amd64.deb is required'
[[ -f "$CLI_DEB" ]] || die "file not found: $CLI_DEB"
for cmd in dpkg-deb sha256sum stat xz tar sort sed; do command -v "$cmd" >/dev/null || die "$cmd is required"; done

verify_hash() {
  local label=$1 path=$2 expected=$3 actual
  actual=$(sha256sum "$path" | awk '{print $1}')
  log "$label: $(basename "$path") ($(stat -c '%s' "$path") bytes)"
  log "$label SHA-256: $actual"
  [[ -z "$expected" || "$actual" == "$expected" ]] || die "$label SHA-256 mismatch (expected $expected)"
}

verify_hash 'Unity CLI' "$CLI_DEB" "$CLI_SHA256"
mkdir -p "$WORK_DIR"
rm -rf "$WORK_DIR/cli-root"
dpkg-deb -x "$CLI_DEB" "$WORK_DIR/cli-root"
UNITY_CLI="$WORK_DIR/cli-root/usr/bin/unity"
[[ -x "$UNITY_CLI" ]] || die "Unity CLI binary not found: $UNITY_CLI"
CLI_VERSION=$("$UNITY_CLI" --version)
log "Unity CLI version: $CLI_VERSION"

if [[ ${#PARTS[@]} -gt 0 && -n "$EDITOR_ARCHIVE" ]]; then die 'supply either complete Editor archive or parts, not both'; fi
if [[ ${#PARTS[@]} -gt 0 ]]; then
  mkdir -p "$WORK_DIR/editor"
  EDITOR_ARCHIVE="$WORK_DIR/editor/Unity.tar.xz"
  : > "$EDITOR_ARCHIVE"
  mapfile -t SORTED_PARTS < <(printf '%s\n' "${PARTS[@]}" | sort -V)
  expected_part=1
  for part in "${SORTED_PARTS[@]}"; do
    [[ -f "$part" ]] || die "part not found: $part"
    base=$(basename "$part")
    n=$(sed -E 's/.*\.part([0-9]{3})(\.bin)?$/\1/' <<<"$base")
    [[ "$n" =~ ^[0-9]{3}$ ]] || die "cannot parse part number: $base"
    ((10#$n == expected_part)) || die "missing/out-of-order Editor part: expected part$(printf '%03d' "$expected_part"), got part$n"
    cat "$part" >> "$EDITOR_ARCHIVE"
    ((expected_part++))
  done
  log "reconstructed ${#SORTED_PARTS[@]} Editor parts"
fi

if [[ -n "$EDITOR_ARCHIVE" ]]; then
  [[ -f "$EDITOR_ARCHIVE" ]] || die "Editor archive not found: $EDITOR_ARCHIVE"
  if [[ -n "$EDITOR_SHA256_FILE" ]]; then
    [[ -f "$EDITOR_SHA256_FILE" ]] || die "SHA-256 file not found: $EDITOR_SHA256_FILE"
    EDITOR_SHA256=$(awk 'NF {print tolower($1); exit}' "$EDITOR_SHA256_FILE")
  fi
  verify_hash 'Unity Editor archive' "$EDITOR_ARCHIVE" "$EDITOR_SHA256"
  xz --list "$EDITOR_ARCHIVE" >/dev/null
  log 'Unity Editor xz index: OK'

  if ((VERIFY_ONLY == 0)); then
    rm -rf "$WORK_DIR/editor-root"
    mkdir -p "$WORK_DIR/editor-root"
    tar -xJf "$EDITOR_ARCHIVE" -C "$WORK_DIR/editor-root"
    UNITY_EDITOR="$WORK_DIR/editor-root/Editor/Unity"
    [[ -x "$UNITY_EDITOR" ]] || die "Unity Editor binary not found: $UNITY_EDITOR"
    EDITOR_VERSION=$("$UNITY_EDITOR" -version -batchmode -nographics -quit 2>&1 | tr '\n' ' ' || true)
    [[ "$EDITOR_VERSION" =~ [0-9]{4}\.[0-9]+\.[0-9]+ ]] || die "Unity Editor version smoke test failed: $EDITOR_VERSION"
    log "Unity Editor version output: $EDITOR_VERSION"
  fi
fi

cat > "$WORK_DIR/env.sh" <<ENV
export UNITY_CLI=$(printf '%q' "$UNITY_CLI")
${UNITY_EDITOR:+export UNITY_EDITOR=$(printf '%q' "$UNITY_EDITOR")}
ENV
log "environment file: $WORK_DIR/env.sh"
