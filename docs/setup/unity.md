# Unity CLI / Editor

Current Drive sources include `UnityCLI/unity-cli-linux-amd64.deb` and `UnityEditor/2021.3.10f1/Unity-2021.3.10f1-linux.tar.xz.part001..010`.

```bash
./kit.sh install unity
```

The existing installer extracts the CLI package rootlessly, reconstructs the Editor archive when present, validates the xz archive, and runs the Editor batch/headless version probe during full setup.

Default workspace: `/mnt/data/unity-kit`.
