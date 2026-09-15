import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/repositories.dart';
import 'package:pf_tracker/src/features/profit_history/presentation/profit_form_screen.dart';

void main() {
  testWidgets('profit form preserves an explicit zero amount', (tester) async {
    final repository = _MemoryProfitRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profitRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: ProfitFormScreen()),
      ),
    );

    await tester.enterText(find.byKey(const Key('profitAmountField')), '0');
    final saveButton = find.byKey(const Key('saveProfitButton'));
    tester.widget<FilledButton>(saveButton).onPressed!();
    await tester.pump();

    expect(repository.saved?.amount, Money.zero());
    expect(find.text('Profit amount cannot be negative'), findsNothing);
  });
}

class _MemoryProfitRepository implements ProfitRepository {
  StoredProfitRecord? saved;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<StoredProfitRecord>> getForEmployment(String employmentId) async {
    return <StoredProfitRecord>[];
  }

  @override
  Future<void> save(StoredProfitRecord record) async {
    saved = record;
  }
}
