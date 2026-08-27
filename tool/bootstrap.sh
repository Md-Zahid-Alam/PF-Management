#!/usr/bin/env bash
set -euo pipefail

command -v flutter >/dev/null || {
  echo 'Flutter is not on PATH. Install Flutter 3.47.2 stable first.' >&2
  exit 1
}

flutter create --platforms=android --org=com.zahidalam --project-name=pf_tracker .
flutter pub get
dart run build_runner build --delete-conflicting-outputs
echo 'Bootstrap complete. Run tool/verify.sh next.'
