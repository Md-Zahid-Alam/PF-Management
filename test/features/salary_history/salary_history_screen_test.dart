import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/core/domain/calculation_policy.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';
import 'package:pf_tracker/src/features/salary_history/presentation/salary_history_screen.dart';

void main() {
  testWidgets('salary history shows the applicable month-end PF rates', (
    tester,
  ) async {
    final now = DateTime(2026);
    final salary = StoredSalary(
      id: 'salary-1',
      employmentId: 'employment-1',
      effectiveFrom: DateTime(2026, 7, 1),
      grossSalary: Money.parse('30000'),
      createdAt: now,
      updatedAt: now,
    );
    final initialRule = _storedRule(
      id: 'rule-1',
      effectiveFrom: DateTime(2026),
      basicRate: '60',
      employeeRate: '10',
      employerRate: '10',
    );
    final midMonthRule = _storedRule(
      id: 'rule-2',
      effectiveFrom: DateTime(2026, 7, 20),
      basicRate: '70',
      employeeRate: '12',
      employerRate: '13',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salaryHistoryProvider.overrideWith(
            (ref) async => <StoredSalary>[salary],
          ),
          pfRuleHistoryProvider.overrideWith(
            (ref) async => <StoredPFRule>[initialRule, midMonthRule],
          ),
        ],
        child: const MaterialApp(home: SalaryHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Basic salary: 70%'), findsOneWidget);
    expect(find.text('Employee PF: 12% · Employer PF: 13%'), findsOneWidget);
    expect(find.text('Rule effective Jul 20, 2026'), findsOneWidget);
  });
}

StoredPFRule _storedRule({
  required String id,
  required DateTime effectiveFrom,
  required String basicRate,
  required String employeeRate,
  required String employerRate,
}) {
  return StoredPFRule(
    rule: PFRuleVersion(
      id: id,
      effectiveFrom: effectiveFrom,
      basicSalaryRate: Rate.fromPercent(basicRate),
      employeePFRate: Rate.fromPercent(employeeRate),
      employerPFRate: Rate.fromPercent(employerRate),
      maturityMonths: 24,
      maturityBasis: MaturityBasis.joiningDate,
    ),
    organizationId: 'organization-1',
    partialMonthPolicy: PartialMonthPolicy.fullContribution,
    effectiveVersionPolicy: EffectiveVersionPolicy.monthEnd,
    createdAt: effectiveFrom,
    updatedAt: effectiveFrom,
  );
}
