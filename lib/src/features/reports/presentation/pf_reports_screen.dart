import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/pf_calculation_engine.dart';
import 'package:pf_tracker/src/core/domain/pf_report_service.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class PFStatementReportView {
  const PFStatementReportView({
    required this.summary,
    required this.actual,
    required this.comparison,
  });

  final PFStatementSummary summary;
  final StoredActualPFStatement? actual;
  final StatementComparison? comparison;
}

final pfStatementReportsProvider = FutureProvider<List<PFStatementReportView>>((
  ref,
) async {
  final records = await ref.watch(monthlyPFRecordsProvider.future);
  final profits = await ref.watch(profitHistoryProvider.future);
  final actualStatements = await ref.watch(actualPFStatementsProvider.future);
  final definitions = await ref.watch(statementYearDefinitionsProvider.future);
  final configuration = _currentConfiguration(definitions, DateTime.now());
  final summaries = const PFReportService().statementSummaries(
    records: records,
    profits: profits,
    configuration: configuration,
  );
  const engine = PFCalculationEngine();
  return <PFStatementReportView>[
    for (final summary in summaries)
      PFStatementReportView(
        summary: summary,
        actual: _actualFor(actualStatements, summary.year.startYear),
        comparison: _actualFor(actualStatements, summary.year.startYear) == null
            ? null
            : engine.reconcileStatement(
                calculated: summary.snapshot,
                actual: _actualFor(
                  actualStatements,
                  summary.year.startYear,
                )!.snapshot,
              ),
      ),
  ];
});

class PFReportsScreen extends ConsumerWidget {
  const PFReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(pfStatementReportsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('PF Reports'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Exit estimate',
            onPressed: () => context.push('/reports/exit-estimate'),
            icon: const Icon(Icons.directions_walk_outlined),
          ),
          IconButton(
            tooltip: 'Statement year settings',
            onPressed: () => context.push('/reports/statement-year'),
            icon: const Icon(Icons.date_range_outlined),
          ),
        ],
      ),
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
  const _StatementCard(this.report);

  final PFStatementReportView report;

  @override
  Widget build(BuildContext context) {
    final summary = report.summary;
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
          if (snapshot.profit == null)
            const ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('Known profit'),
              trailing: Text('Not entered'),
            )
          else
            _AmountRow('Known profit', snapshot.profit!),
          _AmountRow('Adjustments', snapshot.adjustments!),
          const Divider(),
          _AmountRow(
            'Calculated closing balance',
            snapshot.closingBalance!,
            bold: true,
          ),
          const SizedBox(height: 12),
          if (report.comparison == null)
            const Text('No official statement recorded for comparison.')
          else
            Column(
              children: <Widget>[
                _ComparisonRow(
                  label: 'Opening balance',
                  actual: report.actual!.snapshot.openingBalance,
                  difference: report.comparison!.openingDifference,
                ),
                _ComparisonRow(
                  label: 'Employee contribution',
                  actual: report.actual!.snapshot.employeeContribution,
                  difference: report.comparison!.employeeDifference,
                ),
                _ComparisonRow(
                  label: 'Employer contribution',
                  actual: report.actual!.snapshot.employerContribution,
                  difference: report.comparison!.employerDifference,
                ),
                _ComparisonRow(
                  label: 'Profit',
                  actual: report.actual!.snapshot.profit,
                  difference: report.comparison!.profitDifference,
                ),
                _ComparisonRow(
                  label: 'Adjustments',
                  actual: report.actual!.snapshot.adjustments,
                  difference: report.comparison!.adjustmentDifference,
                ),
                _ComparisonRow(
                  label: 'Closing balance',
                  actual: report.actual!.snapshot.closingBalance,
                  difference: report.comparison!.closingDifference,
                ),
              ],
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () =>
                  context.push('/reports/${summary.year.startYear}/actual'),
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(
                report.actual == null
                    ? 'Add actual statement'
                    : 'Edit actual statement',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.actual,
    required this.difference,
  });

  final String label;
  final Money? actual;
  final Money? difference;

  @override
  Widget build(BuildContext context) {
    if (actual == null) return const SizedBox.shrink();
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        'Difference ${difference == null ? '—' : _formatMoney(difference!)}',
      ),
      trailing: Text(_formatMoney(actual!)),
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

StoredActualPFStatement? _actualFor(
  List<StoredActualPFStatement> statements,
  int startYear,
) {
  for (final statement in statements) {
    if (statement.statementStartYear == startYear) return statement;
  }
  return null;
}

StatementYearConfiguration _currentConfiguration(
  List<StoredStatementYearDefinition> definitions,
  DateTime today,
) {
  for (final definition in definitions.reversed) {
    if (!definition.effectiveFrom.isAfter(today)) {
      return definition.configuration;
    }
  }
  return const StatementYearConfiguration(
    startMonth: DateTime.july,
    startDay: 1,
  );
}
