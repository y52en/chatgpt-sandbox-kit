# Video / Remotion / VOICEVOX / PSD

This component restores the video-production stack that was smoke-tested in the ChatGPT Linux sandbox on 2026-08-23.

## Drive assets

Materialize these files from the `Video/` area into `/mnt/data` (folder structure may be preserved):

- `remotion-offline-linux-x64.zip` — Remotion 4.0.515 project + npm cache
- `chrome-headless-shell-linux64-149.0.7790.0.zip` — dedicated Remotion browser
- `voicevox_engine-linux-cpu-x64-0.25.2.7z.001.parts/parts.json` plus every `part-0001` ... `part-0008`
- `7z2602-linux-x64.tar.xz` — extraction helper for VOICEVOX
- `psd_tools-1.18.0-*.whl` and the sibling wheelhouse (optional, for layered PSD artwork)

Do not use the sandbox host `/usr/bin/chromium` for Remotion. The tested host browser was managed with a URL block policy and rejected Remotion's localhost bundle. The dedicated Chrome Headless Shell is therefore an intentional Drive asset.

## Install

```bash
./kit.sh inventory
./kit.sh install video
```

The default workspace is `/mnt/data/video-kit`. `setup.sh` verifies every VOICEVOX split part against `parts.json`, verifies the reconstructed archive SHA-256, normalizes Windows-style path separators in the Remotion ZIP, performs `npm ci --offline`, installs Chrome Headless Shell, extracts VOICEVOX, and optionally creates a psd-tools venv.

## Smoke test

```bash
bash video/smoke-test.sh
```

This first opens a localhost HTTP page with the dedicated Headless Shell—the exact scenario blocked by the managed host Chromium—and then asks Remotion to enumerate compositions. Both checks must succeed.

## Remotion

```bash
bash video/run-remotion.sh compositions
bash video/run-remotion.sh render Demo /mnt/data/out.mp4
```

The wrapper forces `--browser-executable=<dedicated headless shell>` and `--chrome-mode=headless-shell`, overriding a project config that points at the host Chromium.

## VOICEVOX

```bash
bash video/start-voicevox.sh
# API: http://127.0.0.1:50021
```

## PSD artwork

If the psd-tools wheelhouse is materialized, `./kit.sh install video` creates `/mnt/data/video-kit/psd-venv`.

```bash
/mnt/data/video-kit/psd-venv/bin/python video/extract-psd.py character.psd --output-dir /mnt/data/character-layers
```

The helper exports leaf layers as transparent PNGs and writes `layers.json` with names, visibility, bounding boxes, and parent groups. Remotion should consume the PNG/JSON output rather than reading PSD files directly.

## Verified end-to-end

The stack was used to render a 5-minute 1280x720 H.264/AAC video with a layered PSD character, VOICEVOX narration, subtitles, and Remotion. Chrome Headless Shell 149.0.7790.0, Remotion 4.0.515, VOICEVOX Engine 0.25.2, and psd-tools 1.18.0 were all exercised in the sandbox. The repository-side `setup.sh` and `smoke-test.sh` were then re-run against the same Drive-format assets: VOICEVOX part hashes and reconstructed hash matched, offline `npm ci` succeeded, localhost loaded in Headless Shell, and `remotion compositions` succeeded.
