import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/l10n/generated/app_localizations.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/features/maturity/presentation/pf_maturity_screen.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

void main() {
  testWidgets('shows the empty maturity state in Bangla', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialPFSetupProvider.overrideWith(
            (ref) async => null,
          ),
          pfRuleHistoryProvider.overrideWith(
            (ref) async => const <StoredPFRule>[],
          ),
        ],
        child: const MaterialApp(
          locale: Locale('bn'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PFMaturityScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PF মেয়াদপূর্তি'), findsOneWidget);
    expect(find.text('প্রথমে PF সেটআপ সম্পন্ন করুন।'), findsOneWidget);
  });
}
