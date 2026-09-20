import 'package:pf_tracker/src/core/domain/calculation_policy.dart';
import 'package:pf_tracker/src/core/domain/pf_calculation_engine.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/core/domain/year_month.dart';

bool includesPFMonth({
  required EmploymentDates employment,
  required YearMonth month,
  required PartialMonthPolicy policy,
}) {
  final isPartialStartMonth =
      YearMonth.fromDate(employment.pfStartDate) == month &&
      employment.pfStartDate.day > 1;
  if (!isPartialStartMonth) {
    return true;
  }
  return switch (policy) {
    PartialMonthPolicy.fullContribution => true,
    PartialMonthPolicy.none => false,
    PartialMonthPolicy.proratedCalendarDays =>
      throw const MissingCalculationInput(
        'Prorated partial-month PF requires an organization-approved formula.',
      ),
  };
}
