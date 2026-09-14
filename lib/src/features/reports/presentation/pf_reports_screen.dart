import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/pf_report_service.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

final pfStatementReportsProvider = FutureProvider<List<PFStatementSummary>>((
  ref,
) async {
  final records = await ref.watch(monthlyPFRecordsProvider.future);
  final profits = await ref.watch(profitHistoryProvider.future);
  return const PFReportService().statementSummaries(
    records: records,
    profits: profits,
    configuration: const StatementYearConfiguration(
      startMonth: DateTime.july,
      startDay: 1,
    ),
  );
});

class PFReportsScreen extends ConsumerWidget {
  const PFReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(pfStatementReportsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('PF Reports')),
      body: reports.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(pfStatementReportsProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry reports'),
          ),
        ),
        data: (items) => items.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No PF reports yet. Add or calculate monthly PF records first.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) => _StatementCard(items[index]),
              ),
      ),
    );
  }
}

class _StatementCard extends StatelessWidget {
  const _StatementCard(this.summary);

  final PFStatementSummary summary;

  @override
  Widget build(BuildContext context) {
    final snapshot = summary.snapshot;
    return Card(
      child: ExpansionTile(
        leading: const CircleAvatar(child: Icon(Icons.assessment_outlined)),
        title: Text(
          'Statement ${summary.year.startYear}–${summary.year.endYear.toString().substring(2)}',
        ),
        subtitle: Text(
          '${DateFormat.yMMMd().format(summary.periodStart)} – '
          '${DateFormat.yMMMd().format(summary.periodEnd)} · '
          '${summary.monthCount} months',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        children: <Widget>[
          _AmountRow('Opening balance', snapshot.openingBalance!),
          _AmountRow('Employee contribution', snapshot.employeeContribution!),
          _AmountRow('Employer contribution', snapshot.employerContribution!),
          _AmountRow('Known profit', snapshot.profit!),
          _AmountRow('Adjustments', snapshot.adjustments!),
          const Divider(),
          _AmountRow(
            'Calculated closing balance',
            snapshot.closingBalance!,
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow(this.label, this.amount, {this.bold = false});

  final String label;
  final Money amount;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.bold) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: style)),
          Text(_formatMoney(amount), style: style),
        ],
      ),
    );
  }
}

String _formatMoney(Money money) => NumberFormat.currency(
  locale: 'en_US',
  symbol: money.currencyCode == 'BDT' ? '৳' : '${money.currencyCode} ',
  decimalDigits: money.decimalPlaces,
).format(money.minorUnits / _scale(money.decimalPlaces));

int _scale(int decimalPlaces) {
  var value = 1;
  for (var index = 0; index < decimalPlaces; index++) {
    value *= 10;
  }
  return value;
}
