enum PartialMonthPolicy { fullContribution, proratedCalendarDays, none }

enum EffectiveVersionPolicy { monthEnd, monthStart, prorated }

enum MaturityBasis { joiningDate, pfStartDate, permanentDate }

enum MoneyRoundingMode { halfUp }

class CalculationPolicy {
  const CalculationPolicy({
    this.partialMonthPolicy = PartialMonthPolicy.fullContribution,
    this.effectiveVersionPolicy = EffectiveVersionPolicy.monthEnd,
    this.decimalPlaces = 0,
    this.roundingMode = MoneyRoundingMode.halfUp,
  });

  final PartialMonthPolicy partialMonthPolicy;
  final EffectiveVersionPolicy effectiveVersionPolicy;
  final int decimalPlaces;
  final MoneyRoundingMode roundingMode;
}
