import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pf_tracker/l10n/generated/app_localizations.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/repositories.dart';
import 'package:pf_tracker/src/core/domain/setup_models.dart';
import 'package:pf_tracker/src/core/security/pin_security.dart';
import 'package:pf_tracker/src/core/security/security_provider.dart';
import 'package:pf_tracker/src/core/security/security_repository.dart';
import 'package:pf_tracker/src/features/security/presentation/create_pin_screen.dart';

void main() {
  testWidgets('creates a derived PIN credential and continues to setup', (
    tester,
  ) async {
    final store = _MemorySecureStore();
    final repository = SecurityRepository(store);
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _app(router: router, locale: const Locale('en'), repository: repository),
    );
    await tester.enterText(find.byKey(const Key('createPinField')), '2580');
    await tester.enterText(find.byKey(const Key('confirmPinField')), '2580');
    await tester.tap(find.byKey(const Key('savePinButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('setupDestination')), findsOneWidget);
    expect(store.values.values.join(), isNot(contains('2580')));
    expect(await repository.hasPin(), isTrue);
  });

  testWidgets('shows mismatch validation in Bangla', (tester) async {
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _app(
        router: router,
        locale: const Locale('bn'),
        repository: SecurityRepository(_MemorySecureStore()),
      ),
    );
    await tester.enterText(find.byKey(const Key('createPinField')), '2580');
    await tester.enterText(find.byKey(const Key('confirmPinField')), '2581');
    await tester.tap(find.byKey(const Key('savePinButton')));
    await tester.pump();

    expect(find.text('PIN দুটি মিলছে না'), findsOneWidget);
  });
}

Widget _app({
  required GoRouter router,
  required Locale locale,
  required SecurityRepository repository,
}) {
  return ProviderScope(
    overrides: [
      securityRepositoryProvider.overrideWithValue(repository),
      initialSetupRepositoryProvider.overrideWithValue(_SetupRepository()),
      pinCredentialFactoryProvider.overrideWithValue((pin) async {
        return PinSecurityService(
          iterations: 10,
          secureRandom: Random(42),
        ).createCredential(pin);
      }),
    ],
    child: MaterialApp.router(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/security/create-pin',
    routes: <RouteBase>[
      GoRoute(
        path: '/security/create-pin',
        builder: (context, state) => const CreatePinScreen(),
      ),
      GoRoute(
        path: '/setup',
        builder: (context, state) =>
            const SizedBox(key: Key('setupDestination')),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const SizedBox(key: Key('dashboardDestination')),
      ),
    ],
  );
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

class _SetupRepository implements InitialSetupRepository {
  @override
  Future<bool> hasCompletedSetup() async => false;

  @override
  Future<InitialPFSetup?> load() async => null;

  @override
  Future<void> save(InitialPFSetup setup) async {}
}
