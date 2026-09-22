import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/l10n/generated/app_localizations.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/year_month.dart';
import 'package:pf_tracker/src/features/monthly_records/presentation/monthly_record_adjustment_screen.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

void main() {
  testWidgets('shows PF adjustment labels in Bangla', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime(2026, 9, 1);
    final record = StoredMonthlyPFRecord(
      id: 'record-1',
      employmentId: 'employment-1',
      month: const YearMonth(2026, 8),
      grossSalary: Money.parse('30000'),
      basicSalary: Money.parse('18000'),
      employeeContribution: Money.parse('1800'),
      employerContribution: Money.parse('1800'),
      adjustment: Money.zero(),
      basicRate: Rate.fromPercent('60'),
      employeeRate: Rate.fromPercent('10'),
      employerRate: Rate.fromPercent('10'),
      source: 'automatic',
      status: 'automaticallyCalculated',
      createdAt: now,
      updatedAt: now,
      ruleVersionId: 'rule-1',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthlyPFRecordsProvider.overrideWith((ref) async => [record]),
        ],
        child: const MaterialApp(
          locale: Locale('bn'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MonthlyRecordAdjustmentScreen(recordId: 'record-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PF রেকর্ড সমন্বয়'), findsOneWidget);
    expect(find.text('কর্মীর PF অবদান'), findsOneWidget);
    expect(find.text('সমন্বয় সংরক্ষণ করুন'), findsOneWidget);
  });
}
