import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/repositories.dart';
import 'package:pf_tracker/src/core/notifications/flutter_local_notification_gateway.dart';

final automationNotificationGatewayProvider =
    Provider<AutomationNotificationGateway>((ref) {
      return FlutterLocalNotificationGateway(
        localeRepository: ref.watch(localePreferenceRepositoryProvider),
      );
    });
