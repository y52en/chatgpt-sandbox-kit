# Playwright browser bundle

Current Drive source: `playwright/playwright-linux-browsers-bundle.tar.gz.part000..002`.

```bash
./kit.sh install playwright
source /mnt/data/playwright-kit/env.sh
```

The browser bundle is reconstructed and extracted locally. The generated `env.sh` exports `PLAYWRIGHT_BROWSERS_PATH`; no browser download is performed.

Default workspace: `/mnt/data/playwright-kit`.
