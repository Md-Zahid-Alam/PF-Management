import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/l10n/generated/app_localizations.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/repositories.dart';
import 'package:pf_tracker/src/features/salary_history/presentation/salary_form_screen.dart';

void main() {
  testWidgets('salary form rejects a zero gross salary', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salaryRepositoryProvider.overrideWithValue(_MemorySalaryRepository()),
        ],
        child: _salaryFormApp(),
      ),
    );

    await tester.enterText(find.byKey(const Key('salaryAmountField')), '0');
    await tester.tap(find.byKey(const Key('saveSalaryButton')));
    await tester.pump();

    expect(find.text('Enter a salary greater than zero'), findsOneWidget);
  });

  testWidgets('shows salary form labels in Bangla', (tester) async {
    await tester.pumpWidget(_salaryFormApp(locale: const Locale('bn')));

    expect(find.text('বেতন যোগ করুন'), findsOneWidget);
    expect(find.text('মোট বেতন'), findsOneWidget);
    expect(find.text('কার্যকর তারিখ'), findsOneWidget);
    expect(find.text('বেতন সংরক্ষণ করুন'), findsOneWidget);
  });
}

Widget _salaryFormApp({Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const SalaryFormScreen(),
);

class _MemorySalaryRepository implements SalaryRepository {
  @override
  Future<void> delete(String id) async {}

  @override
  Future<StoredSalary?> findApplicable(
    String employmentId,
    DateTime onDate,
  ) async => null;

  @override
  Future<List<StoredSalary>> getForEmployment(String employmentId) async {
    return <StoredSalary>[];
  }

  @override
  Future<void> save(StoredSalary salary) async {}
}
