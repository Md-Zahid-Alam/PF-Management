import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/core/security/pin_security.dart';

void main() {
  group('PinSecurityService', () {
    late PinSecurityService service;

    setUp(() {
      service = PinSecurityService(iterations: 10, secureRandom: Random(42));
    });

    test('stores a derived verifier and verifies the correct PIN', () {
      final credential = service.createCredential('2580');
      final encoded = credential.encode();

      expect(encoded, isNot(contains('2580')));
      expect(service.verify('2580', PinCredential.decode(encoded)), isTrue);
      expect(service.verify('2581', credential), isFalse);
    });

    test('uses a fresh salt when a credential is replaced', () {
      final first = service.createCredential('2580');
      final second = service.changeCredential(
        currentPin: '2580',
        newPin: '3690',
        credential: first,
      );

      expect(second.salt, isNot(orderedEquals(first.salt)));
      expect(service.verify('2580', second), isFalse);
      expect(service.verify('3690', second), isTrue);
    });

    test('rejects invalid PIN formats and an incorrect current PIN', () {
      expect(() => service.createCredential('12ab'), throwsFormatException);
      expect(() => service.createCredential('123'), throwsFormatException);

      final credential = service.createCredential('2580');
      expect(
        () => service.changeCredential(
          currentPin: '0000',
          newPin: '3690',
          credential: credential,
        ),
        throwsA(isA<PinAuthenticationException>()),
      );
    });
  });

  test('wrong-PIN attempts receive escalating capped backoff', () {
    final now = DateTime.utc(2026, 9, 23, 10);
    var guard = const PinAttemptGuard();

    for (var attempt = 0; attempt < 4; attempt += 1) {
      guard = guard.recordFailure(now);
      expect(guard.isBlockedAt(now), isFalse);
    }

    guard = guard.recordFailure(now);
    expect(guard.remainingAt(now), const Duration(seconds: 30));
    guard = guard.recordFailure(now);
    expect(guard.remainingAt(now), const Duration(minutes: 1));

    for (var attempt = 0; attempt < 10; attempt += 1) {
      guard = guard.recordFailure(now);
    }
    expect(guard.remainingAt(now), const Duration(minutes: 15));
    expect(guard.reset().failedAttempts, 0);
  });
}
