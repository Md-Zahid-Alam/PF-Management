import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/repositories.dart';
import 'package:pf_tracker/src/features/profit_history/presentation/profit_form_screen.dart';

void main() {
  testWidgets('profit form rejects a zero amount', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profitRepositoryProvider.overrideWithValue(
            _MemoryProfitRepository(),
          ),
        ],
        child: const MaterialApp(home: ProfitFormScreen()),
      ),
    );

    await tester.enterText(find.byKey(const Key('profitAmountField')), '0');
    await tester.tap(find.byKey(const Key('saveProfitButton')));
    await tester.pump();

    expect(find.text('Enter an amount greater than zero'), findsOneWidget);
  });
}

class _MemoryProfitRepository implements ProfitRepository {
  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<StoredProfitRecord>> getForEmployment(
    String employmentId,
  ) async {
    return <StoredProfitRecord>[];
  }

  @override
  Future<void> save(StoredProfitRecord record) async {}
}
