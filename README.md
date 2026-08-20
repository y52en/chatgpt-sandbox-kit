# chatgpt-sandbox-kit

Utilities, reproducible setup scripts, and operator notes for tools that are useful inside ChatGPT's Linux sandbox.

The sandbox can execute native Linux binaries and Java/Python tooling, but outbound networking from shell processes may be unavailable. Each tool directory therefore documents how to bring required artifacts into the sandbox, verify them, and run the tool without relying on package-manager access.

## Toolkits

| Toolkit | What it provides |
| --- | --- |
| [`ghidra/`](ghidra/) | Ghidra installation, verification, headless analysis, decompilation export, PyGhidra, and an automatically maintained split distribution for sandbox-friendly downloads. |

## Repository layout

Each tool should live in its own top-level directory and be independently understandable:

```text
<tool>/
├── README.md            # English guide
├── README.ja.md         # Japanese guide when useful
├── setup.sh             # Reproducible installation/setup
├── verify.sh            # Environment and installation checks
├── ...                  # Small wrappers/scripts for common operations
└── tests/               # Offline-friendly smoke tests
```

Large third-party binaries are not committed to `main`. When a sandbox-friendly copy is needed, automation may publish verified, byte-for-byte chunks on a dedicated distribution branch instead.

## Ghidra distribution automation

The Ghidra toolkit includes a daily GitHub Actions updater:

1. resolve the latest public release from `NationalSecurityAgency/ghidra`;
2. download the official release asset on the GitHub-hosted runner;
3. verify the upstream SHA-256 digest;
4. read the bundled `application.properties` to capture the Ghidra and Java requirements;
5. smoke-test the real distribution with `analyzeHeadless` and the native decompiler;
6. split the untouched ZIP into 64 MiB chunks;
7. verify every chunk and reassemble it byte-for-byte;
8. force-publish only the verified current release to the orphan `ghidra-dist` branch.

The distribution branch is intentionally separate from `main`, so normal clones stay small and old ~500+ MiB releases do not accumulate in Git history.

`ghidra/fetch.sh` prefers this split distribution when it is available and falls back to the pinned official release URL otherwise.

## Security / trust model

Scripts in this repository do not make a mirror authoritative. A downloaded third-party tool is accepted only after its complete-file SHA-256 matches the digest expected from the upstream release metadata. Split chunks additionally have per-part SHA-256 hashes in their manifest.

For Ghidra specifically, the updater never modifies the official ZIP before splitting it. Reassembly is checked both by SHA-256 and `cmp` against the downloaded official asset before publication.

## Scope

This repository is intended for setup/automation around legitimate development, debugging, reverse engineering, interoperability, and research workflows. Use third-party tools in accordance with their licenses and any laws or policies that apply to the software or data being analyzed.

## License

The original scripts and documentation in this repository are licensed under the MIT License. Third-party software installed or downloaded by these scripts remains under its own license and is not relicensed by this repository.
