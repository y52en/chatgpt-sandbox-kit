# Capstone + Keystone オフラインセットアップ

このディレクトリは、あらかじめ ChatGPT の Linux サンドボックスへ転送した Capstone / Keystone Engine の Python wheel をオフライン導入するためのものです。wheel の搬送は **GitHub の分割バイナリではなく Google Drive を前提**にします。

`setup.sh` 自身は PyPI や外部ホストからダウンロードしません。ローカルに存在する2つのwheelだけを `pip --no-index --no-deps` でインストールします。

## 推奨: ChatGPT + Google Drive

1. 手元のPCで Linux x86-64向けのwheelを用意する。
2. `.whl` を Google Drive に置く。
3. ChatGPT に Drive 上のファイルをLinuxサンドボックスへ取得/materializeさせる（通常は `/mnt/data` 配下）。
4. 取得した2ファイルを `capstone-keystone/setup.sh` に渡す。
5. 任意のSHA-256確認、専用venv作成、完全オフラインinstall、Keystone→Capstoneの実動作テストまで自動実行する。

GitHubのリポジトリファイル取得ではバイナリがツールレスポンスへbase64として展開され、数KB程度でも応答上限に達する場合があります。Google Driveではmulti-MBのwheelをその形でレスポンスへ展開せずサンドボックスへ搬送できるため、この用途ではDriveを推奨します。

## 動作確認済み構成

Linux x86-64 / Python 3.13.5 で以下を実際に確認済みです。

- Capstone 5.0.9
  - `capstone-5.0.9-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl`
  - SHA-256: `273fd8d747d2e35c88f91450be51a603ecfaafb00d96d9f315dcb8689c86193e`
- Keystone Engine 0.9.2
  - `keystone_engine-0.9.2-py2.py3-none-manylinux1_x86_64.whl`
  - SHA-256: `5a5316a34323620b1bba31dcfe9e4b4ca6f0c030e82fc7a151da7c8fbe81a379`

これは既知の動作確認例であり、バージョンを固定する仕組みではありません。互換性のある新しいwheelも同じ手順で渡せます。

## セットアップ

```bash
./capstone-keystone/setup.sh \
  --capstone-sha256 273fd8d747d2e35c88f91450be51a603ecfaafb00d96d9f315dcb8689c86193e \
  --keystone-sha256 5a5316a34323620b1bba31dcfe9e4b4ca6f0c030e82fc7a151da7c8fbe81a379 \
  /mnt/data/capstone-5.0.9-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl \
  /mnt/data/keystone_engine-0.9.2-py2.py3-none-manylinux1_x86_64.whl
```

2つのwheelの引数順序は問いません。ファイル名からCapstone/Keystoneを判別します。

`/mnt/data` が存在する場合、デフォルトでは `/mnt/data/capstone-keystone-kit/venv` を作成します。それ以外では `./.tools/capstone-keystone/venv` を使います。

作業先やPythonを変更する場合:

```bash
./capstone-keystone/setup.sh \
  --work-dir /mnt/data/my-capstone-keystone \
  --python python3 \
  /mnt/data/capstone-*.whl \
  /mnt/data/keystone_engine-*.whl
```

## 動作確認

`setup.sh` の最後に `verify.py` を自動実行します。Keystoneで

```asm
mov eax, 0x12345678
inc eax
```

をassembleし、期待するmachine codeと完全一致することを確認した後、そのbytesをCapstoneでdisassembleして期待する2命令へ戻ることを確認します。

再度実行する場合:

```bash
CAPSTONE_KEYSTONE_WORK_DIR=/mnt/data/capstone-keystone-kit \
  ./capstone-keystone/python.sh ./capstone-keystone/verify.py
```

## 完全オフライン動作

インストールは次だけを使用します。

```text
pip install --no-index --no-deps <capstone-wheel> <keystone-wheel>
```

PyPIへのfallbackはありません。また、このリポジトリではCapstone/Keystoneのwheelをvendor・分割保存・定期自動更新しません。

## ライセンス

このリポジトリの独自スクリプト・ドキュメントはMIT Licenseです。Capstone / Keystone Engine本体は各upstreamのライセンスに従います。private Driveの外へwheelを再配布する場合は、upstreamのライセンス通知も適切に保持してください。
