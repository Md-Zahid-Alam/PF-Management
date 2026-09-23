import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pf_tracker/src/core/security/pin_security.dart';
import 'package:pf_tracker/src/core/security/security_repository.dart';

final secureKeyValueStoreProvider = Provider<SecureKeyValueStore>((ref) {
  return FlutterSecureKeyValueStore();
});

final securityRepositoryProvider = Provider<SecurityRepository>((ref) {
  return SecurityRepository(ref.watch(secureKeyValueStoreProvider));
});

final hasPinProvider = FutureProvider<bool>((ref) {
  return ref.watch(securityRepositoryProvider).hasPin();
});

final pinCredentialFactoryProvider =
    Provider<Future<PinCredential> Function(String)>((ref) {
      return (pin) =>
          Isolate.run(() => PinSecurityService().createCredential(pin));
    });
