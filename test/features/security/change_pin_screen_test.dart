import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pf_tracker/l10n/generated/app_localizations.dart';
import 'package:pf_tracker/src/core/security/pin_security.dart';
import 'package:pf_tracker/src/core/security/security_provider.dart';
import 'package:pf_tracker/src/core/security/security_repository.dart';
import 'package:pf_tracker/src/features/security/presentation/change_pin_screen.dart';

void main() {
  testWidgets('requires the correct current PIN', (tester) async {
    final repository = await _repositoryWithPin('2580');
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router, repository));
    await _openChangePin(tester);
    await _enterPins(tester, current: '0000', replacement: '3690');
    await tester.tap(find.byKey(const Key('changePinButton')));
    await tester.pumpAndSettle();

    expect(find.text('The current PIN is incorrect'), findsOneWidget);
    final credential = (await repository.readCredential())!;
    expect(
      PinSecurityService(iterations: 10).verify('2580', credential),
      isTrue,
    );
  });

  testWidgets('changes the verifier without touching financial data', (
    tester,
  ) async {
    final repository = await _repositoryWithPin('2580');
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router, repository));
    await _openChangePin(tester);
    await _enterPins(tester, current: '2580', replacement: '3690');
    await tester.tap(find.byKey(const Key('changePinButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('securityDestination')), findsOneWidget);
    final credential = (await repository.readCredential())!;
    final service = PinSecurityService(iterations: 10);
    expect(service.verify('2580', credential), isFalse);
    expect(service.verify('3690', credential), isTrue);
  });
}

Widget _app(GoRouter router, SecurityRepository repository) {
  return ProviderScope(
    overrides: [
      securityRepositoryProvider.overrideWithValue(repository),
      pinVerifierProvider.overrideWithValue((pin, credential) async {
        return PinSecurityService(iterations: 10).verify(pin, credential);
      }),
      pinCredentialFactoryProvider.overrideWithValue((pin) async {
        return PinSecurityService(
          iterations: 10,
          secureRandom: Random(84),
        ).createCredential(pin);
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

GoRouter _router() {
  return GoRouter(
    initialLocation: '/security',
    routes: <RouteBase>[
      GoRoute(
        path: '/security',
        builder: (context, state) => Scaffold(
          key: const Key('securityDestination'),
          body: FilledButton(
            key: const Key('openChangePinButton'),
            onPressed: () => context.push('/security/change-pin'),
            child: const Text('Open'),
          ),
        ),
      ),
      GoRoute(
        path: '/security/change-pin',
        builder: (context, state) => const ChangePinScreen(),
      ),
      GoRoute(
        path: '/security/create-pin',
        builder: (context, state) =>
            const SizedBox(key: Key('createPinDestination')),
      ),
    ],
  );
}

Future<void> _openChangePin(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('openChangePinButton')));
  await tester.pumpAndSettle();
}

Future<void> _enterPins(
  WidgetTester tester, {
  required String current,
  required String replacement,
}) async {
  await tester.enterText(find.byKey(const Key('currentPinField')), current);
  await tester.enterText(find.byKey(const Key('newPinField')), replacement);
  await tester.enterText(
    find.byKey(const Key('confirmNewPinField')),
    replacement,
  );
}

Future<SecurityRepository> _repositoryWithPin(String pin) async {
  final repository = SecurityRepository(_MemorySecureStore());
  await repository.saveCredential(
    PinSecurityService(
      iterations: 10,
      secureRandom: Random(42),
    ).createCredential(pin),
  );
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
