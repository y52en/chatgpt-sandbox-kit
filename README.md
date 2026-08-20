# chatgpt-sandbox-kit

Small, offline-first helpers for tools that need to run inside ChatGPT's Linux sandbox.

The sandbox can run normal Linux, Java, and Python tooling, but transferring large files into it is often more restrictive than running the tools themselves. This repository therefore avoids download automation and CI mirroring. Bring the required third-party artifact into the sandbox first, then use the local setup scripts.

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

No GitHub Actions workflows or automatic external downloads are included.

## License

Original scripts and documentation in this repository are MIT-licensed. Ghidra and other third-party software remain under their own licenses.
