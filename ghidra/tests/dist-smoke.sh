#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fake_root="$TMP/ghidra_99.1_PUBLIC_20990101"
mkdir -p "$fake_root/support" "$fake_root/Ghidra/Features/Decompiler/os/linux_x86_64" "$fake_root/Ghidra"
cat > "$fake_root/Ghidra/application.properties" <<'EOF'
application.version=99.1
application.java.min=1
EOF
cat > "$fake_root/support/analyzeHeadless" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
output=''
while (($#)); do
  if [[ "$1" == '-postScript' ]]; then output="$3"; shift 3; else shift; fi
done
[[ -z "$output" ]] || printf 'int sandbox_add(int a, int b) { return a + b; }\n' > "$output"
SH
chmod +x "$fake_root/support/analyzeHeadless"
touch "$fake_root/Ghidra/Features/Decompiler/os/linux_x86_64/decompile"
chmod +x "$fake_root/Ghidra/Features/Decompiler/os/linux_x86_64/decompile"
(
  cd "$TMP"
  zip -qr "$TMP/fake.zip" "$(basename "$fake_root")"
)
full_sha="$(sha256sum "$TMP/fake.zip" | awk '{print $1}')"

mkdir "$TMP/dist"
split -b 257 -d -a 3 "$TMP/fake.zip" "$TMP/dist/part-"
python3 - "$TMP/dist" "$full_sha" "$(stat -c %s "$TMP/fake.zip")" <<'PY'
import hashlib,json,pathlib,sys
root=pathlib.Path(sys.argv[1])
chunks=[]
for p in sorted(root.glob('part-*')):
    b=p.read_bytes(); chunks.append({'file':p.name,'size':len(b),'sha256':hashlib.sha256(b).hexdigest()})
m={'schema':1,'tag':'Ghidra_99.1_build','version':'99.1','filename':'ghidra_99.1_PUBLIC_20990101.zip','size':int(sys.argv[3]),'sha256':sys.argv[2],'java_min':1,'chunks':chunks}
(root/'manifest.json').write_text(json.dumps(m),encoding='utf-8')
PY

export GHIDRA_TOOLS_ROOT="$TMP/tools"
archive="$($ROOT/ghidra/assemble.sh --manifest "$TMP/dist/manifest.json" --parts-dir "$TMP/dist" --output "$TMP/rebuilt.zip")"
cmp "$archive" "$TMP/fake.zip"
cp "$TMP/dist/manifest.json" "$archive.manifest.json"
"$ROOT/ghidra/setup.sh" --archive "$archive" --skip-pyghidra >/dev/null
[[ "$(basename "$(readlink -f "$GHIDRA_TOOLS_ROOT/current")")" == '99.1' ]]

# Tampering must be rejected.
cp "$TMP/dist/part-000" "$TMP/dist/part-000.good"
printf X >> "$TMP/dist/part-000"
if "$ROOT/ghidra/assemble.sh" --manifest "$TMP/dist/manifest.json" --parts-dir "$TMP/dist" --output "$TMP/bad.zip" >/dev/null 2>&1; then
  echo 'tampered chunk was incorrectly accepted' >&2; exit 1
fi
mv "$TMP/dist/part-000.good" "$TMP/dist/part-000"

# A wrong whole-archive digest must also be rejected by setup.
python3 - "$archive.manifest.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d['sha256']='00'*32; open(p,'w').write(json.dumps(d))
PY
if "$ROOT/ghidra/setup.sh" --archive "$archive" --skip-pyghidra >/dev/null 2>&1; then
  echo 'wrong upstream digest was incorrectly accepted' >&2; exit 1
fi

echo 'dist smoke test passed'
