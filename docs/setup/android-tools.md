# Android command-line tools

Current Drive sources include `Android/commandlinetools-linux-15859902_latest.zip`, its SHA-256 sidecar, and Platform Tools from the materialized asset set.

```bash
./kit.sh install android-tools
```

When the SHA-256 sidecar is present, `kit.sh` passes the expected hash to the existing installer. The offline smoke test uses `sdkmanager`; it deliberately avoids the newer `android` launcher because that launcher may bootstrap from the network on first run.

Default workspace: `/mnt/data/android-tools-kit`.
