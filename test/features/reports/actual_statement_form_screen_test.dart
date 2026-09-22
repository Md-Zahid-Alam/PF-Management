import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/l10n/generated/app_localizations.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/repositories.dart';
import 'package:pf_tracker/src/features/reports/presentation/actual_statement_form_screen.dart';

void main() {
  testWidgets('actual statement rejects a completely empty record', (
    tester,
  ) async {
    final repository = _MemoryActualStatementRepository();
    await tester.pumpWidget(_statementApp(repository: repository));
    await tester.pump();

    final save = find.byKey(const Key('saveActualStatementButton'));
    tester.widget<FilledButton>(save).onPressed!();
    await tester.pump();

    expect(
      find.text('Enter at least one official statement amount.'),
      findsOneWidget,
    );
    expect(repository.saved, isNull);
  });

  testWidgets('shows actual statement labels in Bangla', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_statementApp(locale: const Locale('bn')));
    await tester.pump();

    expect(find.text('প্রকৃত স্টেটমেন্ট 2025–26'), findsOneWidget);
    expect(find.text('প্রারম্ভিক স্থিতি'), findsOneWidget);
    expect(find.text('প্রকৃত স্টেটমেন্ট সংরক্ষণ করুন'), findsOneWidget);
  });
}

Widget _statementApp({
  Locale locale = const Locale('en'),
  _MemoryActualStatementRepository? repository,
}) => ProviderScope(
  overrides: [
    actualPFStatementRepositoryProvider.overrideWithValue(
      repository ?? _MemoryActualStatementRepository(),
    ),
  ],
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const ActualStatementFormScreen(startYear: 2025),
  ),
);

class _MemoryActualStatementRepository implements ActualPFStatementRepository {
  StoredActualPFStatement? saved;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<StoredActualPFStatement>> getForEmployment(
    String employmentId,
  ) async => const <StoredActualPFStatement>[];

  @override
  Future<void> save(StoredActualPFStatement statement) async {
    saved = statement;
  }
}
