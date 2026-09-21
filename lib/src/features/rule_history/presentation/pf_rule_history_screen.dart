import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class PFRuleHistoryScreen extends ConsumerWidget {
  const PFRuleHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(pfRuleHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.pfRuleHistory)),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(pfRuleHistoryProvider),
            icon: const Icon(Icons.refresh),
            label: Text(context.l10n.retryPFRuleHistory),
          ),
        ),
        data: (items) => items.isEmpty
            ? Center(child: Text(context.l10n.noPFRuleVersions))
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
        label: Text(context.l10n.newRuleVersion),
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
        title: Text(context.l10n.ruleAlreadyUsed),
        content: Text(context.l10n.ruleAlreadyUsedMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.createVersion),
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
        title: Text(context.l10n.deletePFRuleTitle),
        content: Text(
          context.l10n.deletePFRuleMessage(
            _formatDate(context, rule.rule.effectiveFrom),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.ruleInUseError)));
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
        ? context.l10n.current
        : context.l10n.toDate(_formatDate(context, effectiveTo!));
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
        leading: CircleAvatar(
          child: Icon(isCurrent ? Icons.verified_outlined : Icons.history),
        ),
        title: Text(
          context.l10n.ruleContributionRates(
            _percent(rule.employeePFRate),
            _percent(rule.employerPFRate),
          ),
        ),
        subtitle: Text(
          '${context.l10n.ruleEffectiveRange(_formatDate(context, rule.effectiveFrom), endLabel)}\n'
          '${context.l10n.ruleSummary(_percent(rule.basicSalaryRate), rule.maturityMonths, _basisLabel(context, rule.maturityBasis.name))}',
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
          itemBuilder: (context) => <PopupMenuEntry<String>>[
            PopupMenuItem(value: 'edit', child: Text(context.l10n.edit)),
            PopupMenuItem(
              value: 'duplicate',
              child: Text(context.l10n.createNewVersion),
            ),
            PopupMenuItem(value: 'delete', child: Text(context.l10n.delete)),
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

String _basisLabel(BuildContext context, String name) => switch (name) {
  'pfStartDate' => context.l10n.pfStart,
  'permanentDate' => context.l10n.permanentDateLower,
  _ => context.l10n.joiningDateLower,
};

String _formatDate(BuildContext context, DateTime date) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
        .format(date);
