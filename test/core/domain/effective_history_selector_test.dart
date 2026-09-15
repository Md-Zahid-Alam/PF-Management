import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/core/domain/calculation_policy.dart';
import 'package:pf_tracker/src/core/domain/effective_history_selector.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/core/domain/year_month.dart';

void main() {
  test('month-start policy keeps mid-month rule and salary for next month', () {
    final rules = <StoredPFRule>[
      _rule('old-rule', DateTime(2025), EffectiveVersionPolicy.monthEnd),
      _rule(
        'new-rule',
        DateTime(2026, 1, 15),
        EffectiveVersionPolicy.monthStart,
      ),
    ];
    final salaries = <StoredSalary>[
      _salary('old-salary', DateTime(2025), '30000'),
      _salary('new-salary', DateTime(2026, 1, 15), '40000'),
    ];

    final januaryRule = EffectiveHistorySelector.ruleFor(
      const YearMonth(2026, 1),
      rules,
    );
    final januarySalary = EffectiveHistorySelector.salaryFor(
      const YearMonth(2026, 1),
      salaries,
      EffectiveHistorySelector.policyFor(const YearMonth(2026, 1), rules)!,
    );
    final februaryRule = EffectiveHistorySelector.ruleFor(
      const YearMonth(2026, 2),
      rules,
    );
    final februarySalary = EffectiveHistorySelector.salaryFor(
      const YearMonth(2026, 2),
      salaries,
      EffectiveHistorySelector.policyFor(const YearMonth(2026, 2), rules)!,
    );

    expect(januaryRule.rule.id, 'old-rule');
    expect(januarySalary!.id, 'old-salary');
    expect(februaryRule.rule.id, 'new-rule');
    expect(februarySalary!.id, 'new-salary');
  });

  test('month-end policy applies mid-month rule and salary immediately', () {
    final rules = <StoredPFRule>[
      _rule('old-rule', DateTime(2025), EffectiveVersionPolicy.monthEnd),
      _rule('new-rule', DateTime(2026, 1, 15), EffectiveVersionPolicy.monthEnd),
    ];
    final salaries = <StoredSalary>[
      _salary('old-salary', DateTime(2025), '30000'),
      _salary('new-salary', DateTime(2026, 1, 15), '40000'),
    ];

    final rule = EffectiveHistorySelector.ruleFor(
      const YearMonth(2026, 1),
      rules,
    );
    final salary = EffectiveHistorySelector.salaryFor(
      const YearMonth(2026, 1),
      salaries,
      EffectiveHistorySelector.policyFor(const YearMonth(2026, 1), rules)!,
    );

    expect(rule.rule.id, 'new-rule');
    expect(salary!.id, 'new-salary');
  });
}

StoredPFRule _rule(
  String id,
  DateTime effectiveFrom,
  EffectiveVersionPolicy policy,
) {
  return StoredPFRule(
    rule: PFRuleVersion(
      id: id,
      effectiveFrom: effectiveFrom,
      basicSalaryRate: Rate.fromPercent('60'),
      employeePFRate: Rate.fromPercent('10'),
      employerPFRate: Rate.fromPercent('10'),
      maturityMonths: 24,
      maturityBasis: MaturityBasis.pfStartDate,
    ),
    organizationId: 'organization-1',
    partialMonthPolicy: PartialMonthPolicy.fullContribution,
    effectiveVersionPolicy: policy,
    createdAt: effectiveFrom,
    updatedAt: effectiveFrom,
  );
}

StoredSalary _salary(String id, DateTime effectiveFrom, String grossSalary) {
  return StoredSalary(
    id: id,
    employmentId: 'employment-1',
    effectiveFrom: effectiveFrom,
    grossSalary: Money.parse(grossSalary),
    createdAt: effectiveFrom,
    updatedAt: effectiveFrom,
  );
}
