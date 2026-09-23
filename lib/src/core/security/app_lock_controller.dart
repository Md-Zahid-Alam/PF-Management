import 'package:pf_tracker/src/core/security/security_repository.dart';

class AppLockController {
  AppLockController(this._repository);

  final SecurityRepository _repository;
  DateTime? _backgroundedAt;

  void recordBackgrounded(DateTime now) {
    _backgroundedAt ??= now.toUtc();
  }

  Future<bool> shouldLockOnResume(DateTime now) async {
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt == null) {
      return false;
    }
    final preferences = await _repository.readPreferences();
    final duration = preferences.autoLockDuration.duration;
    if (duration == null) {
      return false;
    }
    return !now.toUtc().isBefore(backgroundedAt.add(duration));
  }
}

String safeUnlockDestination(String? requested) {
  if (requested == null || requested.isEmpty) {
    return '/';
  }
  final uri = Uri.tryParse(requested);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !uri.path.startsWith('/') ||
      uri.path.startsWith('/security')) {
    return '/';
  }
  return uri.toString();
}

String unlockLocation(String destination) {
  return Uri(
    path: '/security/unlock',
    queryParameters: <String, String>{
      'destination': safeUnlockDestination(destination),
    },
  ).toString();
}
