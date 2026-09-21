import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/app/pf_tracker_app.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/repositories.dart';
import 'package:pf_tracker/src/core/domain/setup_models.dart';
import 'package:pf_tracker/src/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  testWidgets('starts in the guided PF setup flow', (tester) async {
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

    expect(find.text('PF Ledger সেটআপ করুন'), findsOneWidget);
    expect(find.text('প্রোফাইল ও চাকরি'), findsOneWidget);
    expect(
      Localizations.localeOf(tester.element(find.byType(OnboardingScreen))),
      const Locale('bn'),
    );
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
