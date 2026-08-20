# chatgpt-sandbox-kit

Small, offline-first helpers for tools that need to run inside ChatGPT's Linux sandbox.

The sandbox can run normal Linux, Java, and Python tooling, but transferring files into it is often more restrictive than running the tools themselves. This repository therefore avoids download automation and CI mirroring. Bring the required third-party artifact into the sandbox first, then use the local setup scripts.

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

No GitHub Actions workflows or automatic external downloads are included.

## License

Original scripts and documentation in this repository are MIT-licensed. Ghidra, Unicorn Engine, and other third-party software remain under their own licenses.
