import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/repositories.dart';
import 'package:pf_tracker/src/core/domain/setup_models.dart';
import 'package:pf_tracker/src/features/startup/presentation/startup_screen.dart';

void main() {
  testWidgets('opens setup when initial setup is incomplete', (tester) async {
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router, _StartupRepository(completed: false)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('setupDestination')), findsOneWidget);
  });

  testWidgets('opens dashboard when initial setup is complete', (tester) async {
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router, _StartupRepository(completed: true)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboardDestination')), findsOneWidget);
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

    expect(find.byKey(const Key('setupDestination')), findsOneWidget);
  });
}

Widget _app(GoRouter router, InitialSetupRepository repository) {
  return ProviderScope(
    overrides: [initialSetupRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(routerConfig: router),
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
