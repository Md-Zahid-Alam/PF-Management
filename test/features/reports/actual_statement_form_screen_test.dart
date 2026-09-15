import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/repositories.dart';
import 'package:pf_tracker/src/features/reports/presentation/actual_statement_form_screen.dart';

void main() {
  testWidgets('actual statement rejects a completely empty record', (
    tester,
  ) async {
    final repository = _MemoryActualStatementRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          actualPFStatementRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: ActualStatementFormScreen(startYear: 2025),
        ),
      ),
    );
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
}

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
