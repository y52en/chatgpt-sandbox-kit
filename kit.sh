#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/assets.sh
source "$ROOT/lib/assets.sh"

usage(){ cat <<'USAGE'
Usage: ./kit.sh [--asset-root DIR ...] <command> [args]

Commands:
  inventory [--strict]       Show the Google Drive / /mnt/data asset matrix
  doctor                     Check host-side prerequisites
  list                       List installable components
  install COMPONENT          Auto-discover assets and install one component
  install all                Install all components in dependency-aware order
  env                        Print generated env.sh files
  self-test                  Test asset discovery and shell syntax

Asset roots default to /mnt/data and the current directory. Use repeated
--asset-root or SANDBOX_KIT_ASSET_ROOTS=/a:/b to narrow discovery.
USAGE
}
roots=()
while (($#)); do
  case "$1" in
    --asset-root) (($# >= 2)) || sandbox_kit_die '--asset-root requires a directory'; roots+=("$2"); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) break ;;
  esac
done
if ((${#roots[@]})); then SANDBOX_KIT_ASSET_ROOTS=$(IFS=:; echo "${roots[*]}"); export SANDBOX_KIT_ASSET_ROOTS; fi
command_name=${1:-}; [[ -n "$command_name" ]] || { usage; exit 2; }; shift || true

components=(java dotnet python linux-tools playwright android-analysis android-tools unicorn capstone-keystone ghidra unity android-emulator)
list_components(){ printf '%s\n' "${components[@]}"; }
source_component_env(){ local component=$1 file; for file in "/mnt/data/$component-kit/env.sh" "$PWD/.tools/$component/env.sh" "$ROOT/.tools/$component/env.sh"; do if [[ -f "$file" ]]; then sandbox_kit_source_env_if_present "$file"; return 0; fi; done; return 0; }

install_component(){
  local component=$1; shift || true
  local a b c hash_file expected_hash
  local -a group=() group2=() optional_args=()
  case "$component" in
    java)
      a=$(sandbox_kit_find_one 'temurin-jdk21-linux-x64.tar.gz'); b=$(sandbox_kit_find_one 'gradle-9.7.1-bin.zip' optional || true); c=$(sandbox_kit_find_one 'apache-maven-3.9.16-bin.tar.gz' optional || true)
      optional_args=(); [[ -z "$b" ]] || optional_args+=("$b"); [[ -z "$c" ]] || optional_args+=("$c")
      "$ROOT/java/setup.sh" "$a" "${optional_args[@]}" "$@"; source_component_env java;;
    dotnet)
      a=$(sandbox_kit_find_one 'dotnet-sdk-linux-x64.tar.gz'); "$ROOT/dotnet/setup.sh" "$a" "$@"; source_component_env dotnet;;
    python)
      sandbox_kit_collect_archive group 'python313-linux-x86_64-wheelhouse.tar.gz' 'python313-linux-x86_64-wheelhouse.tar.gz.part*' required 0 2; "$ROOT/python/setup.sh" "${group[@]}" "$@"; source_component_env python;;
    linux-tools)
      sandbox_kit_collect_archive group 'debian13-amd64-dev-debug-qemu-debs.tar.gz' 'debian13-amd64-dev-debug-qemu-debs.tar.gz.part*' required 0 2; "$ROOT/linux-tools/setup.sh" "${group[@]}" "$@"; source_component_env linux-tools;;
    playwright)
      sandbox_kit_collect_archive group 'playwright-linux-browsers-bundle.tar.gz' 'playwright-linux-browsers-bundle.tar.gz.part*' required 0 3; "$ROOT/playwright/setup.sh" "${group[@]}" "$@"; source_component_env playwright;;
    android-analysis)
      a=$(sandbox_kit_find_one 'apktool_3.0.3.jar'); b=$(sandbox_kit_find_one 'jadx-1.5.5.zip'); "$ROOT/android-analysis/setup.sh" "$a" "$b" "$@"; source_component_env android-analysis;;
    android-tools)
      a=$(sandbox_kit_find_one 'commandlinetools-linux-15859902_latest.zip'); b=$(sandbox_kit_find_one 'platform-tools-latest-linux.zip' optional || true); hash_file=$(sandbox_kit_find_one 'commandlinetools-linux-15859902_latest.zip.sha256' optional || true)
      optional_args=()
      if [[ -n "$hash_file" ]]; then
        expected_hash=$(awk 'NF {print tolower($1); exit}' "$hash_file")
        [[ "$expected_hash" =~ ^[0-9a-f]{64}$ ]] || sandbox_kit_die "invalid SHA-256 sidecar: $hash_file"
        optional_args+=(--cmdline-sha256 "$expected_hash")
      fi
      [[ -z "$b" ]] || optional_args+=("$b")
      "$ROOT/android-tools/setup.sh" "${optional_args[@]}" "$a" "$@";;
    unicorn)
      a=$(sandbox_kit_find_one 'unicorn-2.1.4-*.whl'); "$ROOT/unicorn/setup.sh" "$a" "$@";;
    capstone-keystone)
      a=$(sandbox_kit_find_one 'capstone-5.0.9-*.whl'); b=$(sandbox_kit_find_one 'keystone_engine-0.9.2-*.whl'); "$ROOT/capstone-keystone/setup.sh" "$a" "$b" "$@";;
    ghidra)
      sandbox_kit_collect_archive group 'ghidra_12.1.3_PUBLIC_20260817.zip' 'ghidra_12.1.3_PUBLIC_20260817.zip.part*' required 1 3; "$ROOT/ghidra/setup.sh" "${group[@]}" "$@";;
    unity)
      a=$(sandbox_kit_find_one 'unity-cli-linux-amd64.deb'); sandbox_kit_collect_archive group 'Unity-2021.3.10f1-linux.tar.xz' 'Unity-2021.3.10f1-linux.tar.xz.part*' optional 1 10 || true; "$ROOT/unity/setup.sh" "$a" "${group[@]}" "$@";;
    android-emulator)
      a=$(sandbox_kit_find_one 'platform-tools-latest-linux.zip'); sandbox_kit_collect_archive group 'emulator-linux_x64-16079175.zip' 'emulator-linux_x64-16079175.zip.part*' required 1 2; "$ROOT/android-emulator/setup.sh" "$a" "${group[@]}" "$@"; sandbox_kit_collect_archive group2 'x86_64-30_r16.zip' 'x86_64-30_r16.zip.part*' required 1 6; "$ROOT/android-emulator/install-system-image.sh" "${group2[@]}";;
    *) sandbox_kit_die "unknown component: $component";;
  esac
}

case "$command_name" in
  inventory) exec "$ROOT/scripts/inventory.sh" "$@";;
  doctor) exec "$ROOT/scripts/doctor.sh" "$@";;
  list) list_components;;
  self-test) exec "$ROOT/tests/self-test.sh";;
  env) find /mnt/data "$ROOT/.tools" -maxdepth 2 -type f -name env.sh -print 2>/dev/null | sort -u;;
  install)
    target=${1:-}; [[ -n "$target" ]] || sandbox_kit_die 'install requires a component or all'; shift || true
    if [[ "$target" == all ]]; then
      for component in "${components[@]}"; do sandbox_kit_log "installing $component"; install_component "$component"; done
    else install_component "$target" "$@"; fi;;
  *) usage >&2; exit 2;;
esac
