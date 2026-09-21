import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/presentation/formatters.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class ProfitHistoryScreen extends ConsumerWidget {
  const ProfitHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(profitHistoryProvider);
    final setup = ref.watch(initialPFSetupProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.profitHistory)),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(profitHistoryProvider),
            icon: const Icon(Icons.refresh),
            label: Text(context.l10n.retryProfitHistory),
          ),
        ),
        data: (items) => items.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    context.l10n.noProfitEntries,
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
        label: Text(context.l10n.addProfit),
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
        title: Text(context.l10n.deleteProfitEntryTitle),
        content: Text(
          context.l10n.deleteProfitEntryMessage(
            _formatDate(context, profit.creditedDate),
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
              context.l10n.totalKnownProfit,
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
        : '${_formatDate(context, profit.periodStart!)} – ${_formatDate(context, profit.periodEnd!)}';
    final details = <String>[
      context.l10n.creditedOn(_formatDate(context, profit.creditedDate)),
      if (period != null) context.l10n.profitPeriod(period),
      if (profit.notes != null) profit.notes!,
    ];
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
        leading: const CircleAvatar(child: Icon(Icons.trending_up)),
        title: Text(
          formatMoney(profit.amount),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        subtitle: Text(details.join('\n')),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
          itemBuilder: (context) => <PopupMenuEntry<String>>[
            PopupMenuItem(value: 'edit', child: Text(context.l10n.edit)),
            PopupMenuItem(value: 'delete', child: Text(context.l10n.delete)),
          ],
        ),
      ),
    );
  }
}

String _formatDate(BuildContext context, DateTime date) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
        .format(date);
