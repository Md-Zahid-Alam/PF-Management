import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/l10n/generated/app_localizations.dart';
import 'package:pf_tracker/src/core/branding/app_version_provider.dart';
import 'package:pf_tracker/src/core/branding/brand_identity.dart';
import 'package:pf_tracker/src/features/settings/presentation/about_screen.dart';

void main() {
  testWidgets('shows PF Ledger branding and logo', (tester) async {
    await tester.pumpWidget(_aboutApp());
    await tester.pumpAndSettle();

    expect(find.text('About PF Ledger'), findsOneWidget);
    expect(find.text('PF Ledger'), findsOneWidget);
    expect(find.text(BrandIdentity.brandName), findsOneWidget);
    expect(find.text(BrandIdentity.productOwnerName), findsOneWidget);
    expect(find.text('0.1.0 (1)'), findsOneWidget);
    expect(
      find.text('© 2026 Rifat Labs. All rights reserved.'),
      findsOneWidget,
    );
    expect(find.textContaining('PF Tracker'), findsNothing);
    expect(find.byKey(const Key('pfLedgerLogo')), findsOneWidget);
  });

  testWidgets('shows localized identity labels in Bangla dark theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      _aboutApp(locale: const Locale('bn'), brightness: Brightness.dark),
    );
    await tester.pumpAndSettle();

    expect(find.text('ডেভেলপ করেছে'), findsOneWidget);
    expect(find.text('প্রোডাক্ট মালিক'), findsOneWidget);
    expect(find.text('সংস্করণ'), findsOneWidget);
    expect(
      find.text('© 2026 Rifat Labs। সর্বস্বত্ব সংরক্ষিত।'),
      findsOneWidget,
    );
  });
}

Widget _aboutApp({
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
}) {
  return ProviderScope(
    overrides: [
      appVersionProvider.overrideWith(
        (ref) async => const AppVersionInfo(version: '0.1.0', buildNumber: '1'),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      theme: ThemeData(brightness: brightness),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AboutScreen(),
    ),
  );
}
