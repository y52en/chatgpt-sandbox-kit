# Android command-line tools

Offline layout and smoke testing for Google's Linux Android command-line tools, optionally with Platform Tools.

```bash
./android-tools/setup.sh \
  /mnt/data/commandlinetools-linux-15859902_latest.zip \
  /mnt/data/platform-tools-latest-linux.zip
source /mnt/data/android-tools-kit/env.sh
sdkmanager --version
adb version
```

The command-line ZIP is installed at the SDK-required `cmdline-tools/latest` path. The smoke test unsets proxy environment variables before invoking `sdkmanager`, because malformed sandbox proxy variables can otherwise make Java reject startup before any network request occurs.

The newer `android` launcher bundled with current command-line tools is not used for offline verification: on first invocation it currently attempts to download the standalone Android CLI. `sdkmanager` remains usable from the transferred archive without that bootstrap download.

Tested with command-line tools build `15859902` (`sdkmanager 22.0`).
