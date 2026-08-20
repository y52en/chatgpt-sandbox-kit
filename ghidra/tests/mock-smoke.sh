#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fake="$TMP/ghidra_99.1_PUBLIC_20990101"
mkdir -p "$fake/support" "$fake/Ghidra/Features/Decompiler/os/linux_x86_64"
cat > "$fake/support/analyzeHeadless" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
output=''
while (($#)); do
  if [[ "$1" == '-postScript' ]]; then output="$3"; shift 3; else shift; fi
done
if [[ -n "$output" ]]; then
  cat > "$output" <<'EOF'
int sandbox_add(int a, int b) { return a + b; }
EOF
fi
SH
chmod +x "$fake/support/analyzeHeadless"
touch "$fake/Ghidra/Features/Decompiler/os/linux_x86_64/decompile"
chmod +x "$fake/Ghidra/Features/Decompiler/os/linux_x86_64/decompile"
(
  cd "$TMP"
  zip -qr "$TMP/fake.zip" "$(basename "$fake")"
)
sha="$(sha256sum "$TMP/fake.zip" | awk '{print $1}')"
cat > "$TMP/fake.zip.manifest.json" <<EOF
{"version":"99.1","filename":"fake.zip","sha256":"$sha","java_min":1}
EOF

export GHIDRA_TOOLS_ROOT="$TMP/tools"
"$ROOT/ghidra/setup.sh" --archive "$TMP/fake.zip" --skip-pyghidra >/dev/null
"$ROOT/ghidra/verify.sh" >/dev/null
printf '\x7fELFmock' > "$TMP/sample"
"$ROOT/ghidra/decompile.sh" "$TMP/sample" "$TMP/out.c" >/dev/null
grep -q sandbox_add "$TMP/out.c"
[[ -L "$GHIDRA_TOOLS_ROOT/current" ]]
[[ "$(basename "$(readlink -f "$GHIDRA_TOOLS_ROOT/current")")" == '99.1' ]]
echo 'mock smoke test passed'
