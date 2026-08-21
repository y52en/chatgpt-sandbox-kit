# chatgpt-sandbox-kit

ChatGPT の Linux sandbox へ大容量ツールを持ち込み、開発・デバッグ・リバースエンジニアリング・ブラウザ自動化・Android テスト・Unity 作業を offline-first で行うためのツールキットです。

第三者バイナリは Git に含めません。Google Drive / 会話添付を搬送経路として使い、資材を `/mnt/data` に materialize した後は、外部から代替ファイルをダウンロードせずローカルで利用します。

> **ChatGPT / coding agent でこのリポジトリを使う場合:** 最初に [`AGENTS.md`](AGENTS.md) を読ませてください。`AGENTS.md` にはツールの配置場所だけを記載し、セットアップ手順はすべて [`docs/setup/`](docs/setup/) に分離しています。

## まず使うコマンド

```bash
./kit.sh inventory --strict
./kit.sh doctor
./kit.sh list
./kit.sh install ghidra
```

`kit.sh` は materialize 済み資材を再帰的に探索し、重複・既知の分割アーカイブ欠落を確認して各ツール専用 installer を呼び出します。Google Drive の認証情報やファイル ID はリポジトリへ保存しません。

セットアップ手順は [`docs/setup/README.md`](docs/setup/README.md)、現在の Drive 資材一覧は [`docs/google-drive-layout.md`](docs/google-drive-layout.md)、対応状況と検証内容は [`docs/tool-matrix.md`](docs/tool-matrix.md) を参照してください。

## 現在の対象

Ghidra / PyGhidra、Unicorn / Capstone / Keystone、apktool / JADX、Android SDK / Emulator、Chrome / ChromeDriver、Unity、JDK / Gradle / Maven、.NET SDK、Python wheelhouse、Playwright browsers、Debian 13 開発・デバッグ・QEMU 用 `.deb` bundle を対象にしています。

大容量ファイルは完全アーカイブのほか、`part000` または `part001` 始まりの分割ファイルを扱えます。現在の manifest には既知資材の開始番号と part 数も保持しているため、末尾 part の欠落も再構築前に検出します。connector が `.bin` を追加したファイル名にも対応します。

外部ダウンロードに依存する GitHub Actions は追加していません。軽量な self-test は `./kit.sh self-test` で実行し、実バイナリの完全な smoke test は資材を sandbox に materialize した状態で行います。
