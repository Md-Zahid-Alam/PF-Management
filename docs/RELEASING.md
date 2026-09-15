# Android release

The regular Android CI workflow builds a debug APK and requires no secrets. Production artifacts are created only by the manually triggered **Android Release** workflow.

## Required GitHub Actions secrets

- `ANDROID_KEYSTORE_BASE64`: Base64-encoded Android upload keystore
- `ANDROID_KEYSTORE_PASSWORD`: Upload-keystore password
- `ANDROID_KEY_ALIAS`: Alias of the upload key
- `ANDROID_KEY_PASSWORD`: Upload-key password

All four values are required for the release workflow. Firebase files, API keys, and other service credentials are not required by the current offline app. Never commit the keystore, passwords, generated Android directory, or signing-property files.

## Create the upload key

Create and securely archive the keystore outside the repository:

```powershell
keytool -genkeypair -v -keystore pf-tracker-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Convert it to Base64 for the GitHub secret:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\secure\pf-tracker-upload.jks")) | Set-Clipboard
```

Add the four values under **GitHub repository → Settings → Secrets and variables → Actions**. Preserve the original keystore and passwords permanently; losing the upload key can prevent future updates.

## Build a signed release

1. Update `version:` in `pubspec.yaml` when appropriate. The part before `+` is the user-visible version; the integer after `+` must increase for each store upload.
2. Push the version change and confirm Android CI passes.
3. Open **Actions → Android Release → Run workflow** on `main`.
4. Download the `pf-tracker-signed-release` artifact after the workflow succeeds.
5. Use the `.aab` for Google Play submission. The `.apk` is available for controlled direct installation and testing.

The workflow creates the Android host and temporary keystore only on the runner, runs formatting, fatal analysis, and all tests again, then produces signed release artifacts. It does not publish automatically.

## Pre-release device checks

- Install and exercise the release APK on a physical Android device.
- Verify onboarding, calculations, history, statements, backup export/restore, deletion confirmation, and notifications.
- Verify dark mode, large text, phone/tablet layouts, and system back navigation.
- Confirm the application ID and store-listing details before the first public upload.
