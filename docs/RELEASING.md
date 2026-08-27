# Android release preparation

Debug builds use standard Android debug signing and require no repository secret.

For a future production release, create the upload keystore outside the repository, keep signing values in GitHub Actions encrypted secrets, generate temporary signing configuration during CI, and build with `flutter build appbundle --release`.

Never commit keystores, passwords, properties files, or private credentials. Release signing remains inactive until a production application identity and signing material are approved.
