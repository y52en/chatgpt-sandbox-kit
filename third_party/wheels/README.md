# Split offline wheels

These files are byte-for-byte split copies of Linux x86_64 wheels used for
offline ChatGPT sandbox setup. Each `.partNNN` file is at most **1,000,000
bytes** (about 976.6 KiB), which is strictly below 1 MiB (1,048,576 bytes).

## Included packages

- Capstone 5.0.9: `capstone-5.0.9-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl`
  - SHA-256: `273fd8d747d2e35c88f91450be51a603ecfaafb00d96d9f315dcb8689c86193e`
  - Source: https://files.pythonhosted.org/packages/d1/39/17747862222bb062e86b501f1f148d5ff589b77908b080d30f7f085cbfb7/capstone-5.0.9-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl
- Keystone Engine 0.9.2: `keystone_engine-0.9.2-py2.py3-none-manylinux1_x86_64.whl`
  - SHA-256: `5a5316a34323620b1bba31dcfe9e4b4ca6f0c030e82fc7a151da7c8fbe81a379`
  - Source: https://files.pythonhosted.org/packages/01/5c/40ffbec589262f49ff7c463d96ff0bfab0fbd98d9d869c370a70853a13fb/keystone_engine-0.9.2-py2.py3-none-manylinux1_x86_64.whl

## Automatic updates

`.github/workflows/update-binary-wheels.yml` checks PyPI weekly and can also be
run manually. It selects the newest stable wheel compatible with CPython 3.13
on Linux x86_64, verifies the SHA-256 published by PyPI, refreshes the split
parts and license notices, reconstructs the wheels, runs an
assemble/disassemble smoke test, and commits only when the vendored artifacts
actually change.

## Reassemble

```bash
cd third_party/wheels
./reassemble.sh
```

`PARTS-SHA256SUMS` verifies each tracked chunk. `SHA256SUMS` verifies the
reconstructed wheels against PyPI metadata.

## Offline install

```bash
python3 -m pip install --no-index --no-deps \
  ./capstone-5.0.9-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl \
  ./keystone_engine-0.9.2-py2.py3-none-manylinux1_x86_64.whl
```

## Licensing

Capstone and the Keystone Python binding are third-party software. Their
redistribution notices are reproduced as `CAPSTONE-LICENSE.txt` and
`KEYSTONE-LICENSE.txt`; those packages are not covered by this repository's
MIT license.
