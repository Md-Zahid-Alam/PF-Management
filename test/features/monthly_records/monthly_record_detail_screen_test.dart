import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/l10n/generated/app_localizations.dart';
import 'package:pf_tracker/src/features/monthly_records/presentation/monthly_record_detail_screen.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

void main() {
  testWidgets('shows PF record loading error in Bangla', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthlyPFRecordsProvider.overrideWith(
            (ref) => Future.error(StateError('test error')),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('bn'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MonthlyRecordDetailScreen(recordId: 'missing'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PF রেকর্ডের বিস্তারিত'), findsOneWidget);
    expect(find.text('এই PF রেকর্ড লোড করা যায়নি।'), findsOneWidget);
  });
}
