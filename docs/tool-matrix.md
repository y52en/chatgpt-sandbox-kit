# Tool matrix

Setup instructions are centralized in [`setup/`](setup/).

| Component | Offline source | Verification |
|---|---|---|
| Java | Temurin JDK 21, Gradle, Maven | `java -version`; Gradle/Maven version probes |
| .NET | Linux x64 SDK tarball | `dotnet --info` |
| Python | Python 3.13 wheelhouse | tar integrity, wheel discovery, venv/pip probe |
| Linux dev/debug/QEMU | Debian 13 `.deb` bundle | `dpkg-deb -x`; discovered binaries are listed |
| Playwright browsers | browser bundle | archive integrity + browser revision directory discovery |
| Host browser | sandbox-provided Chromium-family browser; not a Drive asset | `./kit.sh doctor` command discovery + browser version probe |
| Video / Remotion | Remotion 4.0.515 offline npm cache + Chrome Headless Shell 149.0.7790.0 | offline `npm ci`, browser version and Remotion composition probe |
| VOICEVOX | Engine 0.25.2 split payload + 7-Zip helper | per-part SHA-256, reconstructed SHA-256, engine extraction/startup |
| PSD artwork | psd-tools 1.18.0 Linux wheelhouse | offline venv install + layered PSD parse/export |
| apktool/JADX | jar + ZIP | `apktool --version`, `jadx --version` |
| Android SDK CLI | command-line tools + Platform Tools | existing `sdkmanager`/adb smoke tests |
| Android Emulator | Platform Tools + Emulator + API 30 image | existing emulator, ADB, ZIP, image/AVD checks |
| Unicorn | wheel | existing x86 emulation test |
| Capstone/Keystone | wheels | existing assemble/disassemble round trip |
| Ghidra/PyGhidra | Ghidra split ZIP | existing ZIP, Java/Python requirements and JVM startup |
| Unity | CLI `.deb` + Editor split archive | existing CLI and Editor batch/headless version checks |
