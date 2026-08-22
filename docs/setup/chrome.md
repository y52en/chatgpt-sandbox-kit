# Chrome for Testing / ChromeDriver

Current Drive sources: `Chrome/chrome-linux64.zip` and optional `Chrome/chromedriver-linux64.zip`.

```bash
./kit.sh install chrome
```

The existing installer checks archive integrity, runs a real headless DOM smoke test, and requires ChromeDriver to match Chrome exactly when the driver is present.

Default workspace: `/mnt/data/chrome-kit`.
