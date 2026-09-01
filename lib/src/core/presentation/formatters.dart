import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/domain/money.dart';

String formatMoney(Money money) {
  var divisor = 1;
  for (var index = 0; index < money.decimalPlaces; index++) {
    divisor *= 10;
  }
  return NumberFormat.currency(
    locale: 'en_US',
    symbol: money.currencyCode == 'BDT' ? '৳' : '${money.currencyCode} ',
    decimalDigits: money.decimalPlaces,
  ).format(money.minorUnits / divisor);
}

String formatPFStatus(String status) => switch (status) {
  'automaticallyCalculated' => 'Automatically calculated',
  'manuallyCalculated' => 'Manually calculated',
  'manuallyAdjusted' => 'Manually adjusted',
  'confirmed' => 'Confirmed',
  _ => status,
};
