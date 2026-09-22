import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/l10n/generated/app_localizations.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';
import 'package:pf_tracker/src/features/reports/presentation/pf_reports_screen.dart';

void main() {
  testWidgets('shows report filters in Bangla', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pfStatementReportsProvider.overrideWith((ref) async => []),
          monthlyPFRecordsProvider.overrideWith((ref) async => []),
          salaryHistoryProvider.overrideWith((ref) async => []),
          profitHistoryProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(
          locale: Locale('bn'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PFReportsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PF রিপোর্ট'), findsOneWidget);
    expect(find.text('রিপোর্টের ধরন'), findsOneWidget);
    expect(find.text('তারিখের সীমা'), findsOneWidget);
  });
}
