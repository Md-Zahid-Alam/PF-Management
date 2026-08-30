import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/app/pf_tracker_app.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/repositories.dart';
import 'package:pf_tracker/src/core/domain/setup_models.dart';

void main() {
  testWidgets('opens the first-time setup flow', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialSetupRepositoryProvider.overrideWithValue(
            _EmptySetupRepository(),
          ),
        ],
        child: const PFTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set up PF Tracker'), findsOneWidget);
    expect(find.text('Profile & employment'), findsOneWidget);
    expect(find.byKey(const Key('employeeNameField')), findsOneWidget);
    expect(find.text('Continue'), findsWidgets);
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
