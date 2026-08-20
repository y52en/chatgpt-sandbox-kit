# Ghidra in the ChatGPT Linux sandbox

This directory makes a verified Ghidra installation usable in a network-restricted ChatGPT Linux sandbox. It supports headless analysis, decompilation export, and PyGhidra without requiring package-manager or PyPI access from the sandbox itself.

Japanese guide: [README.ja.md](README.ja.md)

## Quick start

```bash
./ghidra/fetch.sh
./ghidra/setup.sh
./ghidra/verify.sh --full
./ghidra/decompile.sh ./target_binary
```

If the sandbox cannot reach the distribution branch itself, bring `manifest.json` plus every `part-*` file into one directory and run:

```bash
./ghidra/assemble.sh \
  --manifest /path/to/manifest.json \
  --parts-dir /path/to/parts \
  --output /tmp/ghidra.zip

./ghidra/setup.sh --archive /tmp/ghidra.zip
```

## Why a split distribution exists

A current Ghidra release is well above GitHub's normal 100 MiB single-object limit. The official ZIP therefore is **not** committed to `main`.

`.github/workflows/update-ghidra-dist.yml` runs every day and publishes a verified copy to the orphan `ghidra-dist` branch as 64 MiB chunks. Only the current release is kept on that branch, avoiding an ever-growing binary history.

The updater:

1. asks GitHub's release API for the latest stable `NationalSecurityAgency/ghidra` release;
2. identifies the official `ghidra_*_PUBLIC_*.zip` asset;
3. records the release asset SHA-256 (GitHub's asset `digest`, or the release-note SHA when necessary);
4. downloads the asset through GitHub's authenticated release-asset API on a GitHub-hosted runner;
5. verifies its size and SHA-256;
6. reads `Ghidra/application.properties` from inside the ZIP;
7. installs the JDK version required by that release;
8. installs the untouched ZIP into a temporary tool root and runs `verify.sh --full`, which exercises `analyzeHeadless` and the native decompiler;
9. splits the original bytes into 64 MiB chunks;
10. hashes every chunk, reassembles all of them, checks the full SHA-256 again, and runs `cmp` against the official download;
11. only then force-pushes a fresh orphan `ghidra-dist` branch.

This means the branch is a transport mechanism, not a trust anchor. `fetch.sh` still validates the complete upstream digest after reassembly.

## Files

| File | Purpose |
| --- | --- |
| `fetch.sh` | Prefer the verified `ghidra-dist` chunks, with official-release fallback. |
| `assemble.sh` | Verify/reassemble locally supplied or remotely downloaded chunks. |
| `setup.sh` | Verify and install Ghidra; create an offline PyGhidra venv when possible. |
| `verify.sh` | Quick checks or a full real-decompiler smoke test. |
| `analyze.sh` | Import and analyze a binary with a disposable headless project. |
| `decompile.sh` | Analyze a binary and export every decompilable function as C-like text. |
| `pyghidra.sh` | Run Python inside the offline PyGhidra environment. |
| `version.env` | Pinned official release fallback and digest. |
| `ci/` | Release resolution and distribution packaging logic for Actions. |
| `tests/` | Offline tests, including tamper detection and a synthetic future release. |

## Installation paths

By default the toolkit keeps generated files under:

```text
.tools/ghidra/
├── downloads/
├── installs/
│   └── <version>/
├── current -> installs/<version>/
└── pyghidra-venv/
```

Override the root with `GHIDRA_TOOLS_ROOT`.

## Download behavior

### Default: split distribution

```bash
./ghidra/fetch.sh
```

The script asks for:

```text
https://raw.githubusercontent.com/y52en/chatgpt-sandbox-kit/ghidra-dist/current/manifest.json
```

then downloads and validates each listed `part-*`, concatenates them in manifest order, and validates the complete upstream SHA-256.

Override the location with:

```bash
GHIDRA_DIST_BASE_URL='https://example/path/current' ./ghidra/fetch.sh
```

### Direct official download

```bash
./ghidra/fetch.sh --official
```

or provide a trusted transport/mirror while retaining the pinned digest:

```bash
GHIDRA_DOWNLOAD_URL='https://mirror.example/ghidra.zip' ./ghidra/fetch.sh --official
```

Changing the URL does not change the accepted SHA-256.

### Fully offline / manually transferred chunks

If another ChatGPT-facing mechanism can download smaller raw GitHub files, transfer `manifest.json` and all `part-*` files and run `assemble.sh` as shown above. No network access is needed at assembly time.

## Setup

```bash
./ghidra/setup.sh
```

or:

```bash
./ghidra/setup.sh --archive /path/to/ghidra.zip
```

A split distribution has a sibling `ghidra.zip.manifest.json`. `setup.sh` reads that sidecar so a newly released Ghidra version can be installed before `main/version.env` is updated. In particular, its SHA-256, Ghidra version, and minimum Java version come from the verified manifest rather than stale hard-coded values.

For a directly supplied archive without a sidecar, the pinned fallback in `version.env` is used.

`setup.sh` refuses an archive when the digest does not match. It also requires a sufficiently new JDK and rejects an unexpected ZIP layout.

### PyGhidra

Current Ghidra distributions include the PyGhidra wheels and dependencies needed for an offline installation. `setup.sh` creates:

```text
.tools/ghidra/pyghidra-venv
```

and uses:

```bash
python3 -m pip install --no-index -f \
  <GhidraInstallDir>/Ghidra/Features/PyGhidra/pypkg/dist pyghidra
```

No PyPI access is required.

Run scripts through that environment with:

```bash
./ghidra/pyghidra.sh script.py
```

or open an interactive CPython session:

```bash
./ghidra/pyghidra.sh
```

## Verification

Quick structural check:

```bash
./ghidra/verify.sh
```

Full check:

```bash
./ghidra/verify.sh --full
```

The full check builds a tiny native ELF containing `sandbox_add`, imports it with Ghidra, runs auto-analysis and the native decompiler, and verifies that the exported C-like output contains that function.

## Analyze a binary

```bash
./ghidra/analyze.sh ./program
```

Extra options after the binary are forwarded to `analyzeHeadless`:

```bash
./ghidra/analyze.sh ./program -analysisTimeoutPerFile 300
```

A disposable project is created in `/tmp` and removed afterwards.

## Export decompiled functions

```bash
./ghidra/decompile.sh ./program
```

Output defaults to:

```text
./program.decompiled.c
```

Specify another path with:

```bash
./ghidra/decompile.sh ./program /tmp/program.c
```

`ExportDecompilation.java` enumerates functions known to Ghidra and asks the native decompiler for C-like output for each function. A failure on one function is recorded in the output instead of discarding successful functions.

## Automation details

### Daily schedule

The distribution updater runs at `21:17 UTC`, i.e. **06:17 JST** the following day. It is also manually runnable through `workflow_dispatch`.

It compares both the release tag and upstream SHA-256 with the existing `ghidra-dist/current/manifest.json`. If neither changed, it exits without downloading the ~500+ MiB release.

### Distribution manifest

Example shape:

```json
{
  "schema": 1,
  "upstream": "NationalSecurityAgency/ghidra",
  "tag": "Ghidra_12.1.2_build",
  "version": "12.1.2",
  "filename": "ghidra_12.1.2_PUBLIC_20260605.zip",
  "size": 572803866,
  "sha256": "b62e81a0390618466c019c60d8c2f796ced2509c4c1aea4a37644a77272cf99d",
  "java_min": 21,
  "chunk_size": 67108864,
  "chunks": [
    {
      "file": "part-000",
      "size": 67108864,
      "sha256": "..."
    }
  ]
}
```

`assemble.sh` checks the declared byte count and SHA-256 of every part before concatenation, then checks the full-file SHA-256.

### Why an orphan branch?

A normal branch would retain every previous Ghidra ZIP in Git history even after files were replaced. For a 500+ MiB release this would become impractical quickly.

The workflow initializes a fresh repository, makes a single root commit containing only `current/`, and force-pushes it to `ghidra-dist`. Therefore every update replaces the previous binary history instead of extending it.

## Current pinned fallback

`version.env` currently pins Ghidra 12.1.2 as the direct-download fallback. This is intentionally independent of the daily distribution; it provides reproducibility when GitHub Actions or `ghidra-dist` is unavailable.

## Limitations

- The ChatGPT shell may still have no outbound network access. In that case transfer the chunks or complete official ZIP into the sandbox first.
- Normal GUI use depends on a working X server/display path. Headless analysis does not.
- The container may not expose a hardware GPU. Most reverse-engineering operations do not need one.
- Ghidra's debugger integrations can require additional native tools/network access that this kit does not install.
- The updater's force-push needs repository `contents: write`; branch protection must allow GitHub Actions to update `ghidra-dist`.

## Licenses

The scripts and documentation in this directory are MIT-licensed as part of this repository. Ghidra itself is downloaded from its upstream release and remains under its own license and notices. The split distribution consists of the untouched official ZIP bytes, divided only for transport.
