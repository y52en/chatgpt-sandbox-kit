#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
cat 'capstone-5.0.9-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl'.part* > 'capstone-5.0.9-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl'
cat 'keystone_engine-0.9.2-py2.py3-none-manylinux1_x86_64.whl'.part* > 'keystone_engine-0.9.2-py2.py3-none-manylinux1_x86_64.whl'
sha256sum --check --strict SHA256SUMS
printf 'Reassembled and verified wheels.\n'
