import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/l10n/generated/app_localizations.dart';
import 'package:pf_tracker/src/features/reports/presentation/exit_estimate_screen.dart';

void main() {
  testWidgets('shows exit estimate labels in Bangla', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exitEstimateProvider.overrideWith(
            (ref, date) => Future.error(StateError('test')),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('bn'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ExitEstimateScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('চাকরি ছাড়ার আনুমানিক হিসাব'), findsOneWidget);
    expect(find.text('প্রত্যাশিত চাকরি ছাড়ার তারিখ'), findsOneWidget);
    expect(
      find.textContaining('আনুমানিক হিসাব পাওয়া যাচ্ছে না'),
      findsOneWidget,
    );
  });
}
