import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pf_tracker/src/core/domain/automation_models.dart';
import 'package:pf_tracker/src/core/domain/repositories.dart';

class FlutterLocalNotificationGateway implements AutomationNotificationGateway {
  FlutterLocalNotificationGateway({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'pf_automation';
  static const _channelName = 'PF automation';

  final FlutterLocalNotificationsPlugin _plugin;
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
    await _plugin.show(
      id: _notificationId(notification),
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'PF calculation reminders and results',
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
