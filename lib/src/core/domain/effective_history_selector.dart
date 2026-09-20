import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/year_month.dart';

class EffectiveHistorySelector {
  const EffectiveHistorySelector._();

  static StoredPFRule? ruleFor(YearMonth month, List<StoredPFRule> history) {
    return _latestRuleAt(month.lastDay, history);
  }

  static StoredSalary? salaryFor(YearMonth month, List<StoredSalary> history) {
    StoredSalary? selected;
    for (final salary in history) {
      if (!salary.effectiveFrom.isAfter(month.lastDay) &&
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
