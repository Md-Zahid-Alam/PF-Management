import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pf_tracker/l10n/generated/app_localizations.dart';
import 'package:pf_tracker/src/core/security/security_provider.dart';
import 'package:pf_tracker/src/core/security/security_repository.dart';
import 'package:pf_tracker/src/features/security/presentation/security_screen.dart';

void main() {
  testWidgets('persists the selected auto-lock duration', (tester) async {
    final repository = SecurityRepository(_MemorySecureStore());
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router, repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('autoLockDurationDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 minutes').last);
    await tester.pumpAndSettle();

    expect(
      (await repository.readPreferences()).autoLockDuration,
      AutoLockDuration.fiveMinutes,
    );
  });

  testWidgets('Lock now opens the PIN unlock route', (tester) async {
    final repository = SecurityRepository(_MemorySecureStore());
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router, repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lockNowTile')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unlockDestination')), findsOneWidget);
  });
}

Widget _app(GoRouter router, SecurityRepository repository) {
  return ProviderScope(
    overrides: [
      securityRepositoryProvider.overrideWithValue(repository),
      hasPinProvider.overrideWith((ref) async => true),
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
        builder: (context, state) => const SecurityScreen(),
      ),
      GoRoute(
        path: '/security/change-pin',
        builder: (context, state) => const SizedBox(),
      ),
      GoRoute(
        path: '/security/unlock',
        builder: (context, state) =>
            const SizedBox(key: Key('unlockDestination')),
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
