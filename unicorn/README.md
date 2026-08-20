# Unicorn Engine offline setup

This directory installs the Python bindings for [Unicorn Engine](https://www.unicorn-engine.org/) from a wheel that has already been transferred into the ChatGPT Linux sandbox.

It intentionally does **not** download anything from PyPI or another external host.

## Tested sandbox configuration

The following combination was tested successfully:

- Linux x86-64
- Python 3.13.5
- Unicorn 2.1.4
- wheel: `unicorn-2.1.4-cp37-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl`

The wheel's `cp37-abi3` tag makes it usable by CPython 3.7 and newer, including Python 3.13. The `manylinux_2_17_x86_64` tag targets x86-64 glibc environments compatible with the sandbox.

## Setup

After transferring the wheel into the sandbox, run:

```bash
./unicorn/setup.sh /mnt/data/unicorn-2.1.4-cp37-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl
```

By default the environment is created under `/mnt/data/unicorn-kit/venv` when `/mnt/data` exists. Otherwise it uses `./.tools/unicorn/venv`.

A custom location or interpreter can be selected with:

```bash
./unicorn/setup.sh \
  --work-dir /mnt/data/my-unicorn \
  --python python3 \
  /mnt/data/unicorn-2.1.4-cp37-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl
```

To verify an expected wheel hash as part of setup:

```bash
./unicorn/setup.sh \
  --sha256 9d6e6dea140560de4ebd8446661f7ef84a357d428c14a3ef09dacd306ec8c239 \
  /mnt/data/unicorn-2.1.4-cp37-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl
```

The hash above is the SHA-256 of the exact wheel tested in the ChatGPT sandbox. Verify independently when provenance matters.

## Verify

`setup.sh` automatically runs `verify.py`. It creates a 32-bit x86 Unicorn instance, executes:

```asm
mov eax, 0x12345678
inc eax
```

and asserts that `EAX == 0x12345679`.

Run the smoke test again with:

```bash
UNICORN_WORK_DIR=/mnt/data/unicorn-kit ./unicorn/python.sh ./unicorn/verify.py
```

Or run your own script in the isolated environment:

```bash
UNICORN_WORK_DIR=/mnt/data/unicorn-kit ./unicorn/python.sh your_script.py
```

## Offline behavior

Installation uses:

```text
pip install --no-index --no-deps <local-wheel>
```

so `setup.sh` will not fall back to PyPI if the network is unavailable.

## Third-party license

The scripts in this repository are MIT-licensed. Unicorn Engine itself is third-party software and remains subject to its own license terms.
