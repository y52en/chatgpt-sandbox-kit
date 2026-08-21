# chatgpt-sandbox-kit

Small, offline-first helpers for tools that need to run inside ChatGPT's Linux sandbox.

The sandbox can run normal Linux, Java, and Python tooling, but transferring files into it is often more restrictive than running the tools themselves. This repository therefore keeps third-party binaries out of Git and assumes they are transferred into the sandbox first, with Google Drive as the recommended transport for larger artifacts and Python wheels.

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

[`capstone-keystone/`](capstone-keystone/) installs locally transferred Capstone and Keystone Engine wheels completely offline.

The recommended flow is:

1. put compatible Linux x86-64 `.whl` files in Google Drive;
2. transfer/materialize them into the ChatGPT sandbox, normally under `/mnt/data`;
3. optionally verify their SHA-256 values;
4. install both into an isolated venv with `pip --no-index --no-deps`;
5. verify them together by assembling x86 code with Keystone and disassembling the resulting bytes with Capstone.

The wheels are intentionally **not vendored or split into Git-tracked parts**. GitHub repository-file retrieval is useful for source code and small text files, while Google Drive is the more practical binary transport into the sandbox.

## Android Emulator / ADB

[`android-emulator/`](android-emulator/) prepares locally transferred Linux Android Platform Tools and Android Emulator archives completely offline.

The current sandbox has been verified with Platform Tools 37.0.1 and Android Emulator 37.2.5. The helper scripts can reconstruct a split Emulator ZIP, validate SHA-256 and ZIP integrity, extract an SDK-like layout, smoke-test the ADB server, and verify the Emulator binary and its software-emulation option.

The sandbox currently does **not** expose `/dev/kvm`, so hardware acceleration is unavailable. The tested Emulator supports `-accel off` / `-no-accel`; actual Android boot remains pending until a compatible system image is transferred into the sandbox.

See [`android-emulator/README.ja.md`](android-emulator/README.ja.md) for the Japanese guide and exact hashes of the tested archives.

## License

Original scripts and documentation in this repository are MIT-licensed. Ghidra, Unicorn Engine, Capstone, Keystone Engine, Android SDK components, and other third-party software remain under their own licenses.
