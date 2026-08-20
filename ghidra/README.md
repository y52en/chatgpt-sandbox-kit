# Ghidra / PyGhidra in the ChatGPT Linux sandbox

Offline-first setup for a Ghidra archive that has already been transferred into the sandbox.

The repository intentionally does not download, mirror, or publish Ghidra. Large-file transfer is the fragile part of this environment, so the workflow starts only after a ZIP or split ZIP parts are present locally.

## Typical Google Drive workflow

The ChatGPT Google Drive connector may reject a single file above roughly 256 MiB with `413 File too large`. Split the original Ghidra ZIP into parts around 250 MB or smaller, upload those parts to Drive, then have ChatGPT fetch each part into `/mnt/data`.

A fetched `application/octet-stream` part can gain a `.bin` suffix in the sandbox. That is fine; `setup.sh` sorts the supplied part paths using version ordering and concatenates their bytes unchanged.

Example:

```bash
./ghidra/setup.sh \
  --sha256 93a5d11a9ad510622acaaf908c556a7b9b764d338e78a7567f3689bf5081fd54 \
  /mnt/data/ghidra_12.1.3_PUBLIC_20260817.zip.part001 \
  /mnt/data/ghidra_12.1.3_PUBLIC_20260817.zip.part002.bin \
  /mnt/data/ghidra_12.1.3_PUBLIC_20260817.zip.part003.bin
```

For a normal unsplit ZIP:

```bash
./ghidra/setup.sh /mnt/data/ghidra_12.1.3_PUBLIC_20260817.zip
```

## What setup does

`setup.sh` performs only local operations:

- reconstructs split parts when supplied;
- prints and optionally verifies the complete SHA-256;
- checks the ZIP with `unzip -t`;
- extracts Ghidra;
- reads Ghidra's Java and Python requirements from `Ghidra/application.properties`;
- creates an isolated Python venv;
- installs PyGhidra with `pip --no-index` exclusively from wheels bundled under `Ghidra/Features/PyGhidra/pypkg/dist`;
- starts the JVM and imports a Ghidra Java class as a smoke test.

The default sandbox workspace is `/mnt/data/ghidra-kit`. Override it with `GHIDRA_WORK_DIR` or `--work-dir`.

## Run PyGhidra

```bash
./ghidra/pyghidra.sh --help
./ghidra/pyghidra.sh /mnt/data/sample.bin
```

For a normal Python script using PyGhidra:

```python
import pyghidra
pyghidra.start()

from ghidra.framework import Application
print(Application.getApplicationVersion())
```

```bash
./ghidra/python.sh script.py
```

The wrappers invoke Python with safe-path mode (`-P`) so the repository's own `ghidra/` directory cannot shadow PyGhidra's Java package importer.

Verify the prepared environment:

```bash
./ghidra/verify.sh
```

See [README.ja.md](README.ja.md) for the detailed Japanese guide.

## Tested snapshot

The workflow has been exercised with Ghidra 12.1.3 PUBLIC (20260817), a 569,445,154-byte ZIP with SHA-256 `93a5d11a9ad510622acaaf908c556a7b9b764d338e78a7567f3689bf5081fd54`, OpenJDK 21, Python 3.13, PyGhidra 3.1.0, and JPype 1.5.2.

## No CI / no downloader

There are deliberately no GitHub Actions workflows, release-resolver scripts, mirror branches, or fallback network downloaders in this codebase.
