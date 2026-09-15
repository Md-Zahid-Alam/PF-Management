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
  stdout.writeln('Configured generated Android host for local notifications.');
}
