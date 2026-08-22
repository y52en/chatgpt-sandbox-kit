# Python offline wheelhouse

Current Drive source: `python/python313-linux-x86_64-wheelhouse.tar.gz.part000..001`.

```bash
./kit.sh install python
source /mnt/data/python-kit/env.sh
pip install <package-name>
```

The wheelhouse is reconstructed locally, checked as a gzip/tar archive, and used through a venv configured with `PIP_NO_INDEX=1` and `PIP_FIND_LINKS`.

Default workspace: `/mnt/data/python-kit`.
