# Chrome for Testing

Offline setup for locally transferred Linux x64 Chrome for Testing and optional ChromeDriver archives.

```bash
./chrome/setup.sh /mnt/data/chrome-linux64.zip /mnt/data/chromedriver-linux64.zip
source /mnt/data/chrome-kit/env.sh
"$CHROME_BIN" --version
```

The setup validates ZIP integrity, launches Chrome headlessly against a local `data:` URL, and requires an exact Chrome/ChromeDriver version match when the driver is supplied. No network access is used.

Tested in the ChatGPT Linux sandbox with Chrome for Testing / ChromeDriver `152.0.7977.54`.
