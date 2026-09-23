import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/core/security/app_lock_controller.dart';
import 'package:pf_tracker/src/core/security/security_repository.dart';

void main() {
  group('AppLockController', () {
    test('locks immediately after returning from background', () async {
      final controller = await _controller(AutoLockDuration.immediately);
      final backgroundedAt = DateTime.utc(2026, 9, 23, 10);

      controller.recordBackgrounded(backgroundedAt);

      expect(await controller.shouldLockOnResume(backgroundedAt), isTrue);
    });

    test('waits for the configured duration', () async {
      final controller = await _controller(AutoLockDuration.fiveMinutes);
      final backgroundedAt = DateTime.utc(2026, 9, 23, 10);

      controller.recordBackgrounded(backgroundedAt);
      expect(
        await controller.shouldLockOnResume(
          backgroundedAt.add(const Duration(minutes: 4, seconds: 59)),
        ),
        isFalse,
      );

      controller.recordBackgrounded(backgroundedAt);
      expect(
        await controller.shouldLockOnResume(
          backgroundedAt.add(const Duration(minutes: 5)),
        ),
        isTrue,
      );
    });

    test('never setting does not auto-lock', () async {
      final controller = await _controller(AutoLockDuration.never);
      final backgroundedAt = DateTime.utc(2026, 9, 23, 10);

      controller.recordBackgrounded(backgroundedAt);

      expect(
        await controller.shouldLockOnResume(
          backgroundedAt.add(const Duration(days: 30)),
        ),
        isFalse,
      );
    });
  });

  test(
    'unlock destinations accept internal routes and reject unsafe routes',
    () {
      expect(
        safeUnlockDestination('/records?status=confirmed'),
        '/records?status=confirmed',
      );
      expect(safeUnlockDestination('/security/change-pin'), '/');
      expect(safeUnlockDestination('https://example.com'), '/');
      expect(safeUnlockDestination('//example.com/path'), '/');
    },
  );
}

Future<AppLockController> _controller(AutoLockDuration duration) async {
  final repository = SecurityRepository(_MemorySecureStore());
  await repository.savePreferences(
    SecurityPreferences(autoLockDuration: duration),
  );
  return AppLockController(repository);
}

class _MemorySecureStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
