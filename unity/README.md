# Unity CLI / Editor

Offline setup for a locally transferred official Unity CLI Debian package plus an optional Linux Editor `Unity.tar.xz` or split parts.

The split-part path is designed for Google Drive connector limits. Connector materialization can append `.bin`, so both `*.part001` and `*.part001.bin` are accepted.

Verify a split Editor without extracting it:

```bash
./unity/setup.sh \
  --verify-only \
  --editor-sha256-file /mnt/data/Unity-2021.3.10f1-linux.tar.xz.sha256.bin \
  /mnt/data/unity-cli-linux-amd64.deb \
  /mnt/data/Unity-2021.3.10f1-linux.tar.xz.part*.bin
```

For a full setup, omit `--verify-only`. The script then extracts the Editor and runs a batch/headless version smoke test.

Tested artifacts:

- Unity CLI `1.0.0-beta.3` (`unity-cli-linux-amd64.deb`)
- Unity Editor `2021.3.10f1` split into 10 parts
- reconstructed Editor SHA-256: `a06c789a8da1fbc395de46e8720d34f87c2a15f313a0afc43f50c64c70453ea1`
