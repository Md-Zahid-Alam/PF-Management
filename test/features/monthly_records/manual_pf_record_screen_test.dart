import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/l10n/generated/app_localizations.dart';
import 'package:pf_tracker/src/features/monthly_records/presentation/manual_pf_record_screen.dart';

void main() {
  testWidgets('shows manual PF calculation in Bangla', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('bn'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ManualPFRecordScreen(),
        ),
      ),
    );

    expect(find.text('PF মাসের হিসাব'), findsOneWidget);
    expect(find.text('মাসিক PF রেকর্ড তৈরি করুন'), findsOneWidget);
    expect(find.text('হিসাব করে সংরক্ষণ করুন'), findsOneWidget);
  });
}
