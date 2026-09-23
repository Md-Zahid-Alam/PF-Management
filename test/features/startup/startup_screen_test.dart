import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pf_tracker/l10n/generated/app_localizations.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/repositories.dart';
import 'package:pf_tracker/src/core/domain/setup_models.dart';
import 'package:pf_tracker/src/core/security/security_provider.dart';
import 'package:pf_tracker/src/features/startup/presentation/startup_screen.dart';

void main() {
  testWidgets('requires PIN creation before opening PF data', (tester) async {
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _app(router, _StartupRepository(completed: true), hasPin: false),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('createPinDestination')), findsOneWidget);
  });

  testWidgets('requires unlock before opening incomplete setup', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router, _StartupRepository(completed: false)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unlockToSetupDestination')), findsOneWidget);
  });

  testWidgets('requires unlock before opening dashboard', (tester) async {
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router, _StartupRepository(completed: true)));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('unlockToDashboardDestination')),
      findsOneWidget,
    );
  });

  testWidgets('offers retry when setup status cannot be loaded', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    final repository = _StartupRepository(completed: false, shouldFail: true);

    await tester.pumpWidget(_app(router, repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pfLedgerLogo')), findsOneWidget);
    expect(find.text('Could not open your PF data.'), findsOneWidget);
    repository.shouldFail = false;
    await tester.tap(find.byKey(const Key('retryStartupButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unlockToSetupDestination')), findsOneWidget);
  });
}

Widget _app(
  GoRouter router,
  InitialSetupRepository repository, {
  bool hasPin = true,
}) {
  return ProviderScope(
    overrides: [
      initialSetupRepositoryProvider.overrideWithValue(repository),
      hasPinProvider.overrideWith((ref) async => hasPin),
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
    initialLocation: '/startup',
    routes: <RouteBase>[
      GoRoute(
        path: '/startup',
        builder: (context, state) => const StartupScreen(),
      ),
      GoRoute(
        path: '/setup',
        builder: (context, state) =>
            const SizedBox(key: Key('setupDestination')),
      ),
      GoRoute(
        path: '/security/create-pin',
        builder: (context, state) =>
            const SizedBox(key: Key('createPinDestination')),
      ),
      GoRoute(
        path: '/security/unlock',
        builder: (context, state) {
          final destination = state.uri.queryParameters['destination'];
          return SizedBox(
            key: Key(
              destination == '/setup'
                  ? 'unlockToSetupDestination'
                  : 'unlockToDashboardDestination',
            ),
          );
        },
      ),
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const SizedBox(key: Key('dashboardDestination')),
      ),
    ],
  );
}

class _StartupRepository implements InitialSetupRepository {
  _StartupRepository({required this.completed, this.shouldFail = false});

  final bool completed;
  bool shouldFail;

  @override
  Future<bool> hasCompletedSetup() async {
    if (shouldFail) {
      throw StateError('Setup status unavailable');
    }
    return completed;
  }

  @override
  Future<InitialPFSetup?> load() async => null;

  @override
  Future<void> save(InitialPFSetup setup) async {}
}
