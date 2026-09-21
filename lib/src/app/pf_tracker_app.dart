import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pf_tracker/l10n/generated/app_localizations.dart';
import 'package:pf_tracker/src/app/router.dart';
import 'package:pf_tracker/src/core/domain/app_preferences.dart';
import 'package:pf_tracker/src/core/theme/app_theme.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class PFTrackerApp extends ConsumerStatefulWidget {
  const PFTrackerApp({super.key});

  @override
  ConsumerState<PFTrackerApp> createState() => _PFTrackerAppState();
}

class _PFTrackerAppState extends ConsumerState<PFTrackerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(pfAutomationRunProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(pfAutomationRunProvider);
    final themeMode = ref
        .watch(appThemePreferenceProvider)
        .when(
          data: (preference) => switch (preference) {
            AppThemePreference.system => ThemeMode.system,
            AppThemePreference.light => ThemeMode.light,
            AppThemePreference.dark => ThemeMode.dark,
          },
          loading: () => ThemeMode.system,
          error: (error, stackTrace) => ThemeMode.system,
        );
    final locale = ref
        .watch(appLocalePreferenceProvider)
        .when(
          data: (preference) => Locale(preference.languageCode),
          loading: () => const Locale('bn'),
          error: (error, stackTrace) => const Locale('bn'),
        );
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
    );
  }
}
