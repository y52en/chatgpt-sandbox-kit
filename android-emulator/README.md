# Android Emulator (offline sandbox setup)

This directory provides an offline-first Android test environment for ChatGPT's Linux sandbox. Android SDK binaries are **not** vendored in Git and are never downloaded by these scripts. Transfer the official Linux archives through Google Drive or another available file channel, materialize them under `/mnt/data`, and install them locally.

The complete tested path is now:

```text
Platform Tools + Android Emulator + Android 11 system image
                           |
                           v
                    headless AVD
                 (-accel off / TCG)
                           |
                           v
                 adb install / am start
                           |
                           v
                 screenshot + logcat
```

## Verified in the current ChatGPT sandbox

| Component | Tested artifact | Result |
| --- | --- | --- |
| Platform Tools | `platform-tools-latest-linux.zip` | ADB server/client works |
| Android Emulator | `emulator-linux_x64-16079175.zip` | Emulator 37.2.5 runs |
| System image | `x86_64-30_r16.zip` | Android 11 / API 30 / Google APIs / x86_64 boots |
| APK install | `BasicDreams.apk` pulled from the image | `adb install` commits an update under `/data/app` |
| UI smoke test | Android Settings | Activity launch, 720x1280 screenshot and logcat collection work |

Observed versions:

```text
Android Debug Bridge version 1.0.41
Platform Tools 37.0.1-15733141
Android Emulator 37.2.5.0 (build_id 16079175)
Android 11 / API 30 / x86_64
```

Exact tested archive metadata:

```text
platform-tools-latest-linux.zip
  size:    9,054,187 bytes
  sha256:  d230f13842f60f782a8645f9c813f8f845bf36089ea7289f28c48f17979313f1

emulator-linux_x64-16079175.zip
  size:    351,290,892 bytes
  sha256:  b93886aeeaa264e4cd0cc9ad57428df8fccb33f17e71392428f5dd221877a97e

x86_64-30_r16.zip
  size:    1,438,186,618 bytes
  sha256:  daae27654be74ae83a484daea4db2c0c77b4f4ad661a645bd5f36d96ce03e4d5
```

The system-image ZIP was reconstructed and CRC-tested from six 256 MB-or-smaller parts. Google Drive materialization may append `.bin` to later parts; all reconstruction scripts sort the supplied paths by version and do not depend on the final extension.

## Important sandbox constraint: no KVM

The current sandbox does not expose `/dev/kvm`, so the Emulator uses QEMU TCG with `-accel off`. This is functional but slow.

The measured first cold boot of the tested API 30 AVD was:

```text
Boot completed in 488685 ms
```

That is about 8 minutes 9 seconds. During the first boot, Android may report `sys.boot_completed=1` before framework services have fully stabilized. `boot.sh` therefore requires two healthy snapshots five seconds apart, each checking:

- `sys.boot_completed=1`
- `dev.bootcomplete=1`
- `init.svc.bootanim=stopped`
- `package` service available
- `activity` service available
- `window` service available

This avoids treating a transient `boot_completed` value as CI readiness.

## 1. Install Platform Tools and Emulator

Complete Emulator ZIP:

```bash
./android-emulator/setup.sh \
  --platform-tools-sha256 d230f13842f60f782a8645f9c813f8f845bf36089ea7289f28c48f17979313f1 \
  --emulator-sha256 b93886aeeaa264e4cd0cc9ad57428df8fccb33f17e71392428f5dd221877a97e \
  /mnt/data/platform-tools-latest-linux.zip \
  /mnt/data/emulator-linux_x64-16079175.zip
```

Split Emulator ZIP:

```bash
./android-emulator/setup.sh \
  --platform-tools-sha256 d230f13842f60f782a8645f9c813f8f845bf36089ea7289f28c48f17979313f1 \
  --emulator-sha256 b93886aeeaa264e4cd0cc9ad57428df8fccb33f17e71392428f5dd221877a97e \
  /mnt/data/platform-tools-latest-linux.zip \
  /mnt/data/emulator-linux_x64-16079175.zip.part001 \
  /mnt/data/emulator-linux_x64-16079175.zip.part002.bin
```

## 2. Install the system image and create an AVD

The script reads `source.properties` from the supplied ZIP, so the API level, tag and ABI are derived from the archive instead of being hard-coded. It creates the AVD directly and does not require `sdkmanager` or `avdmanager`.

```bash
./android-emulator/install-system-image.sh \
  --sha256 daae27654be74ae83a484daea4db2c0c77b4f4ad661a645bd5f36d96ce03e4d5 \
  --avd-name ci-api30 \
  /mnt/data/x86_64-30_r16.zip.part001 \
  /mnt/data/x86_64-30_r16.zip.part002.bin \
  /mnt/data/x86_64-30_r16.zip.part003.bin \
  /mnt/data/x86_64-30_r16.zip.part004.bin \
  /mnt/data/x86_64-30_r16.zip.part005.bin \
  /mnt/data/x86_64-30_r16.zip.part006.bin
```

The default workspace becomes:

```text
/mnt/data/android-emulator-kit/
├── sdk/
│   ├── emulator/
│   ├── platform-tools/
│   └── system-images/android-30/google_apis/x86_64/
├── avd/
│   └── ci-api30.avd/
├── run/
└── env.sh
```

## 3. Boot and wait for stable Android readiness

```bash
./android-emulator/boot.sh --avd-name ci-api30
```

Useful options:

```text
--timeout 1200   maximum readiness wait
--wipe-data      reset userdata before boot
--fresh          stop an emulator already using the selected port
--port 5554      select the emulator/ADB port
```

When `/dev/kvm` is absent, `boot.sh` automatically adds `-accel off`. The tested headless launch also uses no window/audio/boot animation/snapshot and the SwiftShader GPU backend.

## 4. Install an APK

Supplying the package/application id is recommended in this TCG environment:

```bash
./android-emulator/install-apk.sh \
  --package com.example.app \
  /mnt/data/app.apk
```

`adb install` can keep its host-side client open while slow dexopt work continues. With `--package`, the helper starts installation asynchronously and polls PackageManager. For a new APK, a new `/data/app` path is sufficient confirmation; for an update, the path must change unless ADB itself returns `Success`.

This behavior was tested by reinstalling `com.android.dreams.basic`; each successful update changed its `/data/app/.../base.apk` path even when the original `adb install` client was still waiting.

## 5. APK/UI smoke test

For an APK with a launcher activity:

```bash
./android-emulator/smoke-test.sh \
  --package com.example.app \
  /mnt/data/app.apk
```

For a known explicit activity:

```bash
./android-emulator/smoke-test.sh \
  --package com.example.app \
  --activity .MainActivity \
  /mnt/data/app.apk
```

The smoke test:

1. installs the APK unless `--skip-install` is used;
2. resolves or uses the requested activity;
3. starts it with ActivityManager;
4. captures a PNG screenshot;
5. saves a bounded logcat dump;
6. fails on package-scoped Java FATAL exceptions, ANRs, or native crash markers.

The current sandbox test successfully launched Android Settings and produced a valid 720x1280 PNG plus logcat with no package-scoped crash marker.

## Verification and environment

`setup.sh` verifies ZIP integrity, ELF dependencies, ADB startup, Emulator startup, and software-emulation support:

```bash
./android-emulator/verify.sh
```

Load the generated environment manually if needed:

```bash
source /mnt/data/android-emulator-kit/env.sh
```

Third-party Android SDK components remain under their upstream licenses and are not committed to this repository.
