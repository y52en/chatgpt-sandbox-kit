# chatgpt-sandbox-kit

Offline-first development, debugging, reverse-engineering, browser, Android, and Unity tooling for ChatGPT's Linux sandbox.

The hard part of the sandbox is usually **getting large third-party binaries into it**, not executing them. This repository therefore keeps binaries out of Git and treats Google Drive (or conversation attachments) as the transport layer. Once artifacts are under `/mnt/data`, the repository discovers, reconstructs, verifies, and installs them without network access.

## One entrypoint

```bash
./kit.sh inventory
./kit.sh doctor
./kit.sh install ghidra
./kit.sh install android-emulator
./kit.sh install java
```

`kit.sh` recursively discovers the connected-Drive asset set by filename, validates split-part numbering, and delegates to the existing specialized installers. No Google Drive IDs or credentials are stored in the repository.

To avoid accidental matches when `/mnt/data` contains unrelated files:

```bash
./kit.sh --asset-root /mnt/data/sandbox-assets inventory
```

See [`docs/google-drive-layout.md`](docs/google-drive-layout.md) for the Drive snapshot used by the current manifest and [`docs/tool-matrix.md`](docs/tool-matrix.md) for setup/verification coverage.

## Current offline tool set

The Drive-backed manifest currently covers:

- Ghidra 12.1.3 + PyGhidra
- Unicorn 2.1.4, Capstone 5.0.9, Keystone Engine 0.9.2
- apktool 3.0.3 and JADX 1.5.5
- Android command-line tools, Platform Tools, Android Emulator, API 30 Google APIs x86_64 system image
- Chrome for Testing + ChromeDriver
- Unity CLI + Unity Editor 2021.3.10f1
- Temurin JDK 21, Gradle 9.7.1, Maven 3.9.16
- Linux x64 .NET SDK
- Python 3.13 Linux x86_64 wheelhouse
- Playwright Linux browser bundle
- Debian 13 amd64 development/debug/QEMU `.deb` bundle

Run `./kit.sh inventory --strict` after materializing the full Drive set to catch missing required assets.

## Design

### Offline by default

Installers do not use package indexes or vendor download sites. Existing Ghidra, Unicorn, Capstone/Keystone, Chrome, Android, and Unity scripts retain their direct CLI, so automation written against earlier versions continues to work.

### Split archives are first-class

Large Drive objects may be transferred as `.part000`/`.part001`... or `.part001`... sequences. The shared discovery layer checks contiguity before passing parts to installers. Connector-added `.bin` suffixes are accepted.

### Rootless toolchains

Java, .NET, Debian `.deb` tooling, Python wheelhouses, Playwright browsers, and Android analysis tools are extracted into writable work directories and expose generated `env.sh` files. System package installation is not required.

### Fail on ambiguity

If multiple files satisfy an artifact pattern, `kit.sh` stops instead of silently picking one. Set `SANDBOX_KIT_ASSET_ROOTS` or `--asset-root` to select the intended materialized set.

## Commands

```text
./kit.sh inventory [--strict]   # Drive/materialized asset status
./kit.sh doctor                 # host prerequisites and disk info
./kit.sh list                   # installable components
./kit.sh install COMPONENT      # discover + install one component
./kit.sh install all            # install everything (large)
./kit.sh env                    # show generated env.sh files
./kit.sh self-test              # local discovery/syntax tests
```

Each historical component directory remains usable directly (`ghidra/setup.sh`, `android-emulator/setup.sh`, and so on).

## Local validation

There is intentionally no download-based CI workflow. Run:

```bash
./kit.sh self-test
bash -n kit.sh lib/assets.sh scripts/*.sh */setup.sh
```

Full smoke tests require the corresponding transferred third-party assets.

## License

Original scripts and documentation in this repository are MIT-licensed. Ghidra, Android SDK/Emulator components, Chrome, Unity, Temurin, Gradle, Maven, .NET, Playwright, apktool, JADX, Unicorn, Capstone, Keystone, Debian packages, and all other third-party software remain under their own licenses and terms.
