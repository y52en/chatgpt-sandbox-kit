# Ghidra / PyGhidra for ChatGPT Linux sandbox

このディレクトリは、ChatGPT の Linux コンテナで **外部ダウンロードに依存せず** Ghidra と PyGhidra を使うための最小構成です。

## 前提

Ghidra の公式 ZIP 自体はこのリポジトリから取得しません。Google Drive、会話への添付など、利用できる方法で先にコンテナへ持ち込んでください。

現在の ChatGPT の Google Drive 連携では、単一ファイルが約 256 MiB を超えると `413 File too large` になる場合があります。その場合は、元 ZIP を **250 MB 前後以下の part** に分割して Drive に置く方法が安定です。

例:

```text
ghidra_12.1.3_PUBLIC_20260817.zip.part001
ghidra_12.1.3_PUBLIC_20260817.zip.part002
ghidra_12.1.3_PUBLIC_20260817.zip.part003
```

Drive コネクタから取得した `application/octet-stream` の part は、コンテナ側で `.bin` が末尾に付くことがあります。`setup.sh` は `part002.bin` のような名前でも問題なく扱えます。

## ChatGPT + Google Drive での流れ

1. Ghidra ZIP をローカルPCで分割する。
2. part ファイルを Google Drive にアップロードする。
3. ChatGPT に各 part を Drive から取得させる。
4. `/mnt/data` に part が揃ったことを確認する。
5. `setup.sh` に part を順番を気にせず渡す。

```bash
./ghidra/setup.sh \
  --sha256 93a5d11a9ad510622acaaf908c556a7b9b764d338e78a7567f3689bf5081fd54 \
  /mnt/data/ghidra_12.1.3_PUBLIC_20260817.zip.part001 \
  /mnt/data/ghidra_12.1.3_PUBLIC_20260817.zip.part002.bin \
  /mnt/data/ghidra_12.1.3_PUBLIC_20260817.zip.part003.bin
```

`setup.sh` は入力を `sort -V` で並べてから連結するため、引数の順序は問いません。

SHA-256 が不明な別バージョンを使う場合は `--sha256` を省略できます。ただし、出所の検証が必要な場合は信頼できる場所で確認したハッシュを指定してください。

単一 ZIP がすでに `/mnt/data` にある場合:

```bash
./ghidra/setup.sh /mnt/data/ghidra_12.1.3_PUBLIC_20260817.zip
```

## setup.sh が行うこと

- part 群を1つのZIPへ復元
- 完成ZIPの SHA-256 を表示・任意で照合
- `unzip -t` によるZIP整合性検査
- Ghidra展開
- `Ghidra/application.properties` から以下を確認
  - Ghidraバージョン
  - 最低Javaバージョン
  - 対応Pythonバージョン
- Python venv 作成
- Ghidraに同梱された `PyGhidra/pypkg/dist` の wheel だけを使い、`pip --no-index` でPyGhidraをインストール
- JVMを起動し `ghidra.framework.Application` をロードして実動確認

ネットワークから `pip install` したり、GitHub等からGhidraをダウンロードしたりしません。

既定の作業先は ChatGPT sandbox では `/mnt/data/ghidra-kit` です。変更したい場合:

```bash
GHIDRA_WORK_DIR=/mnt/data/my-ghidra ./ghidra/setup.sh /mnt/data/ghidra*.part*
```

## PyGhidraを使う

公式PyGhidra CLI:

```bash
./ghidra/pyghidra.sh --help
```

バイナリを開いて解析し、REPLへ入る:

```bash
./ghidra/pyghidra.sh /mnt/data/sample.bin
```

PythonスクリプトからPyGhidra APIを使う:

```python
import pyghidra

pyghidra.start()

from ghidra.framework import Application
print(Application.getApplicationVersion())
```

実行:

```bash
./ghidra/python.sh script.py
```

環境を直接使いたい場合は生成されたファイルを source できます。

```bash
source /mnt/data/ghidra-kit/env.sh
"$PYGHIDRA_VENV/bin/python"
```

ラッパーは Python の safe-path (`-P`) を使います。これはリポジトリ自身の `ghidra/` ディレクトリが PyGhidra の Java パッケージ import と衝突するのを防ぐためです。

## 確認

```bash
./ghidra/verify.sh
```

`verify.sh` は Java、`analyzeHeadless`、PyGhidra、JPype、Ghidra Javaクラスのロードを確認します。

## Ghidra 12.1.3 で実際に確認した構成

この手順は以下で実動確認しています。

- Ghidra 12.1.3 PUBLIC (`20260817`)
- ZIPサイズ: `569445154` bytes
- SHA-256: `93a5d11a9ad510622acaaf908c556a7b9b764d338e78a7567f3689bf5081fd54`
- Java: OpenJDK 21
- Python: 3.13
- PyGhidra: 3.1.0
- JPype: 1.5.2

Ghidra 12.1.3 自体の `application.properties` では Python 3.9〜3.14、Java 21以上が指定されています。

## CIについて

GitHub Actions / CI は意図的にありません。大きな外部ファイルの取得・ミラー・配布を自動化せず、実際に sandbox へ持ち込めたローカルファイルだけを扱う方針です。
