import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/l10n/generated/app_localizations.dart';
import 'package:pf_tracker/src/features/monthly_records/presentation/monthly_records_screen.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

void main() {
  testWidgets('shows monthly record filters in Bangla', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [monthlyPFRecordsProvider.overrideWith((ref) async => [])],
        child: const MaterialApp(
          locale: Locale('bn'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MonthlyRecordsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('মাসিক PF রেকর্ড'), findsOneWidget);
    expect(find.text('মাস অথবা অবস্থা খুঁজুন'), findsOneWidget);
    expect(find.text('মাসের হিসাব করুন'), findsOneWidget);
  });
}
