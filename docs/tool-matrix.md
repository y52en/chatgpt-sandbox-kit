# Tool matrix

| Component | Offline source | Setup entrypoint | Verification |
|---|---|---|---|
| Java | Temurin JDK 21, Gradle, Maven | `./kit.sh install java` | `java -version`; Gradle/Maven version probes |
| .NET | Linux x64 SDK tarball | `./kit.sh install dotnet` | `dotnet --info` |
| Python | Python 3.13 wheelhouse | `./kit.sh install python` | tar integrity, wheel discovery, venv/pip probe |
| Linux dev/debug/QEMU | Debian 13 `.deb` bundle | `./kit.sh install linux-tools` | `dpkg-deb -x`; discovered binaries are listed |
| Playwright browsers | browser bundle | `./kit.sh install playwright` | archive integrity + browser revision directory discovery |
| apktool/JADX | jar + ZIP | `./kit.sh install android-analysis` | `apktool --version`, `jadx --version` |
| Android SDK CLI | command-line tools + Platform Tools | `./kit.sh install android-tools` | existing `sdkmanager`/adb smoke tests |
| Android Emulator | Platform Tools + Emulator + API 30 image | `./kit.sh install android-emulator` | existing emulator, ADB, ZIP, image/AVD checks |
| Chrome | Chrome for Testing + ChromeDriver | `./kit.sh install chrome` | existing headless DOM and exact driver-version checks |
| Unicorn | wheel | `./kit.sh install unicorn` | existing x86 emulation test |
| Capstone/Keystone | wheels | `./kit.sh install capstone-keystone` | existing assemble/disassemble round trip |
| Ghidra/PyGhidra | Ghidra split ZIP | `./kit.sh install ghidra` | existing ZIP, Java/Python requirements and JVM startup |
| Unity | CLI `.deb` + Editor split archive | `./kit.sh install unity` | existing CLI and Editor batch/headless version checks |

`./kit.sh install all` installs in dependency-aware order, beginning with Java and the language/toolchain bundles. It can extract several gigabytes, so installing only the needed component is usually preferable.
