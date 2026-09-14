import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class PFRuleHistoryScreen extends ConsumerWidget {
  const PFRuleHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(pfRuleHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('PF Rule History')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(pfRuleHistoryProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry PF rule history'),
          ),
        ),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No PF rule versions yet.'))
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final ascendingIndex = items.length - 1 - index;
                  final rule = items[ascendingIndex];
                  final effectiveTo = ascendingIndex + 1 < items.length
                      ? items[ascendingIndex + 1].rule.effectiveFrom.subtract(
                          const Duration(days: 1),
                        )
                      : null;
                  return _RuleCard(
                    stored: rule,
                    effectiveTo: effectiveTo,
                    isCurrent: ascendingIndex == items.length - 1,
                    onEdit: () => _edit(context, ref, rule),
                    onDuplicate: () => context.push(
                      '/pf-rule-history/add?source=${rule.rule.id}',
                    ),
                    onDelete: () => _delete(context, ref, rule),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/pf-rule-history/add'),
        icon: const Icon(Icons.add),
        label: const Text('New rule version'),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    StoredPFRule rule,
  ) async {
    final records = await ref.read(monthlyPFRecordsProvider.future);
    final used = records.any((record) => record.ruleVersionId == rule.rule.id);
    if (!context.mounted) {
      return;
    }
    if (!used) {
      await context.push('/pf-rule-history/${rule.rule.id}/edit');
      return;
    }
    final createVersion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rule already used'),
        content: const Text(
          'This PF rule has been used for historical calculations. Create a new effective-dated version instead?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create version'),
          ),
        ],
      ),
    );
    if (createVersion == true && context.mounted) {
      await context.push('/pf-rule-history/add?source=${rule.rule.id}');
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    StoredPFRule rule,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete PF rule?'),
        content: Text(
          'Delete the rule effective ${DateFormat.yMMMd().format(rule.rule.effectiveFrom)}? Rules used by monthly records remain protected.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await ref.read(pfRuleRepositoryProvider).deleteUnused(rule.rule.id);
      ref.invalidate(pfRuleHistoryProvider);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This rule is used by a PF record and cannot be deleted.',
            ),
          ),
        );
      }
    }
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.stored,
    required this.effectiveTo,
    required this.isCurrent,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  final StoredPFRule stored;
  final DateTime? effectiveTo;
  final bool isCurrent;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final rule = stored.rule;
    final endLabel = effectiveTo == null
        ? 'Current'
        : 'to ${DateFormat.yMMMd().format(effectiveTo!)}';
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
        leading: CircleAvatar(
          child: Icon(isCurrent ? Icons.verified_outlined : Icons.history),
        ),
        title: Text(
          '${_percent(rule.employeePFRate)} employee · ${_percent(rule.employerPFRate)} employer',
        ),
        subtitle: Text(
          'Effective ${DateFormat.yMMMd().format(rule.effectiveFrom)} $endLabel\n'
          'Basic ${_percent(rule.basicSalaryRate)} · Maturity ${rule.maturityMonths} months from ${_basisLabel(rule.maturityBasis.name)}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEdit();
                return;
              case 'duplicate':
                onDuplicate();
                return;
              case 'delete':
                onDelete();
                return;
            }
          },
          itemBuilder: (context) => const <PopupMenuEntry<String>>[
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(
              value: 'duplicate',
              child: Text('Create new version'),
            ),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

String _percent(Rate rate) {
  final value = rate.partsPerMillion / 10000;
  return '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)}%';
}

String _basisLabel(String name) => switch (name) {
  'pfStartDate' => 'PF start',
  'permanentDate' => 'permanent date',
  _ => 'joining date',
};
