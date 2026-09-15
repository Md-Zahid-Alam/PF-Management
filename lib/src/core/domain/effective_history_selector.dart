import 'package:pf_tracker/src/core/domain/calculation_policy.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/year_month.dart';

class EffectiveHistorySelector {
  const EffectiveHistorySelector._();

  static StoredPFRule? ruleFor(YearMonth month, List<StoredPFRule> history) {
    final monthEndRule = _latestRuleAt(month.lastDay, history);
    if (monthEndRule == null) {
      return null;
    }
    return switch (monthEndRule.effectiveVersionPolicy) {
      EffectiveVersionPolicy.monthEnd => monthEndRule,
      EffectiveVersionPolicy.monthStart => _latestRuleAt(
        month.firstDay,
        history,
      ),
      EffectiveVersionPolicy.prorated => throw UnsupportedError(
        'Prorated effective-version calculations are not supported.',
      ),
    };
  }

  static EffectiveVersionPolicy? policyFor(
    YearMonth month,
    List<StoredPFRule> history,
  ) {
    return _latestRuleAt(month.lastDay, history)?.effectiveVersionPolicy;
  }

  static StoredSalary? salaryFor(
    YearMonth month,
    List<StoredSalary> history,
    EffectiveVersionPolicy policy,
  ) {
    final effectiveDate = switch (policy) {
      EffectiveVersionPolicy.monthEnd => month.lastDay,
      EffectiveVersionPolicy.monthStart => month.firstDay,
      EffectiveVersionPolicy.prorated => throw UnsupportedError(
        'Prorated effective-version calculations are not supported.',
      ),
    };
    StoredSalary? selected;
    for (final salary in history) {
      if (!salary.effectiveFrom.isAfter(effectiveDate) &&
          (selected == null ||
              salary.effectiveFrom.isAfter(selected.effectiveFrom))) {
        selected = salary;
      }
    }
    return selected;
  }

  static StoredPFRule? _latestRuleAt(
    DateTime effectiveDate,
    List<StoredPFRule> history,
  ) {
    StoredPFRule? selected;
    for (final rule in history) {
      if (!rule.rule.effectiveFrom.isAfter(effectiveDate) &&
          (selected == null ||
              rule.rule.effectiveFrom.isAfter(selected.rule.effectiveFrom))) {
        selected = rule;
      }
    }
    return selected;
  }
}
