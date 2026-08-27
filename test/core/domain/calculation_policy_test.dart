import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/core/domain/calculation_policy.dart';

void main() {
  group('CalculationPolicy', () {
    test('uses the approved organization defaults', () {
      const policy = CalculationPolicy();

      expect(policy.partialMonthPolicy, PartialMonthPolicy.fullContribution);
      expect(policy.effectiveVersionPolicy, EffectiveVersionPolicy.monthEnd);
      expect(policy.decimalPlaces, 0);
      expect(policy.roundingMode, MoneyRoundingMode.halfUp);
    });

    test('retains configurable future policy choices', () {
      const policy = CalculationPolicy(
        partialMonthPolicy: PartialMonthPolicy.proratedCalendarDays,
        effectiveVersionPolicy: EffectiveVersionPolicy.prorated,
        decimalPlaces: 2,
      );

      expect(
        policy.partialMonthPolicy,
        PartialMonthPolicy.proratedCalendarDays,
      );
      expect(policy.effectiveVersionPolicy, EffectiveVersionPolicy.prorated);
      expect(policy.decimalPlaces, 2);
    });
  });
}
