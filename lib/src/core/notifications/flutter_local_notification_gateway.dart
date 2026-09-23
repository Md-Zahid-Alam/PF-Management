import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart';
import 'package:pf_tracker/l10n/generated/app_localizations.dart';
import 'package:pf_tracker/src/core/domain/automation_models.dart';
import 'package:pf_tracker/src/core/domain/repositories.dart';

class FlutterLocalNotificationGateway implements AutomationNotificationGateway {
  FlutterLocalNotificationGateway(
    this._localeRepository, {
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'pf_automation';

  final FlutterLocalNotificationsPlugin _plugin;
  final LocalePreferenceRepository _localeRepository;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  @override
  Future<void> show(AutomationNotification notification) async {
    await initialize();
    final preference = await _localeRepository.get();
    final l10n = lookupAppLocalizations(Locale(preference.languageCode));
    final (title, body) = localizedAutomationNotification(l10n, notification);
    await _plugin.show(
      id: _notificationId(notification),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          l10n.pfAutomationChannel,
          channelDescription: l10n.pfAutomationChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: notification.month?.toString(),
    );
  }

  static int _notificationId(AutomationNotification notification) {
    final month = notification.month;
    final monthPart = month == null ? 0 : month.year * 100 + month.month;
    return monthPart * 10 + notification.type.index;
  }
}

(String, String) localizedAutomationNotification(
  AppLocalizations l10n,
  AutomationNotification notification,
) {
  final month = notification.month?.toString() ?? '';
  return switch (notification.type) {
    AutomationNotificationType.missingSalaryInformation => (
      l10n.salaryInformationRequired,
      l10n.salaryWaitingNotification(month),
    ),
    AutomationNotificationType.calculationDue => (
      l10n.pfCalculationReady,
      l10n.calculationReadyNotification(month),
    ),
    AutomationNotificationType.automaticallyCalculated => (
      l10n.pfCalculated,
      l10n.calculatedNotification(month),
    ),
    AutomationNotificationType.maturityApproaching => (
      l10n.pfMaturity,
      l10n.maturityDate,
    ),
  };
}
