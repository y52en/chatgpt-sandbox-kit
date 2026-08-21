# Setup guides

All per-tool setup instructions live in this directory.

| Tool | Guide |
| --- | --- |
| Ghidra / PyGhidra | [ghidra.md](ghidra.md) |
| Unicorn | [unicorn.md](unicorn.md) |
| Capstone + Keystone | [capstone-keystone.md](capstone-keystone.md) |
| Chrome / ChromeDriver | [chrome.md](chrome.md) |
| Android command-line tools | [android-tools.md](android-tools.md) |
| Android Emulator / AVD | [android-emulator.md](android-emulator.md) |
| apktool + JADX | [android-analysis.md](android-analysis.md) |
| Unity CLI / Editor | [unity.md](unity.md) |
| Java / Gradle / Maven | [java.md](java.md) |
| .NET SDK | [dotnet.md](dotnet.md) |
| Python wheelhouse | [python.md](python.md) |
| Playwright browsers | [playwright.md](playwright.md) |
| Debian dev/debug/QEMU bundle | [linux-tools.md](linux-tools.md) |

Before installing anything, the recommended sanity check is:

```bash
./kit.sh inventory --strict
./kit.sh doctor
```
