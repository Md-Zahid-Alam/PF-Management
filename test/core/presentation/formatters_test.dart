import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/presentation/formatters.dart';

void main() {
  test('formats whole and decimal BDT from minor units', () {
    expect(formatMoney(Money.parse('1800')), '৳1,800');
    expect(formatMoney(Money.parse('1800.50', decimalPlaces: 2)), '৳1,800.50');
  });
}
