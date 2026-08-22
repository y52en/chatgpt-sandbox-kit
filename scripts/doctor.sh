#!/usr/bin/env bash
set -euo pipefail
required=(bash find sort stat sha256sum tar unzip)
optional=(java python3 dpkg-deb xz ldd)
missing=0
printf 'Host: %s %s\n' "$(uname -s)" "$(uname -m)"
printf 'Asset roots: %s\n' "${SANDBOX_KIT_ASSET_ROOTS:-/mnt/data:$PWD}"
for cmd in "${required[@]}"; do
  if command -v "$cmd" >/dev/null; then printf '  [ok]   %s -> %s\n' "$cmd" "$(command -v "$cmd")"; else printf '  [MISS] %s\n' "$cmd"; ((missing+=1)); fi
done
for cmd in "${optional[@]}"; do
  if command -v "$cmd" >/dev/null; then printf '  [ok]   %s -> %s\n' "$cmd" "$(command -v "$cmd")"; else printf '  [opt]  %s not present\n' "$cmd"; fi
done
if [[ -d /mnt/data ]]; then df -h /mnt/data | sed -n '1,2p'; fi
((missing == 0)) || exit 1
