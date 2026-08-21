# Capstone + Keystone

Current Drive sources are the Capstone 5.0.9 and Keystone Engine 0.9.2 Linux x86_64 wheels under `re/`.

```bash
./kit.sh install capstone-keystone
```

Both wheels are installed with package-index access disabled and verified by a Keystone assemble -> Capstone disassemble round trip.

Default workspace: `/mnt/data/capstone-keystone-kit`.
