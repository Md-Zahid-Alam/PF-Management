import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/repositories.dart';
import 'package:pf_tracker/src/features/rule_history/presentation/pf_rule_form_screen.dart';

void main() {
  testWidgets('PF rule form rejects a negative percentage', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pfRuleRepositoryProvider.overrideWithValue(_MemoryPFRuleRepository()),
        ],
        child: const MaterialApp(home: PFRuleFormScreen()),
      ),
    );

    await tester.enterText(find.byKey(const Key('basicRateField')), '-1');
    final saveButton = find.byKey(const Key('savePFRuleButton'));
    tester.widget<FilledButton>(saveButton).onPressed!();
    await tester.pump();

    expect(find.text('Percentage cannot be negative'), findsOneWidget);
  });
}

class _MemoryPFRuleRepository implements PFRuleRepository {
  @override
  Future<void> deleteUnused(String id) async {}

  @override
  Future<StoredPFRule?> findApplicable(
    String organizationId,
    DateTime onDate,
  ) async => null;

  @override
  Future<List<StoredPFRule>> getForOrganization(String organizationId) async {
    return <StoredPFRule>[];
  }

  @override
  Future<void> save(StoredPFRule rule) async {}
}
