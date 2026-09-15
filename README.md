# PF Tracker

Offline-first Provident Fund tracker for Android, built with Flutter and a layered architecture designed for future desktop/iOS and optional synchronization.

## Current status

Implementation and automated QA phases are complete. The app includes onboarding, effective-dated salary and PF rules, monthly calculations and automation, audited adjustments, profit history, statement reconciliation, reports, exit estimates, and native backup/restore. Release signing remains an operator-controlled GitHub Actions step.

## Command-line bootstrap and verification

Flutter 3.47.2 stable (Dart 3.13.2) is the pinned development baseline.

```powershell
./tool/bootstrap.ps1
./tool/verify.ps1
```

Android Studio is not required. See [development setup](docs/DEVELOPMENT.md) for command-line prerequisites. The debug APK is produced at `build/app/outputs/flutter-apk/app-debug.apk`.

## Continuous integration

The Android CI workflow installs JDK 17 and Flutter 3.47.2, generates the Android Gradle host, resolves dependencies, generates typed database code, checks formatting, runs static analysis and tests, builds a debug APK, and uploads it as an artifact.

No credentials or signing keys are stored in the repository. See [release instructions](docs/RELEASING.md).

## Structure

- `lib/src/app`: app composition and navigation
- `lib/src/core`: shared theme, database, and domain policy primitives
- `lib/src/features`: feature-oriented presentation/application/domain/data modules
- `test`: unit and widget tests

Business calculations are independent of Flutter widgets and Drift. See the [calculation-engine contract](docs/CALCULATION_ENGINE.md).

Persistence is isolated behind domain repositories. See the [database architecture](docs/DATABASE.md).

Local automation runs when the application invokes the automation service; it does not require a server or internet connection. See the [automation contract](docs/AUTOMATION.md).
