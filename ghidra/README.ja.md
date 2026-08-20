# ChatGPT LinuxサンドボックスでGhidraを使う

このディレクトリは、外向きネットワークが制限されることがあるChatGPTのLinuxサンドボックスで、Ghidraを検証可能な形でセットアップ・操作するためのものです。

headless解析、デコンパイル一括出力、PyGhidraに対応します。

## 最短手順

```bash
./ghidra/fetch.sh
./ghidra/setup.sh
./ghidra/verify.sh --full
./ghidra/decompile.sh ./対象バイナリ
```

サンドボックスから`ghidra-dist`にも直接アクセスできない場合は、`manifest.json`とすべての`part-*`をファイル転送で持ち込みます。

```bash
./ghidra/assemble.sh \
  --manifest /path/to/manifest.json \
  --parts-dir /path/to/parts \
  --output /tmp/ghidra.zip

./ghidra/setup.sh --archive /tmp/ghidra.zip
```

## Ghidra本体をmainに入れない理由

Ghidraの公式ZIPは500MiBを大きく超え、GitHubの通常Git objectの上限より大きいため、そのまま`main`へcommitしません。

代わりに`.github/workflows/update-ghidra-dist.yml`が毎日最新版を確認し、公式ZIPを**改変せず64MiB単位に分割**して`ghidra-dist`という専用branchへ配置します。

さらに`ghidra-dist`は通常の履歴を積み上げるbranchではなく、更新のたびに新しいorphan commitを作成してforce-pushします。そのため、旧Ghidraの約500MiB単位の履歴が延々と蓄積しません。

## 毎日の自動更新

GitHub Actionsは毎日**06:17 JST**に動きます。

処理は次の通りです。

1. `NationalSecurityAgency/ghidra`の最新stable ReleaseをGitHub APIから取得
2. `ghidra_*_PUBLIC_*.zip`を特定
3. GitHub Release assetのSHA-256 digestを取得（無い場合だけrelease本文のSHA-256へfallback）
4. GitHub-hosted runner上で公式assetを取得
5. sizeとSHA-256を照合
6. ZIP内の`Ghidra/application.properties`を読み、Ghidra版と必要Java版を確認
7. そのJava版をActions上へセットアップ
8. **公式ZIPそのものを一度インストールし、`analyzeHeadless`とnative Decompilerの実smoke testを実行**
9. 公式ZIPのbytesを64MiBごとにsplit
10. chunkごとのsize/SHA-256を計算
11. 全chunkを再結合
12. 完全ZIPのSHA-256を再確認し、さらに`cmp`で元の公式ZIPとbyte-for-byte一致を確認
13. ここまで全成功した場合だけ`ghidra-dist`へpublish

現在とtag/SHA-256の両方が一致していれば、大きなZIPを再downloadせず何もしません。

## `ghidra-dist`の形

```text
ghidra-dist
└── current/
    ├── manifest.json
    ├── part-000
    ├── part-001
    ├── ...
    └── part-00N
```

`manifest.json`には少なくとも以下を記録します。

- upstream repository
- Release tag
- upstream Release URL
- 公開日時
- Ghidra version
- 元ZIPのfilename
- 元ZIPのsize
- 元ZIPのSHA-256
- 必要Java major version
- chunk size
- 各chunkのfilename / size / SHA-256

つまり`ghidra-dist`自体を信頼する必要はありません。復元後のZIPが**公式Releaseで期待されるSHA-256**に一致しなければ利用されません。

## 取得

通常は次だけです。

```bash
./ghidra/fetch.sh
```

まず、

```text
https://raw.githubusercontent.com/y52en/chatgpt-sandbox-kit/ghidra-dist/current/manifest.json
```

を見に行き、各chunkを取得・検証・再結合します。

`ghidra-dist`がまだ存在しない、またはアクセスできない場合は`version.env`に固定した公式Release URLへfallbackします。

### 取得元を変更する

split配布元：

```bash
GHIDRA_DIST_BASE_URL='https://example/path/current' ./ghidra/fetch.sh
```

直接ZIPのtransportのみ変更：

```bash
GHIDRA_DOWNLOAD_URL='https://mirror.example/ghidra.zip' \
  ./ghidra/fetch.sh --official
```

後者でも許可するSHA-256は変わりません。proxy/mirrorから別の内容が返れば拒否します。

## 完全オフラインで再結合

小さいraw GitHubファイルならChatGPT側の別のファイル取得手段で搬入できる場合があります。その場合、`manifest.json`と全chunkを同じディレクトリに置き、

```bash
./ghidra/assemble.sh \
  --manifest ./manifest.json \
  --parts-dir . \
  --output /tmp/ghidra.zip
```

だけで復元できます。

`assemble.sh`は、

- 各partのsize
- 各partのSHA-256
- 結合後ZIPのSHA-256

を順番に確認します。1byteでも改変されていれば失敗します。

## セットアップ

自動取得：

```bash
./ghidra/setup.sh
```

持ち込んだZIP：

```bash
./ghidra/setup.sh --archive /path/to/ghidra.zip
```

split配布から復元したZIPには`<archive>.manifest.json`が横に保存されます。`setup.sh`はそこからversion・SHA-256・必要Java版を読むため、例えば将来Ghidra 12.2が出ても、`main`の`version.env`更新を待たず最新版を扱えます。

sidecar manifestがないZIPについては、`version.env`に固定した既知の公式版として検証します。

インストール先：

```text
.tools/ghidra/
├── downloads/
├── installs/
│   └── <version>/
├── current -> installs/<version>/
└── pyghidra-venv/
```

## PyGhidra

Ghidraに同梱されているwheelを利用するため、PyPIへの接続は不要です。

内部的には、

```bash
python3 -m pip install --no-index \
  -f <GhidraInstallDir>/Ghidra/Features/PyGhidra/pypkg/dist \
  pyghidra
```

という公式のオフライン方式を利用します。

Pythonスクリプト：

```bash
./ghidra/pyghidra.sh script.py
```

対話環境：

```bash
./ghidra/pyghidra.sh
```

## 動作確認

軽量確認：

```bash
./ghidra/verify.sh
```

実Decompilerまで確認：

```bash
./ghidra/verify.sh --full
```

`--full`では、その場で小さなELFをコンパイルし、

```text
ELF生成
↓
analyzeHeadless
↓
auto-analysis
↓
native Ghidra Decompiler
↓
ExportDecompilation.java
↓
sandbox_add関数がC風コードに出たか確認
```

まで実行します。

## バイナリ解析

```bash
./ghidra/analyze.sh ./program
```

一時Ghidra projectを作成し、終了後削除します。

## デコンパイル一括出力

```bash
./ghidra/decompile.sh ./program
```

デフォルト出力：

```text
./program.decompiled.c
```

出力先指定：

```bash
./ghidra/decompile.sh ./program /tmp/program.c
```

`ExportDecompilation.java`がGhidraで認識された全functionを列挙し、成功したものをC風コードとして1ファイルへ出します。

## CI / テスト

通常の`CI`では546MiB級のGhidraを毎回取得しません。代わりに、

- shell構文
- Python helper
- Release resolver
- mock Ghidra setup/analyze/decompile
- split/reassemble
- chunk改変検知
- upstream digest不一致検知
- 架空の将来版`99.1`をmanifest経由でインストールできること

をオフラインで確認します。

実Ghidraそのもののsmoke testはdaily updaterと手動`Ghidra real smoke test` workflowで行います。

## 固定fallback版

`version.env`には再現性と障害時fallbackのため、既知の公式版を固定しています。daily updaterの最新版とは役割が別です。

最新版Releaseが更新されたからといって、この固定値を自動的に書き換える必要はありません。

## 注意点

- ChatGPTのLinux shell自体が外部ネットワークへ出られない場合、`fetch.sh`も直接通信できません。その場合はchunkを別経路で搬入して`assemble.sh`を使います。
- GUI利用にはX11等が必要です。headless解析には不要です。
- GPUが渡されていない環境でも通常のGhidra解析・Decompilerは利用できます。
- Ghidra Debuggerの一部機能には追加native toolやネットワークが必要です。
- `ghidra-dist`へのforce-pushをbranch protectionで禁止した場合、updaterはpublishできません。

## ライセンス

このkitの独自スクリプト・ドキュメントはMIT Licenseです。Ghidra本体はGhidra自身のライセンス・NOTICE等に従います。`ghidra-dist`は公式ZIPの内容を変更せず、transportのためにbyte列を分割したものです。
