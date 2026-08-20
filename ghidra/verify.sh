#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  cat <<'EOF'
Usage: verify.sh [--full]

Checks the current Ghidra installation. --full additionally builds a tiny ELF,
runs real headless analysis, and confirms the native decompiler can export a
known function.
EOF
}

full=false
while (($#)); do
  case "$1" in
    --full) full=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -x "$GHIDRA_HOME/support/analyzeHeadless" ]] || die "Ghidra is not installed at $GHIDRA_HOME"
require_command java
require_command python3

java_major="$(java_major_version)"
log "Java major: $java_major"
log "Ghidra home: $GHIDRA_HOME"

find -L "$GHIDRA_HOME" -type f \( -name decompile -o -name decompile.exe \) -print -quit | grep -q . || \
  die 'native Ghidra decompiler executable was not found'

if [[ -x "$GHIDRA_PYGHIDRA_VENV/bin/python" ]]; then
  GHIDRA_INSTALL_DIR="$GHIDRA_HOME" "$GHIDRA_PYGHIDRA_VENV/bin/python" - <<'PY'
import pyghidra
print(f"PyGhidra {pyghidra.__version__}")
PY
else
  warn 'PyGhidra venv is not installed (this is expected only if setup used --skip-pyghidra).'
fi

if [[ "$full" == false ]]; then
  log 'quick verification passed'
  exit 0
fi

require_command cc
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cat > "$work/smoke.c" <<'C'
#include <stdio.h>
__attribute__((noinline)) int sandbox_add(int a, int b) { return a + b; }
int main(void) { printf("%d\n", sandbox_add(20, 22)); return 0; }
C
cc -g -O0 "$work/smoke.c" -o "$work/smoke"
"$GHIDRA_KIT_DIR/decompile.sh" "$work/smoke" "$work/smoke.c.out" >/dev/null
grep -q 'sandbox_add' "$work/smoke.c.out" || die 'full smoke test did not decompile sandbox_add'
log 'full verification passed'
