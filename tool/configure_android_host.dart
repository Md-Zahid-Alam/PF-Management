import 'dart:io';

void main() {
  final gradleFile = File('android/app/build.gradle.kts');
  if (!gradleFile.existsSync()) {
    stderr.writeln(
      'Android host is missing. Run flutter create --platforms=android first.',
    );
    exitCode = 1;
    return;
  }

  var source = gradleFile.readAsStringSync();
  if (!source.contains('isCoreLibraryDesugaringEnabled = true')) {
    final marker = RegExp(r'    compileOptions \{\r?\n');
    if (!marker.hasMatch(source)) {
      stderr.writeln('Unable to find Android compileOptions block.');
      exitCode = 1;
      return;
    }
    source = source.replaceFirstMapped(
      marker,
      (match) =>
          '${match.group(0)}'
          '        isCoreLibraryDesugaringEnabled = true\n',
    );
  }

  source = source.replaceAll(
    'JavaVersion.VERSION_11',
    'JavaVersion.VERSION_17',
  );
  source = source.replaceAll('minSdk = flutter.minSdkVersion', 'minSdk = 24');

  if (!source.contains('coreLibraryDesugaring(')) {
    source =
        '$source\n'
        'dependencies {\n'
        '    coreLibraryDesugaring('
        '"com.android.tools:desugar_jdk_libs:2.1.4"'
        ')\n'
        '}\n';
  }

  final releaseKeystore = Platform.environment['PF_RELEASE_KEYSTORE_PATH'];
  if (releaseKeystore != null && releaseKeystore.isNotEmpty) {
    const signingMarker = '    buildTypes {';
    const debugSigning = 'signingConfig = signingConfigs.getByName("debug")';
    if (!source.contains(signingMarker)) {
      stderr.writeln('Unable to find Android buildTypes block.');
      exitCode = 1;
      return;
    }
    if (!source.contains(debugSigning)) {
      stderr.writeln('Unable to find the generated debug signing assignment.');
      exitCode = 1;
      return;
    }
    if (!source.contains('create("release")')) {
      source = source.replaceFirst(signingMarker, '''    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("PF_RELEASE_KEYSTORE_PATH"))
            storePassword = System.getenv("PF_RELEASE_STORE_PASSWORD")
            keyAlias = System.getenv("PF_RELEASE_KEY_ALIAS")
            keyPassword = System.getenv("PF_RELEASE_KEY_PASSWORD")
        }
    }

$signingMarker''');
    }
    source = source.replaceFirst(
      debugSigning,
      'signingConfig = signingConfigs.getByName("release")',
    );
  }

  gradleFile.writeAsStringSync(source);

  final manifestFile = File('android/app/src/main/AndroidManifest.xml');
  if (!manifestFile.existsSync()) {
    stderr.writeln('Generated Android manifest is missing.');
    exitCode = 1;
    return;
  }
  var manifest = manifestFile.readAsStringSync();
  if (!manifest.contains('android.permission.USE_BIOMETRIC')) {
    manifest = manifest.replaceFirstMapped(
      RegExp(r'<manifest[^>]*>'),
      (match) =>
          '${match.group(0)}\n'
          '    <uses-permission '
          'android:name="android.permission.USE_BIOMETRIC"/>',
    );
  }
  if (manifest.contains(RegExp(r'android:allowBackup="[^"]*"'))) {
    manifest = manifest.replaceFirst(
      RegExp(r'android:allowBackup="[^"]*"'),
      'android:allowBackup="false"',
    );
  } else {
    manifest = manifest.replaceFirst(
      '<application',
      '<application android:allowBackup="false"',
    );
  }
  manifest = manifest.replaceFirst(
    RegExp(r'android:label="[^"]*"'),
    'android:label="PF Ledger"',
  );
  manifestFile.writeAsStringSync(manifest);

  final activityFiles = Directory('android/app/src/main/kotlin')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('MainActivity.kt'));
  if (activityFiles.isEmpty) {
    stderr.writeln('Generated Android MainActivity is missing.');
    exitCode = 1;
    return;
  }
  for (final activityFile in activityFiles) {
    var activity = activityFile.readAsStringSync();
    activity = activity.replaceAll(
      'io.flutter.embedding.android.FlutterActivity',
      'io.flutter.embedding.android.FlutterFragmentActivity',
    );
    activity = activity.replaceAll(
      'MainActivity : FlutterActivity()',
      'MainActivity : FlutterFragmentActivity()',
    );
    activityFile.writeAsStringSync(activity);
  }

  final styleFiles = Directory('android/app/src/main/res')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('styles.xml'));
  for (final styleFile in styleFiles) {
    var styles = styleFile.readAsStringSync();
    styles = styles.replaceAll(
      RegExp(r'@android:style/Theme\.[^"<]*NoTitleBar'),
      'Theme.AppCompat.DayNight.NoActionBar',
    );
    styleFile.writeAsStringSync(styles);
  }
  stdout.writeln('Configured generated Android host for PF Ledger.');
}
