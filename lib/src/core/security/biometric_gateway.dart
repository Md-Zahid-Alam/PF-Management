import 'package:local_auth/local_auth.dart';

abstract interface class BiometricGateway {
  Future<bool> isAvailable();

  Future<bool> authenticate({required String reason});
}

class LocalAuthBiometricGateway implements BiometricGateway {
  LocalAuthBiometricGateway({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  @override
  Future<bool> isAvailable() async {
    try {
      if (!await _authentication.canCheckBiometrics) {
        return false;
      }
      return (await _authentication.getAvailableBiometrics()).isNotEmpty;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _authentication.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on Object {
      return false;
    }
  }
}
