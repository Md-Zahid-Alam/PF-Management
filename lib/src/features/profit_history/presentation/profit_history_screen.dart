import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/presentation/formatters.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class ProfitHistoryScreen extends ConsumerWidget {
  const ProfitHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(profitHistoryProvider);
    final setup = ref.watch(initialPFSetupProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profit History')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(profitHistoryProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry profit history'),
          ),
        ),
        data: (items) => items.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No profit entries yet. Add profit when it is credited to your PF account.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  _ProfitSummary(items: items),
                  const SizedBox(height: 16),
                  for (final profit in items.reversed) ...<Widget>[
                    _ProfitCard(
                      profit: profit,
                      onEdit: () =>
                          context.push('/profit-history/${profit.id}/edit'),
                      onDelete: () => _delete(context, ref, profit),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final currency =
              setup.asData?.value?.salary.grossSalary.currencyCode ?? 'BDT';
          context.push('/profit-history/add?currency=$currency');
        },
        icon: const Icon(Icons.add),
        label: const Text('Add profit'),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    StoredProfitRecord profit,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete profit entry?'),
        content: Text(
          'Delete the profit credited ${DateFormat.yMMMd().format(profit.creditedDate)}?',
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
    if (confirmed != true) {
      return;
    }
    await ref.read(profitRepositoryProvider).delete(profit.id);
    ref.invalidate(profitHistoryProvider);
  }
}

class _ProfitSummary extends StatelessWidget {
  const _ProfitSummary({required this.items});

  final List<StoredProfitRecord> items;

  @override
  Widget build(BuildContext context) {
    final totals = <int, Money>{};
    for (final item in items) {
      final zero = Money.zero(
        decimalPlaces: item.amount.decimalPlaces,
        currencyCode: item.amount.currencyCode,
      );
      totals[item.creditedDate.year] =
          (totals[item.creditedDate.year] ?? zero) + item.amount;
    }
    final years = totals.keys.toList()..sort((a, b) => b.compareTo(a));
    var grandTotal = Money.zero(
      decimalPlaces: items.first.amount.decimalPlaces,
      currencyCode: items.first.amount.currencyCode,
    );
    for (final item in items) {
      grandTotal += item.amount;
    }
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'TOTAL KNOWN PROFIT',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Text(
              formatMoney(grandTotal),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Divider(height: 28),
            for (final year in years)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text('$year')),
                    Text(formatMoney(totals[year]!)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfitCard extends StatelessWidget {
  const _ProfitCard({
    required this.profit,
    required this.onEdit,
    required this.onDelete,
  });

  final StoredProfitRecord profit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final period = profit.periodStart == null || profit.periodEnd == null
        ? null
        : '${DateFormat.yMMMd().format(profit.periodStart!)} – ${DateFormat.yMMMd().format(profit.periodEnd!)}';
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
        leading: const CircleAvatar(child: Icon(Icons.trending_up)),
        title: Text(
          formatMoney(profit.amount),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        subtitle: Text(
          'Credited ${DateFormat.yMMMd().format(profit.creditedDate)}'
          '${period == null ? '' : '\nPeriod: $period'}'
          '${profit.notes == null ? '' : '\n${profit.notes}'}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
          itemBuilder: (context) => const <PopupMenuEntry<String>>[
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}
