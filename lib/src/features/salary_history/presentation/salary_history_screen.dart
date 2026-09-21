import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/effective_history_selector.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/year_month.dart';
import 'package:pf_tracker/src/core/presentation/formatters.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class SalaryHistoryScreen extends ConsumerWidget {
  const SalaryHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(salaryHistoryProvider);
    final rules = ref.watch(pfRuleHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Salary History')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorState(onRetry: () => _retry(ref)),
        data: (items) => rules.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _ErrorState(onRetry: () => _retry(ref)),
          data: (ruleHistory) => items.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final ascendingIndex = items.length - 1 - index;
                    final salary = items[ascendingIndex];
                    final nextSalaryDate = ascendingIndex + 1 < items.length
                        ? items[ascendingIndex + 1].effectiveFrom
                        : null;
                    final rule = _ruleForSalaryPeriod(
                      salary: salary,
                      nextSalaryDate: nextSalaryDate,
                      rules: ruleHistory,
                    );
                    return _SalaryCard(
                      salary: salary,
                      applicableRule: rule,
                      onEdit: () =>
                          context.push('/salary-history/${salary.id}/edit'),
                      onDelete: () => _confirmDelete(context, ref, salary),
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final currency =
              history.asData?.value.firstOrNull?.grossSalary.currencyCode ??
              'BDT';
          context.push('/salary-history/add?currency=$currency');
        },
        icon: const Icon(Icons.add),
        label: const Text('Add salary'),
      ),
    );
  }

  void _retry(WidgetRef ref) {
    ref
      ..invalidate(salaryHistoryProvider)
      ..invalidate(pfRuleHistoryProvider);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    StoredSalary salary,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete salary history?'),
        content: Text(
          'Delete the salary effective ${DateFormat.yMMMd().format(salary.effectiveFrom)}? Existing PF records remain unchanged.',
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
      await ref.read(salaryRepositoryProvider).delete(salary.id);
      ref.invalidate(salaryHistoryProvider);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This salary is used by a PF record and cannot be deleted.',
            ),
          ),
        );
      }
    }
  }
}

StoredPFRule? _ruleForSalaryPeriod({
  required StoredSalary salary,
  required DateTime? nextSalaryDate,
  required List<StoredPFRule> rules,
}) {
  final ruleAtSalaryStart = EffectiveHistorySelector.ruleFor(
    YearMonth.fromDate(salary.effectiveFrom),
    rules,
  );
  if (ruleAtSalaryStart != null) {
    return ruleAtSalaryStart;
  }

  StoredPFRule? firstRuleDuringSalary;
  for (final rule in rules) {
    final effectiveFrom = rule.rule.effectiveFrom;
    final startsBeforeNextSalary =
        nextSalaryDate == null || effectiveFrom.isBefore(nextSalaryDate);
    if (!effectiveFrom.isBefore(salary.effectiveFrom) &&
        startsBeforeNextSalary &&
        (firstRuleDuringSalary == null ||
            effectiveFrom.isBefore(firstRuleDuringSalary.rule.effectiveFrom))) {
      firstRuleDuringSalary = rule;
    }
  }
  return firstRuleDuringSalary;
}

class _SalaryCard extends StatelessWidget {
  const _SalaryCard({
    required this.salary,
    required this.applicableRule,
    required this.onEdit,
    required this.onDelete,
  });

  final StoredSalary salary;
  final StoredPFRule? applicableRule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final rule = applicableRule?.rule;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const CircleAvatar(child: Icon(Icons.payments_outlined)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    formatMoney(salary.grossSalary),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Effective ${DateFormat.yMMMd().format(salary.effectiveFrom)}',
                  ),
                  const SizedBox(height: 8),
                  if (rule == null)
                    const Text('No applicable PF rule for this period')
                  else ...<Widget>[
                    Text('Basic salary: ${_percent(rule.basicSalaryRate)}'),
                    Text(
                      'Employee PF: ${_percent(rule.employeePFRate)} · '
                      'Employer PF: ${_percent(rule.employerPFRate)}',
                    ),
                    Text(
                      'Rule effective ${DateFormat.yMMMd().format(rule.effectiveFrom)}',
                    ),
                  ],
                  if (salary.notes != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(salary.notes!),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else {
                  onDelete();
                }
              },
              itemBuilder: (context) => const <PopupMenuEntry<String>>[
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No salary history yet. Add a salary with its effective date.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Retry salary history'),
      ),
    );
  }
}

String _percent(Rate rate) {
  final value = rate.partsPerMillion / 10000;
  return '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)}%';
}
