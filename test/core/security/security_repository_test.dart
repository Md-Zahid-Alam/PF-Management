import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/core/security/pin_security.dart';
import 'package:pf_tracker/src/core/security/security_repository.dart';

void main() {
  late _MemorySecureStore store;
  late SecurityRepository repository;

  setUp(() {
    store = _MemorySecureStore();
    repository = SecurityRepository(store);
  });

  test('stores only an encoded PIN credential in secure storage', () async {
    final service = PinSecurityService(
      iterations: 10,
      secureRandom: Random(42),
    );
    final credential = service.createCredential('2580');

    await repository.saveCredential(credential);

    expect(await repository.hasPin(), isTrue);
    expect(store.values.values.single, isNot(contains('2580')));
    expect(
      service.verify('2580', (await repository.readCredential())!),
      isTrue,
    );
  });

  test('persists lockout state without financial database data', () async {
    final blockedUntil = DateTime.utc(2026, 9, 23, 10, 30);
    await repository.saveAttemptGuard(
      PinAttemptGuard(failedAttempts: 5, blockedUntil: blockedUntil),
    );

    final restored = await repository.readAttemptGuard();

    expect(restored.failedAttempts, 5);
    expect(restored.blockedUntil, blockedUntil);
    await repository.clearAttemptGuard();
    expect((await repository.readAttemptGuard()).failedAttempts, 0);
  });

  test('persists biometric and auto-lock preferences', () async {
    const preferences = SecurityPreferences(
      biometricEnabled: true,
      autoLockDuration: AutoLockDuration.fiveMinutes,
    );

    await repository.savePreferences(preferences);
    final restored = await repository.readPreferences();

    expect(restored.biometricEnabled, isTrue);
    expect(restored.autoLockDuration, AutoLockDuration.fiveMinutes);
  });
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
