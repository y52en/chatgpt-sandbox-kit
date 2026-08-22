# chatgpt-sandbox-kit

`chatgpt-sandbox-kit` is an offline-first toolbox for development, debugging, reverse engineering, browser automation, Android testing, and Unity work inside ChatGPT's Linux sandbox.

The main practical constraint is usually transferring large third-party binaries into the sandbox, not running them. This repository therefore keeps those binaries out of Git and treats Google Drive (or conversation attachments) as the transport layer. After the files are materialized under `/mnt/data`, the kit discovers and uses them locally without downloading replacements.

> **Using this repository with ChatGPT or another coding agent?** Have the agent read [`AGENTS.md`](AGENTS.md) first. `AGENTS.md` intentionally contains only tool locations. All setup instructions are kept separately under [`docs/setup/`](docs/setup/).

## Quick start

```bash
./kit.sh inventory --strict
./kit.sh doctor
./kit.sh list
./kit.sh install ghidra
```

`kit.sh` searches the materialized asset roots recursively, rejects ambiguous duplicates, validates known split-archive layouts, and delegates to the specialized tool installers. It stores no Google Drive credentials or file IDs.

To narrow discovery to a specific materialized directory:

```bash
./kit.sh --asset-root /mnt/data/sandbox-assets inventory --strict
```

Detailed setup instructions are in [`docs/setup/README.md`](docs/setup/README.md). The current Google Drive snapshot is documented in [`docs/google-drive-layout.md`](docs/google-drive-layout.md), and [`docs/tool-matrix.md`](docs/tool-matrix.md) summarizes what is available and how it is verified.

## Included tool families

The current Drive-backed manifest covers:

- Ghidra 12.1.3 + PyGhidra
- Unicorn 2.1.4, Capstone 5.0.9, and Keystone Engine 0.9.2
- apktool 3.0.3 and JADX 1.5.5
- Android command-line tools, Platform Tools, Android Emulator, and an API 30 Google APIs x86_64 image
- Chrome for Testing + ChromeDriver
- Unity CLI + Unity Editor 2021.3.10f1
- Temurin JDK 21, Gradle 9.7.1, and Maven 3.9.16
- Linux x64 .NET SDK
- Python 3.13 Linux x86_64 offline wheelhouse
- Playwright Linux browser bundle
- Debian 13 amd64 development/debug/QEMU `.deb` bundle

## How the kit is organized

The repository keeps three concerns separate:

- `kit.sh`, `lib/`, `scripts/`, and `manifest/` handle discovery, inventory, and orchestration.
- each tool directory contains the executable installer/runtime helpers.
- `docs/setup/` contains setup instructions for humans; tool-directory README files only point there.

Large Drive objects may be supplied either as complete archives or as `.part000`/`.part001`... sequences. The current manifest also records the expected start number and part count for known split artifacts, so a missing final part is detected before reconstruction. Connector-added `.bin` suffixes are accepted.

Java, .NET, Debian package bundles, Python wheelhouses, Playwright browsers, and Android analysis tools are installed rootlessly into writable workspaces under `/mnt/data`. Existing Ghidra, Android Emulator, Chrome, Unity, and other specialist scripts remain directly usable.

## Commands

```text
./kit.sh inventory [--strict]   show materialized asset status
./kit.sh doctor                 check host prerequisites and disk information
./kit.sh list                   list installable components
./kit.sh install COMPONENT      discover and install one component
./kit.sh install all            install all components (large)
./kit.sh env                    list generated env.sh files
./kit.sh self-test              run local discovery and shell-syntax tests
```

## Validation policy

There is intentionally no download-based CI workflow. Lightweight validation is local:

```bash
./kit.sh self-test
bash -n kit.sh lib/assets.sh scripts/*.sh */setup.sh
```

Full smoke tests require the corresponding third-party artifacts to be present in the sandbox.

## License

Original scripts and documentation in this repository are MIT-licensed. Ghidra, Android SDK/Emulator components, Chrome, Unity, Temurin, Gradle, Maven, .NET, Playwright, apktool, JADX, Unicorn, Capstone, Keystone, Debian packages, and all other third-party software remain under their own licenses and terms.
