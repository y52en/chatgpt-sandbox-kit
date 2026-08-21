# Android Emulator (offline sandbox setup)

This directory prepares locally transferred **Linux Android Platform Tools** and the **Linux Android Emulator** inside ChatGPT's Linux sandbox without downloading SDK components from the network.

The setup is intended for the same transport model as the rest of this repository: put large official archives in Google Drive, materialize them under `/mnt/data`, then reconstruct and install locally.

## What is verified today

The following artifacts were tested directly in the current ChatGPT Linux sandbox:

| Component | Tested artifact | Result |
| --- | --- | --- |
| Platform Tools | `platform-tools-latest-linux.zip` | `adb` runs successfully |
| Android Emulator | `emulator-linux_x64-16079175.zip` (also tested from split parts) | `emulator -version` runs successfully |

Observed versions:

```text
Android Debug Bridge version 1.0.41
Version 37.0.1-15733141

Android emulator version 37.2.5.0 (build_id 16079175)
```

Verified archive metadata for the exact files used in the test:

```text
platform-tools-latest-linux.zip
  size:    9,054,187 bytes
  sha256:  d230f13842f60f782a8645f9c813f8f845bf36089ea7289f28c48f17979313f1

emulator-linux_x64-16079175.zip
  size:    351,290,892 bytes
  sha256:  b93886aeeaa264e4cd0cc9ad57428df8fccb33f17e71392428f5dd221877a97e
```

The Emulator ZIP was also reconstructed successfully from:

```text
emulator-linux_x64-16079175.zip.part001  256,000,000 bytes
emulator-linux_x64-16079175.zip.part002   95,290,892 bytes
```

The second part may arrive from the Drive connector with an extra `.bin` suffix; the setup script does not depend on the suffix and concatenates all Emulator inputs in version-sort order.

## Sandbox limitation: no KVM

The current sandbox does not expose `/dev/kvm`:

```text
/dev/kvm is not found: VT disabled in BIOS or KVM kernel module not loaded
```

The tested Emulator build still advertises both `-no-accel` and `-accel off`, so software CPU emulation is available in principle. Actual Android boot is **not yet claimed as verified** because a compatible Android system image/AVD is still required.

Once a system image is available, the intended headless launch shape is:

```bash
emulator @<avd-name> \
  -no-window \
  -no-audio \
  -no-boot-anim \
  -gpu software \
  -accel off \
  -no-snapshot
```

Whether that is fast enough for practical CI must be measured after the system image is installed.

## Setup

For a complete Emulator ZIP:

```bash
./android-emulator/setup.sh \
  --platform-tools-sha256 d230f13842f60f782a8645f9c813f8f845bf36089ea7289f28c48f17979313f1 \
  --emulator-sha256 b93886aeeaa264e4cd0cc9ad57428df8fccb33f17e71392428f5dd221877a97e \
  /mnt/data/platform-tools-latest-linux.zip \
  /mnt/data/emulator-linux_x64-16079175.zip
```

For split Emulator parts:

```bash
./android-emulator/setup.sh \
  --platform-tools-sha256 d230f13842f60f782a8645f9c813f8f845bf36089ea7289f28c48f17979313f1 \
  --emulator-sha256 b93886aeeaa264e4cd0cc9ad57428df8fccb33f17e71392428f5dd221877a97e \
  /mnt/data/platform-tools-latest-linux.zip \
  /mnt/data/emulator-linux_x64-16079175.zip.part001 \
  /mnt/data/emulator-linux_x64-16079175.zip.part002.bin
```

By default the SDK-like directory is created at:

```text
/mnt/data/android-emulator-kit/sdk/
├── emulator/
└── platform-tools/
```

The setup script:

1. reconstructs split Emulator parts when necessary;
2. optionally verifies both SHA-256 hashes;
3. performs ZIP CRC/integrity checks;
4. extracts both components into one SDK root;
5. checks for missing dynamic-library dependencies;
6. runs `adb version` and `emulator -version`;
7. starts/stops the ADB server as a smoke test;
8. verifies that `-no-accel` / `-accel off` is supported;
9. writes an `env.sh` exporting `ANDROID_HOME`, `ANDROID_SDK_ROOT`, and `PATH`.

Load the environment with:

```bash
source /mnt/data/android-emulator-kit/env.sh
```

Then verify again at any time:

```bash
./android-emulator/verify.sh
```

## Next step

A system image is deliberately not bundled or downloaded by these scripts. When a compatible Android system image is transferred into the sandbox, this directory can be extended with offline AVD creation plus an actual boot/ADB/UI-test smoke test.

Third-party Android SDK components remain under their respective upstream licenses; this repository does not vendor them.
