# Tool matrix

Setup instructions are centralized in [`setup/`](setup/).

| Component | Offline source | Verification |
|---|---|---|
| Java | Temurin JDK 21, Gradle, Maven | `java -version`; Gradle/Maven version probes |
| .NET | Linux x64 SDK tarball | `dotnet --info` |
| Python | Python 3.13 wheelhouse | tar integrity, wheel discovery, venv/pip probe |
| Linux dev/debug/QEMU | Debian 13 `.deb` bundle | `dpkg-deb -x`; discovered binaries are listed |
| Playwright browsers | browser bundle | archive integrity + browser revision directory discovery |
| apktool/JADX | jar + ZIP | `apktool --version`, `jadx --version` |
| Android SDK CLI | command-line tools + Platform Tools | existing `sdkmanager`/adb smoke tests |
| Android Emulator | Platform Tools + Emulator + API 30 image | existing emulator, ADB, ZIP, image/AVD checks |
| Chrome | Chrome for Testing + ChromeDriver | existing headless DOM and exact driver-version checks |
| Unicorn | wheel | existing x86 emulation test |
| Capstone/Keystone | wheels | existing assemble/disassemble round trip |
| Ghidra/PyGhidra | Ghidra split ZIP | existing ZIP, Java/Python requirements and JVM startup |
| Unity | CLI `.deb` + Editor split archive | existing CLI and Editor batch/headless version checks |
