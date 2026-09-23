import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pf_tracker/l10n/generated/app_localizations.dart';
import 'package:pf_tracker/src/core/security/biometric_gateway.dart';
import 'package:pf_tracker/src/core/security/pin_security.dart';
import 'package:pf_tracker/src/core/security/security_provider.dart';
import 'package:pf_tracker/src/core/security/security_repository.dart';
import 'package:pf_tracker/src/features/security/presentation/unlock_screen.dart';

void main() {
  testWidgets('correct PIN unlocks the requested destination', (tester) async {
    final repository = await _repositoryWithPin('2580');
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router, repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('unlockPinField')), '2580');
    await tester.tap(find.byKey(const Key('unlockButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unlockedDestination')), findsOneWidget);
    expect((await repository.readAttemptGuard()).failedAttempts, 0);
  });

  testWidgets('incorrect PIN is rejected and records the attempt', (
    tester,
  ) async {
    final repository = await _repositoryWithPin('2580');
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router, repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('unlockPinField')), '0000');
    await tester.tap(find.byKey(const Key('unlockButton')));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect PIN. Try again.'), findsOneWidget);
    expect((await repository.readAttemptGuard()).failedAttempts, 1);
    expect(find.byKey(const Key('unlockedDestination')), findsNothing);
  });

  testWidgets('successful biometric authentication unlocks', (tester) async {
    final repository = await _repositoryWithPin('2580');
    await repository.savePreferences(
      const SecurityPreferences(biometricEnabled: true),
    );
    final gateway = _FakeBiometricGateway(result: true);
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router, repository, gateway: gateway));
    await tester.pumpAndSettle();

    expect(gateway.authenticateCalls, 1);
    expect(find.byKey(const Key('unlockedDestination')), findsOneWidget);
  });

  testWidgets('failed biometric authentication keeps PIN fallback', (
    tester,
  ) async {
    final repository = await _repositoryWithPin('2580');
    await repository.savePreferences(
      const SecurityPreferences(biometricEnabled: true),
    );
    final gateway = _FakeBiometricGateway(result: false);
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router, repository, gateway: gateway));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unlockPinField')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('unlockPinField')), '2580');
    await tester.tap(find.byKey(const Key('unlockButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unlockedDestination')), findsOneWidget);
  });
}

Widget _app(
  GoRouter router,
  SecurityRepository repository, {
  BiometricGateway? gateway,
}) {
  return ProviderScope(
    overrides: [
      securityRepositoryProvider.overrideWithValue(repository),
      biometricGatewayProvider.overrideWithValue(
        gateway ?? _FakeBiometricGateway(result: false, available: false),
      ),
      pinVerifierProvider.overrideWithValue((pin, credential) async {
        return PinSecurityService(iterations: 10).verify(pin, credential);
      }),
    ],
    child: MaterialApp.router(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

class _FakeBiometricGateway implements BiometricGateway {
  _FakeBiometricGateway({required this.result, this.available = true});

  final bool result;
  final bool available;
  int authenticateCalls = 0;

  @override
  Future<bool> authenticate({required String reason}) async {
    authenticateCalls += 1;
    return result;
  }

  @override
  Future<bool> isAvailable() async => available;
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/unlock',
    routes: <RouteBase>[
      GoRoute(
        path: '/unlock',
        builder: (context, state) =>
            const UnlockScreen(destination: '/unlocked'),
      ),
      GoRoute(
        path: '/unlocked',
        builder: (context, state) =>
            const SizedBox(key: Key('unlockedDestination')),
      ),
      GoRoute(
        path: '/security/create-pin',
        builder: (context, state) =>
            const SizedBox(key: Key('createPinDestination')),
      ),
    ],
  );
}

Future<SecurityRepository> _repositoryWithPin(String pin) async {
  final repository = SecurityRepository(_MemorySecureStore());
  final credential = PinSecurityService(
    iterations: 10,
    secureRandom: Random(42),
  ).createCredential(pin);
  await repository.saveCredential(credential);
  return repository;
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
