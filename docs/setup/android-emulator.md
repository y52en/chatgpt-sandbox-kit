# Android Emulator / AVD

Current Drive sources:

- `AndroidEmulator/platform-tools-latest-linux.zip`
- `emulator-linux_x64-16079175.zip.part001..002`
- `x86_64-30_r16.zip.part001..006`

Prepare the SDK and AVD:

```bash
./kit.sh install android-emulator
```

Boot the prepared AVD:

```bash
./android-emulator/boot.sh --fresh
```

If `/dev/kvm` is unavailable, the boot helper uses software CPU emulation (`-accel off`). APK installation and launch checks are available through `android-emulator/install-apk.sh` and `android-emulator/smoke-test.sh`.

Default workspace: `/mnt/data/android-emulator-kit`.
