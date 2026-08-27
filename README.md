# PF Tracker

Offline-first Provident Fund tracker for Android, built with Flutter and a layered architecture designed for future desktop/iOS and optional synchronization.

## Current phase

Phase 2 foundation: app shell, Material 3 theme, routing, Riverpod dependency scope, Drift/SQLite database bootstrap, calculation-policy types, linting, and test harness.

## Command-line bootstrap and verification

Flutter 3.47.2 stable (Dart 3.13.2) is the pinned development baseline.

```powershell
./tool/bootstrap.ps1
./tool/verify.ps1
```

Android Studio is not required. See [development setup](docs/DEVELOPMENT.md) for command-line prerequisites. The debug APK is produced at `build/app/outputs/flutter-apk/app-debug.apk`.

## Continuous integration

The Android CI workflow installs JDK 17 and Flutter 3.47.2, generates the Android Gradle host, resolves dependencies, generates typed database code, checks formatting, runs static analysis and tests, builds a debug APK, and uploads it as an artifact.

No credentials or signing keys are stored in the repository. See [release preparation](docs/RELEASING.md).

## Structure

- `lib/src/app`: app composition and navigation
- `lib/src/core`: shared theme, database, and domain policy primitives
- `lib/src/features`: feature-oriented presentation/application/domain/data modules
- `test`: unit and widget tests

Business calculations are implemented in Phase 3 and remain independent of Flutter widgets and Drift. Calculation-engine tests will be added alongside that implementation; CI already discovers and runs them automatically.
