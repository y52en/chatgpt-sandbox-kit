# chatgpt-sandbox-kit

Small, offline-first helpers for tools that need to run inside ChatGPT's Linux sandbox.

The sandbox can run normal Linux, Java, and Python tooling, but transferring files into it is often more restrictive than running the tools themselves. This repository keeps sandbox setup offline-first and can vendor selected third-party wheels as small Git-tracked parts.

## Ghidra / PyGhidra

[`ghidra/`](ghidra/) prepares a local Ghidra ZIP (or split ZIP parts) without network access:

1. concatenate split parts when necessary;
2. optionally verify the complete ZIP with SHA-256;
3. test and extract the ZIP;
4. check Ghidra's Java/Python requirements from `application.properties`;
5. create a Python virtual environment;
6. install PyGhidra and its dependencies exclusively from the wheels bundled with Ghidra;
7. start Ghidra through PyGhidra to verify the installation.

This is intentionally designed for the workflow where a large Ghidra ZIP is uploaded to Google Drive in chunks small enough for the ChatGPT Google Drive connector, fetched into `/mnt/data`, and reconstructed locally.

## Unicorn Engine

[`unicorn/`](unicorn/) installs a locally transferred Unicorn Python wheel with no package-index access:

1. optionally verify the wheel with SHA-256;
2. create an isolated Python virtual environment;
3. install with `pip --no-index --no-deps`;
4. run a real x86 emulation smoke test and verify the resulting register value.

For the current ChatGPT Linux sandbox (`x86_64`, Python 3.13), the tested artifact is:

```text
unicorn-2.1.4-cp37-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl
```

The `abi3` wheel works with CPython 3.7+ and the `manylinux_2_17_x86_64` build is compatible with the sandbox's x86-64 glibc environment.

## Capstone / Keystone

[`third_party/wheels/`](third_party/wheels/) vendors Linux x86_64 wheels for Capstone and Keystone Engine as parts of at most **1,000,000 bytes each**, keeping every binary part strictly below 1 MiB.

`reassemble.sh` reconstructs the original wheels and verifies their SHA-256 values before offline installation. A weekly GitHub Actions workflow checks PyPI for newer stable CPython 3.13 / Linux x86_64-compatible wheels, verifies PyPI hashes, refreshes the split parts and license notices, smoke-tests both libraries, and commits only when an update is available.

The sandbox itself does not need external package-index access to use the vendored wheels.

## License

Original scripts and documentation in this repository are MIT-licensed. Ghidra, Unicorn Engine, Capstone, Keystone Engine, and other third-party software remain under their own licenses.
