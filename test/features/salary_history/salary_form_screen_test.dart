import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
        child: const MaterialApp(home: SalaryFormScreen()),
      ),
    );

    await tester.enterText(find.byKey(const Key('salaryAmountField')), '0');
    await tester.tap(find.byKey(const Key('saveSalaryButton')));
    await tester.pump();

    expect(find.text('Enter a salary greater than zero'), findsOneWidget);
  });
}

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
