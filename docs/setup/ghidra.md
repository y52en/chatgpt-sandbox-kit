# Ghidra / PyGhidra

Current Drive source: `re/ghidra_12.1.3_PUBLIC_20260817.zip.part001..003`.

```bash
./kit.sh install java
./kit.sh install ghidra
```

The existing Ghidra installer reconstructs and checks the ZIP, validates Java/Python compatibility, creates an isolated venv, installs the PyGhidra wheels bundled with Ghidra using `--no-index`, and starts PyGhidra as a smoke test.

Default workspace: `/mnt/data/ghidra-kit`.
