#!/usr/bin/env bash
set -euo pipefail

dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
flutter build apk --debug
echo 'Verified. APK: build/app/outputs/flutter-apk/app-debug.apk'
