$ErrorActionPreference = 'Stop'

dart format --output=none --set-exit-if-changed lib test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

flutter analyze --fatal-infos
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

flutter test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

flutter build apk --debug
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Verified. APK: build/app/outputs/flutter-apk/app-debug.apk'
