$ErrorActionPreference = 'Stop'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter is not on PATH. Install Flutter 3.47.2 stable first.'
}

flutter create --platforms=android --org=com.zahidalam --project-name=pf_tracker .
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

dart run tool/configure_android_host.dart
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

dart run build_runner build --delete-conflicting-outputs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Bootstrap complete. Run tool/verify.ps1 next.'
