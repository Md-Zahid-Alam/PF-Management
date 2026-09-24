import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/l10n/generated/app_localizations.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/repositories.dart';
import 'package:pf_tracker/src/core/domain/setup_models.dart';
import 'package:pf_tracker/src/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  testWidgets('organization settings opens the organization step', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialSetupRepositoryProvider.overrideWithValue(
            _EmptySetupRepository(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OnboardingScreen(editExisting: true, initialStep: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final stepper = tester.widget<Stepper>(find.byType(Stepper));
    expect(stepper.currentStep, 1);
    expect(find.byKey(const Key('organizationNameField')), findsOneWidget);
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
