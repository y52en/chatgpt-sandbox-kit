# Google Drive asset layout

This repository intentionally does **not** vendor large third-party binaries. The current offline asset source is the connected Google Drive. Files are materialized into the ChatGPT Linux sandbox (normally below `/mnt/data`) and discovered by filename, so the Drive directory hierarchy does not have to be recreated locally.

Snapshot inspected on **2026-08-23**:

| Drive folder | Assets |
|---|---|
| `re/` | Ghidra 12.1.3 split ZIP (`part001`-`part003`), Unicorn 2.1.4 wheel, Capstone 5.0.9 wheel, Keystone Engine 0.9.2 wheel |
| `Android/` | Android command-line tools build 15859902 + SHA-256 sidecar, apktool 3.0.3, JADX 1.5.5 |
| `AndroidEmulator/` | Platform Tools, Emulator build 16079175 split ZIP (`part001`-`part002`), API 30 Google APIs x86_64 image r16 split ZIP (`part001`-`part006`) |
| `UnityCLI/` | `unity-cli-linux-amd64.deb` |
| `UnityEditor/2021.3.10f1/` | Unity Editor archive split into `part001`-`part010`, plus `release-api.json` |
| `java/` | Temurin JDK 21, Gradle 9.7.1, Maven 3.9.16 |
| `dotnet/` | Linux x64 .NET SDK tarball + .NET 10 release metadata |
| `python/` | Python 3.13 Linux x86_64 wheelhouse split into `part000`-`part001` |
| `playwright/` | Linux browser bundle split into `part000`-`part002` |
| `linux-tools/` | Debian 13 amd64 development/debug/QEMU `.deb` bundle split into `part000`-`part001` |
| `Video/` | Remotion 4.0.515 offline project/npm cache, Chrome Headless Shell 149.0.7790.0, VOICEVOX Engine 0.25.2 split as `part-0001`-`part-0008` with `parts.json`, 7-Zip Linux helper, psd-tools 1.18.0 wheelhouse, and user-supplied layered character PSDs |

For ordinary browser automation, prefer a Chromium-family browser already supplied by the sandbox host; `./kit.sh doctor` reports one when available. The Drive-backed Playwright browser bundle remains available when a pinned browser payload is needed. Remotion is a deliberate exception: the tested host Chromium had a managed `URLBlocklist` that rejected Remotion's localhost bundle, so `Video/` contains a pinned Chrome Headless Shell used only for Remotion rendering.

The machine-readable version is [`manifest/artifacts.tsv`](../manifest/artifacts.tsv).

## Materialization workflow

1. Use the Google Drive connector to fetch only the artifacts needed for the task.
2. Materialize them into `/mnt/data`. Original folder names are optional, except that the VOICEVOX `parts.json` must remain beside its `part-0001`... files.
3. Run `./kit.sh inventory` to verify discovery and split-part completeness.
4. Run `./kit.sh install <component>`.

`kit.sh` searches recursively and accepts a connector-added `.bin` suffix on split parts and ordinary files. If the same logical artifact exists more than once, discovery fails rather than choosing one silently. Narrow the search with:

```bash
./kit.sh --asset-root /mnt/data/my-assets inventory
# or
SANDBOX_KIT_ASSET_ROOTS=/mnt/data/a:/mnt/data/b ./kit.sh install ghidra
```

## Split archive policy

Large files are split before upload to keep individual Drive objects manageable. The generic kit format supports both `part000` and `part001` numbering schemes and treats sequence gaps as errors before concatenation. The video component also supports the preparer's `parts.json + part-0001...` layout: it verifies each part SHA-256 and the final reconstructed VOICEVOX archive SHA-256 before extraction.

The repository contains no Google Drive file IDs, access tokens, or download URLs. Drive remains the transport layer; Git remains the reproducible setup/orchestration layer.
