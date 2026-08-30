import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class SalaryHistoryScreen extends ConsumerWidget {
  const SalaryHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(salaryHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Salary History')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _ErrorState(onRetry: () => ref.invalidate(salaryHistoryProvider)),
        data: (items) => items.isEmpty
            ? const _EmptyState()
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final salary = items[items.length - 1 - index];
                  return _SalaryCard(
                    salary: salary,
                    onEdit: () =>
                        context.push('/salary-history/${salary.id}/edit'),
                    onDelete: () => _confirmDelete(context, ref, salary),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/salary-history/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add salary'),
      ),
    );
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

class _SalaryCard extends StatelessWidget {
  const _SalaryCard({
    required this.salary,
    required this.onEdit,
    required this.onDelete,
  });

  final StoredSalary salary;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
        leading: const CircleAvatar(child: Icon(Icons.payments_outlined)),
        title: Text(
          _formatMoney(salary.grossSalary),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        subtitle: Text(
          'Effective ${DateFormat.yMMMd().format(salary.effectiveFrom)}'
          '${salary.notes == null ? '' : '\n${salary.notes}'}',
        ),
        trailing: PopupMenuButton<String>(
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

String _formatMoney(Money money) {
  return NumberFormat.currency(
    locale: 'en_US',
    symbol: '৳',
    decimalDigits: money.decimalPlaces,
  ).format(money.minorUnits);
}
