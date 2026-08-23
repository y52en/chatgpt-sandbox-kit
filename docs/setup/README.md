# Setup guides

All per-tool setup instructions live in this directory.

| Tool | Guide |
| --- | --- |
| Ghidra / PyGhidra | [ghidra.md](ghidra.md) |
| Unicorn | [unicorn.md](unicorn.md) |
| Capstone + Keystone | [capstone-keystone.md](capstone-keystone.md) |
| Android command-line tools | [android-tools.md](android-tools.md) |
| Android Emulator / AVD | [android-emulator.md](android-emulator.md) |
| apktool + JADX | [android-analysis.md](android-analysis.md) |
| Unity CLI / Editor | [unity.md](unity.md) |
| Java / Gradle / Maven | [java.md](java.md) |
| .NET SDK | [dotnet.md](dotnet.md) |
| Python wheelhouse | [python.md](python.md) |
| Playwright browsers | [playwright.md](playwright.md) |
| Remotion / Chrome Headless Shell / VOICEVOX / PSD | [video.md](video.md) |
| Debian dev/debug/QEMU bundle | [linux-tools.md](linux-tools.md) |

For ordinary browser automation, use a Chromium-family browser already provided by the sandbox host when available; `./kit.sh doctor` reports the detected browser. The video component is an exception: Remotion uses a pinned Drive-backed Chrome Headless Shell because the tested host Chromium is managed by a URL block policy that rejects Remotion's localhost bundle. Playwright keeps its separate pinned browser bundle as well.

Before installing anything, the recommended sanity check is:

```bash
./kit.sh inventory --strict
./kit.sh doctor
```
