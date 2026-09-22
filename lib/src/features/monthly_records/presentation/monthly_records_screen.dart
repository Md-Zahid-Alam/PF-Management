import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class MonthlyRecordsScreen extends ConsumerStatefulWidget {
  const MonthlyRecordsScreen({super.key});

  @override
  ConsumerState<MonthlyRecordsScreen> createState() =>
      _MonthlyRecordsScreenState();
}

class _MonthlyRecordsScreenState extends ConsumerState<MonthlyRecordsScreen> {
  final _search = TextEditingController();
  String? _status;
  int? _year;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(monthlyPFRecordsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.monthlyPFRecords),
        actions: <Widget>[
          IconButton(
            tooltip: context.l10n.salaryHistory,
            onPressed: () => context.push('/salary-history'),
            icon: const Icon(Icons.payments_outlined),
          ),
        ],
      ),
      body: records.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(monthlyPFRecordsProvider),
            icon: const Icon(Icons.refresh),
            label: Text(context.l10n.retryRecords),
          ),
        ),
        data: (items) {
          final years = items.map((item) => item.month.year).toSet().toList()
            ..sort((a, b) => b.compareTo(a));
          final filtered = items.where(_matches).toList()
            ..sort((a, b) => b.month.compareTo(a.month));
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    labelText: context.l10n.searchMonthOrStatus,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() {}),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        initialValue: _year,
                        decoration: InputDecoration(
                          labelText: context.l10n.year,
                        ),
                        items: <DropdownMenuItem<int?>>[
                          DropdownMenuItem(
                            value: null,
                            child: Text(context.l10n.all),
                          ),
                          for (final year in years)
                            DropdownMenuItem(value: year, child: Text('$year')),
                        ],
                        onChanged: (value) => setState(() => _year = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _status,
                        decoration: InputDecoration(
                          labelText: context.l10n.status,
                        ),
                        items: <DropdownMenuItem<String?>>[
                          DropdownMenuItem(
                            value: null,
                            child: Text(context.l10n.all),
                          ),
                          DropdownMenuItem(
                            value: 'automaticallyCalculated',
                            child: Text(context.l10n.automatic),
                          ),
                          DropdownMenuItem(
                            value: 'manuallyCalculated',
                            child: Text(context.l10n.manual),
                          ),
                          DropdownMenuItem(
                            value: 'manuallyAdjusted',
                            child: Text(context.l10n.adjusted),
                          ),
                          DropdownMenuItem(
                            value: 'confirmed',
                            child: Text(context.l10n.confirmed),
                          ),
                        ],
                        onChanged: (value) => setState(() => _status = value),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const _EmptyRecordsState()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) => _RecordCard(
                          record: filtered[index],
                          onOpen: () =>
                              context.push('/records/${filtered[index].id}'),
                          onDelete: () => _confirmDelete(filtered[index]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/records/add'),
        icon: const Icon(Icons.calculate_outlined),
        label: Text(context.l10n.calculateMonth),
      ),
    );
  }

  bool _matches(StoredMonthlyPFRecord record) {
    if (_year != null && record.month.year != _year) {
      return false;
    }
    if (_status != null && record.status != _status) {
      return false;
    }
    final query = _search.text.trim().toLowerCase();
    return query.isEmpty ||
        record.month.toString().contains(query) ||
        record.status.toLowerCase().contains(query);
  }

  Future<void> _confirmDelete(StoredMonthlyPFRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deletePFRecordTitle),
        content: Text(
          context.l10n.deletePFRecordMessage(
            _formatMonth(context, record.month.firstDay),
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
    if (confirmed == true && mounted) {
      await ref.read(monthlyPFRepositoryProvider).delete(record.id);
      ref.invalidate(monthlyPFRecordsProvider);
    }
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.record,
    required this.onOpen,
    required this.onDelete,
  });

  final StoredMonthlyPFRecord record;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final total = record.employeeContribution + record.employerContribution;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _formatMonth(context, record.month.firstDay),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Chip(label: Text(_statusLabel(context, record.status))),
                  IconButton(
                    tooltip: context.l10n.deleteRecord,
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _AmountLine(
                label: context.l10n.employee,
                amount: record.employeeContribution,
              ),
              _AmountLine(
                label: context.l10n.company,
                amount: record.employerContribution,
              ),
              const Divider(),
              _AmountLine(
                label: context.l10n.totalContribution,
                amount: total,
                bold: true,
              ),
              if (record.salaryCreditedDate != null)
                Text(
                  context.l10n.salaryCreditedOn(
                    _formatDate(context, record.salaryCreditedDate!),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({
    required this.label,
    required this.amount,
    this.bold = false,
  });

  final String label;
  final Money amount;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.bold) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: style)),
          Text(_formatMoney(amount), style: style),
        ],
      ),
    );
  }
}

class _EmptyRecordsState extends StatelessWidget {
  const _EmptyRecordsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          context.l10n.noMatchingPFRecords,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

String _statusLabel(BuildContext context, String status) => switch (status) {
  'automaticallyCalculated' => context.l10n.automatic,
  'manuallyCalculated' => context.l10n.manual,
  'manuallyAdjusted' => context.l10n.adjusted,
  'confirmed' => context.l10n.confirmed,
  _ => status,
};

String _formatMonth(BuildContext context, DateTime date) =>
    DateFormat.yMMMM(Localizations.localeOf(context).toLanguageTag())
        .format(date);

String _formatDate(BuildContext context, DateTime date) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
        .format(date);

String _formatMoney(Money money) {
  return NumberFormat.currency(
    locale: 'en_US',
    symbol: '৳',
    decimalDigits: money.decimalPlaces,
  ).format(money.minorUnits);
}
