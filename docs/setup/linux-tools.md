# Debian development / debug / QEMU bundle

Current Drive source: `linux-tools/debian13-amd64-dev-debug-qemu-debs.tar.gz.part000..001`.

```bash
./kit.sh install linux-tools
source /mnt/data/linux-tools-kit/env.sh
```

The bundle is reconstructed, each `.deb` is extracted with `dpkg-deb -x` into a rootless filesystem tree, and the generated environment prepends its binary/library paths. It does not run `apt` or `dpkg -i`.

Default workspace: `/mnt/data/linux-tools-kit`.
