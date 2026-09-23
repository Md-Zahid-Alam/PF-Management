import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/l10n/generated/app_localizations.dart';
import 'package:pf_tracker/src/core/domain/automation_models.dart';
import 'package:pf_tracker/src/core/domain/year_month.dart';
import 'package:pf_tracker/src/core/notifications/flutter_local_notification_gateway.dart';

void main() {
  test('automation notification text follows the selected locale', () {
    const notification = AutomationNotification(
      type: AutomationNotificationType.calculationDue,
      month: YearMonth(2026, 8),
    );

    final english = localizedAutomationNotification(
      lookupAppLocalizations(const Locale('en')),
      notification,
    );
    final bangla = localizedAutomationNotification(
      lookupAppLocalizations(const Locale('bn')),
      notification,
    );

    expect(english.$1, 'PF calculation ready');
    expect(english.$2, contains('2026-08'));
    expect(bangla.$1, 'PF হিসাব প্রস্তুত');
    expect(bangla.$2, contains('2026-08'));
    expect(bangla, isNot(english));
  });
}
