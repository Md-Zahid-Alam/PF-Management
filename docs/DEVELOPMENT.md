# Development environment

Android Studio is optional. Development and CI use command-line tooling.

## Required tools

- Git
- Flutter 3.47.2 stable (Dart 3.13.2)
- JDK 17
- Android SDK command-line tools, platform tools, and Flutter-selected build tools

Add Flutter `bin` and Android SDK tools to `PATH`, set `ANDROID_HOME`, and run:

```text
flutter doctor --android-licenses
flutter doctor -v
```

## First checkout

Windows:

```powershell
./tool/bootstrap.ps1
./tool/verify.ps1
```

Linux/macOS/CI:

```bash
chmod +x tool/*.sh
./tool/bootstrap.sh
./tool/verify.sh
```

Bootstrap generates the Android Gradle host, configures its Java 17 and core-library desugaring requirements for local notifications, resolves dependencies, and generates Drift sources. Verification checks formatting, analyzes source, runs tests, and builds `build/app/outputs/flutter-apk/app-debug.apk`.

Package and Gradle downloads require internet during initial build setup. The installed version 1 app has no backend and needs no internet.
