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

host_browser=
for cmd in chromium chromium-browser google-chrome google-chrome-stable; do
  if command -v "$cmd" >/dev/null; then host_browser=$cmd; break; fi
done
if [[ -n "$host_browser" ]]; then
  browser_path=$(command -v "$host_browser")
  browser_version=$("$host_browser" --version 2>/dev/null || true)
  printf '  [ok]   host browser -> %s%s\n' "$browser_path" "${browser_version:+ ($browser_version)}"
else
  printf '  [opt]  no Chromium-family host browser detected\n'
fi

if [[ -d /mnt/data ]]; then df -h /mnt/data | sed -n '1,2p'; fi
((missing == 0)) || exit 1
