import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/app/pf_tracker_app.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/repositories.dart';
import 'package:pf_tracker/src/core/domain/setup_models.dart';
import 'package:pf_tracker/src/core/security/security_provider.dart';

void main() {
  testWidgets('opens the first-time PIN creation flow', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialSetupRepositoryProvider.overrideWithValue(
            _EmptySetupRepository(),
          ),
          hasPinProvider.overrideWith((ref) async => false),
        ],
        child: const PFTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('অ্যাপের PIN তৈরি করুন'), findsOneWidget);
    expect(find.byKey(const Key('createPinField')), findsOneWidget);
    expect(find.byKey(const Key('confirmPinField')), findsOneWidget);
  });
}

class _EmptySetupRepository implements InitialSetupRepository {
  @override
  Future<bool> hasCompletedSetup() async => false;

  @override
  Future<InitialPFSetup?> load() async => null;

  @override
  Future<void> save(InitialPFSetup setup) async {}
}
