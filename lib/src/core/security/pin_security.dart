import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class PinCredential {
  const PinCredential({
    required this.iterations,
    required this.salt,
    required this.verifier,
  });

  static const version = 'v1';

  final int iterations;
  final Uint8List salt;
  final Uint8List verifier;

  String encode() => <String>[
    version,
    iterations.toString(),
    base64UrlEncode(salt),
    base64UrlEncode(verifier),
  ].join(r'$');

  static PinCredential decode(String encoded) {
    final parts = encoded.split(r'$');
    if (parts.length != 4 || parts.first != version) {
      throw const FormatException('Unsupported PIN credential format.');
    }
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations <= 0) {
      throw const FormatException('Invalid PIN credential work factor.');
    }
    try {
      final salt = base64Url.decode(parts[2]);
      final verifier = base64Url.decode(parts[3]);
      if (salt.length < PinSecurityService.saltLength || verifier.isEmpty) {
        throw const FormatException('Invalid PIN credential data.');
      }
      return PinCredential(
        iterations: iterations,
        salt: Uint8List.fromList(salt),
        verifier: Uint8List.fromList(verifier),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid PIN credential encoding.');
    }
  }
}

class PinSecurityService {
  PinSecurityService({this.iterations = 120000, Random? secureRandom})
    : assert(iterations > 0),
      _secureRandom = secureRandom ?? Random.secure();

  static const minimumLength = 4;
  static const maximumLength = 8;
  static const saltLength = 16;
  static const verifierLength = 32;

  final int iterations;
  final Random _secureRandom;

  bool isValidPin(String pin) =>
      RegExp(r'^\d{4,8}$', unicode: true).hasMatch(pin);

  PinCredential createCredential(String pin) {
    _validatePin(pin);
    final salt = Uint8List.fromList(
      List<int>.generate(saltLength, (_) => _secureRandom.nextInt(256)),
    );
    return PinCredential(
      iterations: iterations,
      salt: salt,
      verifier: _derive(pin, salt, iterations),
    );
  }

  bool verify(String pin, PinCredential credential) {
    if (!isValidPin(pin)) {
      return false;
    }
    final candidate = _derive(pin, credential.salt, credential.iterations);
    return _constantTimeEquals(candidate, credential.verifier);
  }

  PinCredential changeCredential({
    required String currentPin,
    required String newPin,
    required PinCredential credential,
  }) {
    if (!verify(currentPin, credential)) {
      throw const PinAuthenticationException();
    }
    return createCredential(newPin);
  }

  void _validatePin(String pin) {
    if (!isValidPin(pin)) {
      throw const FormatException('PIN must contain 4 to 8 digits.');
    }
  }

  static Uint8List _derive(String pin, Uint8List salt, int iterations) {
    final password = utf8.encode(pin);
    final hmac = Hmac(sha256, password);
    final block = Uint8List(salt.length + 4)..setAll(0, salt);
    block.setAll(salt.length, const <int>[0, 0, 0, 1]);

    var current = Uint8List.fromList(hmac.convert(block).bytes);
    final output = Uint8List.fromList(current);
    for (var round = 1; round < iterations; round += 1) {
      current = Uint8List.fromList(hmac.convert(current).bytes);
      for (var index = 0; index < output.length; index += 1) {
        output[index] ^= current[index];
      }
    }
    return Uint8List.sublistView(output, 0, verifierLength);
  }

  static bool _constantTimeEquals(List<int> left, List<int> right) {
    var difference = left.length ^ right.length;
    final length = min(left.length, right.length);
    for (var index = 0; index < length; index += 1) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }
}

class PinAuthenticationException implements Exception {
  const PinAuthenticationException();
}

class PinAttemptGuard {
  const PinAttemptGuard({this.failedAttempts = 0, this.blockedUntil});

  final int failedAttempts;
  final DateTime? blockedUntil;

  bool isBlockedAt(DateTime now) => blockedUntil?.isAfter(now) ?? false;

  Duration remainingAt(DateTime now) {
    final until = blockedUntil;
    if (until == null || !until.isAfter(now)) {
      return Duration.zero;
    }
    return until.difference(now);
  }

  PinAttemptGuard recordFailure(DateTime now) {
    final nextAttempts = failedAttempts + 1;
    final delay = _delayAfter(nextAttempts);
    return PinAttemptGuard(
      failedAttempts: nextAttempts,
      blockedUntil: delay == Duration.zero ? null : now.add(delay),
    );
  }

  PinAttemptGuard reset() => const PinAttemptGuard();

  static Duration _delayAfter(int attempts) {
    if (attempts < 5) {
      return Duration.zero;
    }
    final exponent = min(attempts - 5, 5);
    return Duration(seconds: min(30 * (1 << exponent), 900));
  }
}
