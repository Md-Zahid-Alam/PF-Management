import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/l10n/generated/app_localizations.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';
import 'package:pf_tracker/src/features/reports/presentation/statement_year_screen.dart';

void main() {
  testWidgets('shows statement year settings in Bangla', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          statementYearDefinitionsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(
          locale: Locale('bn'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatementYearScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('স্টেটমেন্ট বছর'), findsOneWidget);
    expect(find.text('শুরুর মাস'), findsOneWidget);
    expect(find.text('নতুন সংজ্ঞা সংরক্ষণ করুন'), findsOneWidget);
  });
}
