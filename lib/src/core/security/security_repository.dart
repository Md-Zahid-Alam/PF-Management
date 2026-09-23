import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pf_tracker/src/core/security/pin_security.dart';

abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore({FlutterSecureStorage? storage})
    : _storage = storage ?? FlutterSecureStorage(aOptions: AndroidOptions());

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

enum AutoLockDuration {
  immediately(Duration.zero),
  oneMinute(Duration(minutes: 1)),
  fiveMinutes(Duration(minutes: 5)),
  fifteenMinutes(Duration(minutes: 15)),
  never(null);

  const AutoLockDuration(this.duration);

  final Duration? duration;
}

class SecurityPreferences {
  const SecurityPreferences({
    this.biometricEnabled = false,
    this.autoLockDuration = AutoLockDuration.immediately,
  });

  final bool biometricEnabled;
  final AutoLockDuration autoLockDuration;

  SecurityPreferences copyWith({
    bool? biometricEnabled,
    AutoLockDuration? autoLockDuration,
  }) {
    return SecurityPreferences(
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      autoLockDuration: autoLockDuration ?? this.autoLockDuration,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'biometricEnabled': biometricEnabled,
    'autoLockDuration': autoLockDuration.name,
  };

  static SecurityPreferences fromJson(Map<String, Object?> json) {
    final biometricEnabled = json['biometricEnabled'];
    final autoLockName = json['autoLockDuration'];
    if (biometricEnabled is! bool || autoLockName is! String) {
      throw const FormatException('Invalid security preferences.');
    }
    final AutoLockDuration autoLockDuration;
    try {
      autoLockDuration = AutoLockDuration.values.byName(autoLockName);
    } on ArgumentError {
      throw const FormatException('Invalid auto-lock duration.');
    }
    return SecurityPreferences(
      biometricEnabled: biometricEnabled,
      autoLockDuration: autoLockDuration,
    );
  }
}

class SecurityRepository {
  SecurityRepository(this._store);

  static const _credentialKey = 'pf_ledger.pin_credential.v1';
  static const _attemptGuardKey = 'pf_ledger.pin_attempt_guard.v1';
  static const _preferencesKey = 'pf_ledger.security_preferences.v1';

  final SecureKeyValueStore _store;

  Future<bool> hasPin() async => await _store.read(_credentialKey) != null;

  Future<PinCredential?> readCredential() async {
    final encoded = await _store.read(_credentialKey);
    return encoded == null ? null : PinCredential.decode(encoded);
  }

  Future<void> saveCredential(PinCredential credential) =>
      _store.write(_credentialKey, credential.encode());

  Future<PinAttemptGuard> readAttemptGuard() async {
    final encoded = await _store.read(_attemptGuardKey);
    if (encoded == null) {
      return const PinAttemptGuard();
    }
    final json = jsonDecode(encoded);
    if (json is! Map<String, Object?>) {
      throw const FormatException('Invalid PIN attempt state.');
    }
    final failedAttempts = json['failedAttempts'];
    final blockedUntilValue = json['blockedUntil'];
    if (failedAttempts is! int || failedAttempts < 0) {
      throw const FormatException('Invalid PIN attempt count.');
    }
    DateTime? blockedUntil;
    if (blockedUntilValue != null) {
      if (blockedUntilValue is! String) {
        throw const FormatException('Invalid PIN lockout time.');
      }
      blockedUntil = DateTime.tryParse(blockedUntilValue)?.toUtc();
      if (blockedUntil == null) {
        throw const FormatException('Invalid PIN lockout time.');
      }
    }
    return PinAttemptGuard(
      failedAttempts: failedAttempts,
      blockedUntil: blockedUntil,
    );
  }

  Future<void> saveAttemptGuard(PinAttemptGuard guard) {
    return _store.write(
      _attemptGuardKey,
      jsonEncode(<String, Object?>{
        'failedAttempts': guard.failedAttempts,
        'blockedUntil': guard.blockedUntil?.toUtc().toIso8601String(),
      }),
    );
  }

  Future<void> clearAttemptGuard() => _store.delete(_attemptGuardKey);

  Future<SecurityPreferences> readPreferences() async {
    final encoded = await _store.read(_preferencesKey);
    if (encoded == null) {
      return const SecurityPreferences();
    }
    final json = jsonDecode(encoded);
    if (json is! Map<String, Object?>) {
      throw const FormatException('Invalid security preferences.');
    }
    return SecurityPreferences.fromJson(json);
  }

  Future<void> savePreferences(SecurityPreferences preferences) =>
      _store.write(_preferencesKey, jsonEncode(preferences.toJson()));
}
