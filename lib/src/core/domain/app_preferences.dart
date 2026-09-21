enum AppThemePreference { system, light, dark }

enum AppLocalePreference {
  bangla('bn'),
  english('en');

  const AppLocalePreference(this.languageCode);

  final String languageCode;
}
