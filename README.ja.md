# chatgpt-sandbox-kit

ChatGPT の Linux sandbox へ大容量ツールを持ち込み、ネットワークに依存せずセットアップするための offline-first ツールキットです。

Git には第三者バイナリを入れません。Google Drive / 会話添付から `/mnt/data` に必要資材だけを持ち込み、`kit.sh` がファイルを自動検出して、分割アーカイブの欠落確認・再構築・既存 installer の呼び出しを行います。

```bash
./kit.sh inventory
./kit.sh doctor
./kit.sh install ghidra
./kit.sh install android-emulator
```

現在の Google Drive には、Ghidra / Unicorn / Capstone / Keystone、Android SDK/Emulator、apktool/JADX、Chrome、Unity、JDK/Gradle/Maven、.NET SDK、Python wheelhouse、Playwright browsers、Debian 13 開発・デバッグ・QEMU 用 `.deb` bundle が用意されています。

詳細:

- [Google Drive 資材レイアウト](docs/google-drive-layout.md)
- [ツール/検証マトリクス](docs/tool-matrix.md)
- [machine-readable manifest](manifest/artifacts.tsv)

## 既存スクリプトとの互換性

従来の `ghidra/setup.sh`、`unicorn/setup.sh`、`capstone-keystone/setup.sh`、`chrome/setup.sh`、`android-tools/setup.sh`、`android-emulator/*.sh`、`unity/setup.sh` はそのまま直接利用できます。`kit.sh` はその上位で Drive 資材の探索を担当します。

## 大容量分割ファイル

`part000` 始まり・`part001` 始まりの両方に対応し、連番が飛んでいる場合は再結合前にエラーにします。Google Drive connector の materialize によって `.bin` が追加された分割ファイルも探索対象です。

## CI について

外部ダウンロードに依存する GitHub Actions は追加していません。軽量なローカル self-test のみを持ち、実バイナリの完全な smoke test は sandbox に資材を materialize した状態で行います。
