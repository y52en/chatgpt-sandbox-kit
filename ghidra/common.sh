#!/usr/bin/env bash
set -euo pipefail

GHIDRA_KIT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GHIDRA_REPO_ROOT="$(cd -- "$GHIDRA_KIT_DIR/.." && pwd)"
# shellcheck source=version.env
source "$GHIDRA_KIT_DIR/version.env"

GHIDRA_TOOLS_ROOT="${GHIDRA_TOOLS_ROOT:-$GHIDRA_REPO_ROOT/.tools/ghidra}"
GHIDRA_INSTALLS_DIR="$GHIDRA_TOOLS_ROOT/installs"
GHIDRA_DOWNLOADS_DIR="$GHIDRA_TOOLS_ROOT/downloads"
GHIDRA_HOME="${GHIDRA_HOME:-$GHIDRA_TOOLS_ROOT/current}"
GHIDRA_PYGHIDRA_VENV="${GHIDRA_PYGHIDRA_VENV:-$GHIDRA_TOOLS_ROOT/pyghidra-venv}"

log() {
  printf '[ghidra-kit] %s\n' "$*" >&2
}

warn() {
  printf '[ghidra-kit] warning: %s\n' "$*" >&2
}

die() {
  printf '[ghidra-kit] error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

sha256_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    die 'sha256sum or shasum is required'
  fi
}

java_major_version() {
  java -version 2>&1 | awk -F'[".]' '/version/ { if ($2 == "1") print $3; else print $2; exit }'
}

python_version_tuple() {
  python3 - <<'PY'
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}")
PY
}

version_ge() {
  python3 - "$1" "$2" <<'PY'
import sys
from itertools import zip_longest

def v(s):
    return tuple(int(x) for x in s.split('.'))

a, b = map(v, sys.argv[1:])
print(int(tuple(zip_longest(a, b, fillvalue=0)) >= tuple(zip_longest(b, a, fillvalue=0))))
PY
}

manifest_value() {
  local manifest="$1" key="$2"
  python3 - "$manifest" "$key" <<'PY'
import json, sys
obj = json.load(open(sys.argv[1], encoding='utf-8'))
value = obj
for part in sys.argv[2].split('.'):
    value = value[part]
if isinstance(value, bool):
    print(str(value).lower())
elif isinstance(value, (dict, list)):
    print(json.dumps(value, separators=(',', ':')))
else:
    print(value)
PY
}

load_archive_metadata() {
  local archive="$1"
  local manifest="${archive}.manifest.json"
  if [[ -f "$manifest" ]]; then
    GHIDRA_ACTIVE_VERSION="$(manifest_value "$manifest" version)"
    GHIDRA_ACTIVE_SHA256="$(manifest_value "$manifest" sha256)"
    GHIDRA_ACTIVE_JAVA_MIN="$(manifest_value "$manifest" java_min)"
    GHIDRA_ACTIVE_FILENAME="$(manifest_value "$manifest" filename)"
  else
    GHIDRA_ACTIVE_VERSION="$GHIDRA_VERSION"
    GHIDRA_ACTIVE_SHA256="$GHIDRA_SHA256"
    GHIDRA_ACTIVE_JAVA_MIN="$GHIDRA_JAVA_MIN"
    GHIDRA_ACTIVE_FILENAME="$GHIDRA_FILENAME"
  fi
}
