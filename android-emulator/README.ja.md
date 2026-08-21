# Android Emulator（オフラインSandboxセットアップ）

ChatGPT の Linux sandbox 上に、外部ネットワークからSDKをダウンロードせず **Android Emulator + ADB + system image + APK CI環境** を構築するためのスクリプトです。Android SDKのバイナリ自体はGitへ含めず、Google Drive等から `/mnt/data` へ持ち込んで使用します。

現在は以下の一連の経路まで実機検証済みです。

```text
Platform Tools + Android Emulator + Android 11 system image
                           ↓
                    headless AVD
                 (-accel off / TCG)
                           ↓
                 adb install / am start
                           ↓
                 screenshot + logcat
```

## このSandboxで実証できたもの

| コンポーネント | 検証ファイル | 結果 |
| --- | --- | --- |
| Platform Tools | `platform-tools-latest-linux.zip` | ADB server/client 動作 |
| Android Emulator | `emulator-linux_x64-16079175.zip` | Emulator 37.2.5 動作 |
| System image | `x86_64-30_r16.zip` | Android 11 / API 30 / Google APIs / x86_64 起動成功 |
| APK install | system image内の `BasicDreams.apk` | `adb install` で `/data/app` への更新成功 |
| UI smoke | Android Settings | Activity起動、720x1280 screenshot、logcat取得成功 |

確認したバージョン:

```text
Android Debug Bridge version 1.0.41
Platform Tools 37.0.1-15733141
Android Emulator 37.2.5.0 (build_id 16079175)
Android 11 / API 30 / x86_64
```

実際に検証したアーカイブ:

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

system image は6分割ファイルから連結し、ZIP CRC検査まで成功しています。Google Drive経由で `.part002.bin` のように `.bin` が追加されても、各スクリプトは渡されたファイルをversion sortして連結するため問題ありません。

## 重要: KVMなしでも起動した

現在のChatGPT sandboxには `/dev/kvm` がありません。そのためQEMU TCGによる完全ソフトウェアCPUエミュレーション (`-accel off`) を使用します。

それでも **Android 11 / API 30 x86_64の実ブートに成功**しました。

今回の初回cold boot実測値:

```text
Boot completed in 488685 ms
```

約 **8分09秒** です。高速ではありませんが、APK解析・CI・E2Eを実行できる水準までAndroid Frameworkが起動します。

また初回bootでは `sys.boot_completed=1` の直後にFramework serviceが一時的に不安定になることがありました。そのため `boot.sh` は5秒間隔で2回、以下がすべて正常であることを確認してからreadyと判定します。

- `sys.boot_completed=1`
- `dev.bootcomplete=1`
- `init.svc.bootanim=stopped`
- `package` service が `found`
- `activity` service が `found`
- `window` service が `found`

単純に `sys.boot_completed` だけを見るCIより安全です。

## 1. Platform Tools + Emulator

```bash
./android-emulator/setup.sh \
  --platform-tools-sha256 d230f13842f60f782a8645f9c813f8f845bf36089ea7289f28c48f17979313f1 \
  --emulator-sha256 b93886aeeaa264e4cd0cc9ad57428df8fccb33f17e71392428f5dd221877a97e \
  /mnt/data/platform-tools-latest-linux.zip \
  /mnt/data/emulator-linux_x64-16079175.zip.part001 \
  /mnt/data/emulator-linux_x64-16079175.zip.part002.bin
```

`setup.sh` はZIP復元/CRC/SHA-256、ELF依存関係、ADB server、Emulatorバイナリ、`-accel off` 対応まで確認します。

## 2. System image復元 + AVD作成

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

`source.properties` をZIP内部から読み、API level / tag / ABI / revisionを取得します。`sdkmanager` / `avdmanager` は不要で、AVD設定を直接生成します。

デフォルト構成:

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

## 3. Headless boot

```bash
./android-emulator/boot.sh --avd-name ci-api30
```

主なオプション:

```text
--timeout 1200   ready待ち上限
--wipe-data      userdata初期化
--fresh          同一portの既存Emulatorを停止して再起動
--port 5554      Emulator/ADB port
```

`/dev/kvm` が無い場合は自動的に `-accel off` を追加します。

## 4. APKインストール

```bash
./android-emulator/install-apk.sh \
  --package com.example.app \
  /mnt/data/app.apk
```

TCGではAPK転送後のdexopt等が遅く、Android側ではインストール済みなのにホスト側 `adb install` clientだけ長時間終了しない場合があります。

そのため `--package` 指定時は:

1. `adb install` をバックグラウンド開始
2. PackageManagerを監視
3. `/data/app/.../base.apk` が新規作成/更新されたことを確認
4. Android側のコミット成功としてCIを先へ進める

という方式です。

実際に `com.android.dreams.basic` を複数回再インストールし、そのたびに `/data/app` のパスが更新されることを確認しました。

## 5. APK/UI smoke test

launcher activityを自動解決する場合:

```bash
./android-emulator/smoke-test.sh \
  --package com.example.app \
  /mnt/data/app.apk
```

Activityを明示する場合:

```bash
./android-emulator/smoke-test.sh \
  --package com.example.app \
  --activity .MainActivity \
  /mnt/data/app.apk
```

実行内容:

1. APK install（`--skip-install` で省略可）
2. launcher Activity解決または指定Activity起動
3. screenshot保存
4. bounded logcat保存
5. 対象packageの `FATAL EXCEPTION` / ANR / native crash marker検出

実機検証ではAndroid SettingsのActivityを起動し、**720x1280 PNG** とlogcatを取得、対象packageのcrash markerは0件でした。

## 再検証

```bash
source /mnt/data/android-emulator-kit/env.sh
./android-emulator/verify.sh
```

Android SDK各コンポーネント自体はGitへ含めず、各上流ライセンスに従います。
