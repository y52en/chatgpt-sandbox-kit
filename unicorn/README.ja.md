# Unicorn Engine オフラインセットアップ

このディレクトリは、あらかじめ ChatGPT の Linux サンドボックスへ転送した wheel から [Unicorn Engine](https://www.unicorn-engine.org/) の Python バインディングを導入するためのものです。

PyPI やその他の外部ホストから自動ダウンロードは行いません。

## 動作確認済み環境

以下の組み合わせで実際に動作確認済みです。

- Linux x86-64
- Python 3.13.5
- Unicorn 2.1.4
- wheel: `unicorn-2.1.4-cp37-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl`

`cp37-abi3` のため CPython 3.7 以降で利用でき、Python 3.13 でも使用できます。`manylinux_2_17_x86_64` はサンドボックスの x86-64 / glibc 環境と互換性があります。

## セットアップ

wheel をサンドボックスへ転送した後、次を実行します。

```bash
./unicorn/setup.sh /mnt/data/unicorn-2.1.4-cp37-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl
```

`/mnt/data` が存在する場合、デフォルトでは `/mnt/data/unicorn-kit/venv` に専用の仮想環境を作成します。それ以外では `./.tools/unicorn/venv` を使用します。

配置先や Python を指定する場合:

```bash
./unicorn/setup.sh \
  --work-dir /mnt/data/my-unicorn \
  --python python3 \
  /mnt/data/unicorn-2.1.4-cp37-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl
```

SHA-256 も確認する場合:

```bash
./unicorn/setup.sh \
  --sha256 9d6e6dea140560de4ebd8446661f7ef84a357d428c14a3ef09dacd306ec8c239 \
  /mnt/data/unicorn-2.1.4-cp37-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl
```

上記ハッシュは今回 ChatGPT サンドボックスで実際に使用した wheel の SHA-256 です。配布元の真正性が重要な場合は別経路でも確認してください。

## 動作確認

`setup.sh` は最後に `verify.py` を自動実行します。32-bit x86 の Unicorn インスタンスで次のコードを実際にエミュレーションします。

```asm
mov eax, 0x12345678
inc eax
```

そして `EAX == 0x12345679` であることを確認します。

再度テストする場合:

```bash
UNICORN_WORK_DIR=/mnt/data/unicorn-kit ./unicorn/python.sh ./unicorn/verify.py
```

自分の Python スクリプトを実行する場合:

```bash
UNICORN_WORK_DIR=/mnt/data/unicorn-kit ./unicorn/python.sh your_script.py
```

## 完全オフライン導入

インストールには以下を使用します。

```text
pip install --no-index --no-deps <local-wheel>
```

そのため、ネットワークが利用できない場合でも PyPI へフォールバックしません。

## ライセンス

このリポジトリ内のスクリプトは MIT License です。Unicorn Engine 本体には Unicorn Engine 側のライセンスが適用されます。
