# Android Emulator（オフラインSandboxセットアップ）

ChatGPT の Linux sandbox 内で、外部ネットワークから SDK をダウンロードせず、Google Drive 等から持ち込んだ **Linux版 Android Platform Tools** と **Linux版 Android Emulator** をセットアップするためのスクリプトです。

## 現在実機検証できている範囲

このChatGPT Linux環境で以下を実際に展開・実行して確認済みです。

| コンポーネント | 検証ファイル | 結果 |
| --- | --- | --- |
| Platform Tools | `platform-tools-latest-linux.zip` | `adb` 実行成功 |
| Android Emulator | `emulator-linux_x64-16079175.zip`（分割ZIPからの復元も検証） | `emulator -version` 実行成功 |

確認できたバージョン:

```text
Android Debug Bridge version 1.0.41
Version 37.0.1-15733141

Android emulator version 37.2.5.0 (build_id 16079175)
```

今回実際に検証したファイル:

```text
platform-tools-latest-linux.zip
  size:    9,054,187 bytes
  sha256:  d230f13842f60f782a8645f9c813f8f845bf36089ea7289f28c48f17979313f1

emulator-linux_x64-16079175.zip
  size:    351,290,892 bytes
  sha256:  b93886aeeaa264e4cd0cc9ad57428df8fccb33f17e71392428f5dd221877a97e
```

Emulator は以下の分割ファイルからの連結・ZIP CRC検証にも成功しています。

```text
emulator-linux_x64-16079175.zip.part001  256,000,000 bytes
emulator-linux_x64-16079175.zip.part002   95,290,892 bytes
```

Google Drive コネクタ経由では2つ目のファイル名末尾に `.bin` が付く場合がありますが、`setup.sh` は拡張子に依存せず、渡されたEmulatorパートをversion sortして連結します。

## 現Sandboxの制約: KVMなし

現在の環境には `/dev/kvm` がありません。

```text
/dev/kvm is not found: VT disabled in BIOS or KVM kernel module not loaded
```

一方、今回のEmulatorバイナリには `-no-accel` / `-accel off` が存在することを実測確認済みです。そのためソフトウェアCPUエミュレーション自体は選択できます。

ただし、**Androidの実ブートはまだ検証済みとはしていません**。ブートには別途互換性のある system image / AVD が必要だからです。

system image導入後は、まず以下のようなheadless起動を試します。

```bash
emulator @<avd-name> \
  -no-window \
  -no-audio \
  -no-boot-anim \
  -gpu software \
  -accel off \
  -no-snapshot
```

KVMなしでCIに実用的な速度が出るかは、system image導入後に実測します。

## セットアップ

Emulatorが1つのZIPの場合:

```bash
./android-emulator/setup.sh \
  --platform-tools-sha256 d230f13842f60f782a8645f9c813f8f845bf36089ea7289f28c48f17979313f1 \
  --emulator-sha256 b93886aeeaa264e4cd0cc9ad57428df8fccb33f17e71392428f5dd221877a97e \
  /mnt/data/platform-tools-latest-linux.zip \
  /mnt/data/emulator-linux_x64-16079175.zip
```

Emulatorが分割されている場合:

```bash
./android-emulator/setup.sh \
  --platform-tools-sha256 d230f13842f60f782a8645f9c813f8f845bf36089ea7289f28c48f17979313f1 \
  --emulator-sha256 b93886aeeaa264e4cd0cc9ad57428df8fccb33f17e71392428f5dd221877a97e \
  /mnt/data/platform-tools-latest-linux.zip \
  /mnt/data/emulator-linux_x64-16079175.zip.part001 \
  /mnt/data/emulator-linux_x64-16079175.zip.part002.bin
```

デフォルトでは次のSDK形式のディレクトリを作ります。

```text
/mnt/data/android-emulator-kit/sdk/
├── emulator/
└── platform-tools/
```

`setup.sh` が行う処理:

1. 必要ならEmulator分割ファイルを連結
2. 指定時は双方のSHA-256を検証
3. ZIP全体のCRC/整合性検査
4. 1つのSDK rootへ展開
5. ELFの不足共有ライブラリを確認
6. `adb version` と `emulator -version` を実行
7. ADB serverの起動・停止をsmoke test
8. `-no-accel` / `-accel off` 対応を確認
9. `ANDROID_HOME` / `ANDROID_SDK_ROOT` / `PATH` を含む `env.sh` を生成

セットアップ後:

```bash
source /mnt/data/android-emulator-kit/env.sh
./android-emulator/verify.sh
```

## 次に行うこと

system image はこのスクリプトからダウンロードしません。互換性のあるAndroid system imageをsandboxへ持ち込めた段階で、オフラインAVD作成、実ブート、ADB接続、APKインストール、UIテストまで追加できます。

Android SDK各コンポーネント自体はリポジトリへ含めず、それぞれ上流のライセンスに従います。
