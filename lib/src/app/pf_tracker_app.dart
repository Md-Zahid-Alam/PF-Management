import 'package:flutter/material.dart';
import 'package:pf_tracker/src/app/router.dart';
import 'package:pf_tracker/src/core/theme/app_theme.dart';

class PFTrackerApp extends StatelessWidget {
  const PFTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PF Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
