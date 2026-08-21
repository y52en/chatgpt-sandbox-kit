# Capstone + Keystone offline setup

This directory installs the Python bindings for Capstone and Keystone Engine from wheels that have already been transferred into the ChatGPT Linux sandbox. The recommended transport is **Google Drive**, not GitHub binary parts.

The setup script never downloads from PyPI or another external host. It installs only the two local wheel files with `pip --no-index --no-deps`.

## Recommended ChatGPT + Google Drive workflow

1. Download suitable Linux x86-64 wheels on your own machine.
2. Put the `.whl` files in Google Drive.
3. Have ChatGPT retrieve/materialize those Drive files into the Linux sandbox (normally under `/mnt/data`).
4. Run `capstone-keystone/setup.sh` with the two local paths.
5. The script verifies optional SHA-256 values, creates an isolated venv, installs offline, and runs a real Keystone -> Capstone smoke test.

Unlike GitHub repository-file retrieval, Google Drive can transfer these multi-megabyte wheels into the sandbox without encoding them into a tool response.

## Tested sandbox configuration

The following exact artifacts were tested successfully with Linux x86-64 and Python 3.13.5:

- Capstone 5.0.9
  - `capstone-5.0.9-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl`
  - SHA-256: `273fd8d747d2e35c88f91450be51a603ecfaafb00d96d9f315dcb8689c86193e`
- Keystone Engine 0.9.2
  - `keystone_engine-0.9.2-py2.py3-none-manylinux1_x86_64.whl`
  - SHA-256: `5a5316a34323620b1bba31dcfe9e4b4ca6f0c030e82fc7a151da7c8fbe81a379`

These are examples of known-good artifacts, not hard-coded requirements. Newer compatible wheels can be supplied in the same way.

## Setup

```bash
./capstone-keystone/setup.sh \
  --capstone-sha256 273fd8d747d2e35c88f91450be51a603ecfaafb00d96d9f315dcb8689c86193e \
  --keystone-sha256 5a5316a34323620b1bba31dcfe9e4b4ca6f0c030e82fc7a151da7c8fbe81a379 \
  /mnt/data/capstone-5.0.9-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl \
  /mnt/data/keystone_engine-0.9.2-py2.py3-none-manylinux1_x86_64.whl
```

The wheel arguments may be given in either order; `setup.sh` identifies them by filename.

By default the environment is created under `/mnt/data/capstone-keystone-kit/venv` when `/mnt/data` exists. Otherwise it uses `./.tools/capstone-keystone/venv`.

To choose another workspace or Python interpreter:

```bash
./capstone-keystone/setup.sh \
  --work-dir /mnt/data/my-capstone-keystone \
  --python python3 \
  /mnt/data/capstone-*.whl \
  /mnt/data/keystone_engine-*.whl
```

## Verification

`setup.sh` automatically runs `verify.py`. It uses Keystone to assemble:

```asm
mov eax, 0x12345678
inc eax
```

and verifies the exact machine code before asking Capstone to disassemble it back to the expected two x86 instructions.

Run it again with:

```bash
CAPSTONE_KEYSTONE_WORK_DIR=/mnt/data/capstone-keystone-kit \
  ./capstone-keystone/python.sh ./capstone-keystone/verify.py
```

## Offline behavior

Installation is deliberately limited to:

```text
pip install --no-index --no-deps <capstone-wheel> <keystone-wheel>
```

There is no package-index fallback and this repository does not vendor, split, or automatically refresh the third-party wheel binaries.

## Third-party licenses

The scripts and documentation in this repository are MIT-licensed. Capstone and Keystone Engine are third-party software and remain subject to their own license terms. Keep the upstream license notices associated with any wheels you redistribute outside your private Drive.
