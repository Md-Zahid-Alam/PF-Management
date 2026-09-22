import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/pf_calculation_engine.dart';
import 'package:pf_tracker/src/core/domain/pf_report_service.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/core/presentation/formatters.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';
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

enum _ReportMode { statementYear, monthly, calendarYear, salary, profit }

enum _ContributionView { total, employee, employer, adjustment }

class PFReportsScreen extends ConsumerStatefulWidget {
  const PFReportsScreen({super.key});

  @override
  ConsumerState<PFReportsScreen> createState() => _PFReportsScreenState();
}

class _PFReportsScreenState extends ConsumerState<PFReportsScreen> {
  var _mode = _ReportMode.statementYear;
  var _contribution = _ContributionView.total;
  int? _year;
  String? _status;
  DateTimeRange? _range;

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(pfStatementReportsProvider);
    final records = ref.watch(monthlyPFRecordsProvider);
    final salaries = ref.watch(salaryHistoryProvider);
    final profits = ref.watch(profitHistoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.pfReports),
        actions: <Widget>[
          IconButton(
            tooltip: context.l10n.exitEstimate,
            onPressed: () => context.push('/reports/exit-estimate'),
            icon: const Icon(Icons.directions_walk_outlined),
          ),
          IconButton(
            tooltip: context.l10n.statementYearSettings,
            onPressed: () => context.push('/reports/statement-year'),
            icon: const Icon(Icons.date_range_outlined),
          ),
        ],
      ),
      body:
          reports.isLoading ||
              records.isLoading ||
              salaries.isLoading ||
              profits.isLoading
          ? const Center(child: CircularProgressIndicator())
          : reports.hasError ||
                records.hasError ||
                salaries.hasError ||
                profits.hasError
          ? Center(
              child: FilledButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.retryReports),
              ),
            )
          : _ReportContent(
              mode: _mode,
              reports: reports.requireValue,
              records: records.requireValue,
              salaries: salaries.requireValue,
              profits: profits.requireValue,
              year: _year,
              status: _status,
              range: _range,
              contribution: _contribution,
              onModeChanged: (value) => setState(() => _mode = value),
              onYearChanged: (value) => setState(() => _year = value),
              onStatusChanged: (value) => setState(() => _status = value),
              onContributionChanged: (value) =>
                  setState(() => _contribution = value),
              onPickRange: _pickRange,
              onClearRange: () => setState(() => _range = null),
            ),
    );
  }

  Future<void> _pickRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDateRange: _range,
    );
    if (selected != null && mounted) {
      setState(() => _range = selected);
    }
  }

  void _retry() {
    ref.invalidate(pfStatementReportsProvider);
    ref.invalidate(monthlyPFRecordsProvider);
    ref.invalidate(salaryHistoryProvider);
    ref.invalidate(profitHistoryProvider);
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({
    required this.mode,
    required this.reports,
    required this.records,
    required this.salaries,
    required this.profits,
    required this.year,
    required this.status,
    required this.range,
    required this.contribution,
    required this.onModeChanged,
    required this.onYearChanged,
    required this.onStatusChanged,
    required this.onContributionChanged,
    required this.onPickRange,
    required this.onClearRange,
  });

  final _ReportMode mode;
  final List<PFStatementReportView> reports;
  final List<StoredMonthlyPFRecord> records;
  final List<StoredSalary> salaries;
  final List<StoredProfitRecord> profits;
  final int? year;
  final String? status;
  final DateTimeRange? range;
  final _ContributionView contribution;
  final ValueChanged<_ReportMode> onModeChanged;
  final ValueChanged<int?> onYearChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<_ContributionView> onContributionChanged;
  final VoidCallback onPickRange;
  final VoidCallback onClearRange;

  @override
  Widget build(BuildContext context) {
    final years = <int>{
      for (final record in records) record.month.year,
      for (final salary in salaries) salary.effectiveFrom.year,
      for (final profit in profits) profit.creditedDate.year,
    }.toList()..sort((a, b) => b.compareTo(a));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        DropdownButtonFormField<_ReportMode>(
          initialValue: mode,
          decoration: InputDecoration(labelText: context.l10n.reportType),
          items: <DropdownMenuItem<_ReportMode>>[
            DropdownMenuItem(
              value: _ReportMode.statementYear,
              child: Text(context.l10n.pfStatementYears),
            ),
            DropdownMenuItem(
              value: _ReportMode.monthly,
              child: Text(context.l10n.monthlyPF),
            ),
            DropdownMenuItem(
              value: _ReportMode.calendarYear,
              child: Text(context.l10n.calendarYearPF),
            ),
            DropdownMenuItem(
              value: _ReportMode.salary,
              child: Text(context.l10n.salaryHistory),
            ),
            DropdownMenuItem(
              value: _ReportMode.profit,
              child: Text(context.l10n.knownProfitReport),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              onModeChanged(value);
            }
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<int?>(
                initialValue: year,
                decoration: InputDecoration(
                  labelText: context.l10n.calendarYear,
                ),
                items: <DropdownMenuItem<int?>>[
                  DropdownMenuItem(
                    value: null,
                    child: Text(context.l10n.allYears),
                  ),
                  for (final item in years)
                    DropdownMenuItem(value: item, child: Text('$item')),
                ],
                onChanged: onYearChanged,
              ),
            ),
            if (mode == _ReportMode.monthly)
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<String?>(
                  initialValue: status,
                  decoration: InputDecoration(labelText: context.l10n.pfStatus),
                  items: <DropdownMenuItem<String?>>[
                    DropdownMenuItem(
                      value: null,
                      child: Text(context.l10n.allStatuses),
                    ),
                    DropdownMenuItem(
                      value: 'automaticallyCalculated',
                      child: Text(context.l10n.automaticallyCalculated),
                    ),
                    DropdownMenuItem(
                      value: 'manuallyCalculated',
                      child: Text(context.l10n.manuallyCalculated),
                    ),
                    DropdownMenuItem(
                      value: 'manuallyAdjusted',
                      child: Text(context.l10n.manuallyAdjusted),
                    ),
                    DropdownMenuItem(
                      value: 'confirmed',
                      child: Text(context.l10n.confirmed),
                    ),
                  ],
                  onChanged: onStatusChanged,
                ),
              ),
            if (mode == _ReportMode.monthly || mode == _ReportMode.calendarYear)
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<_ContributionView>(
                  initialValue: contribution,
                  decoration: InputDecoration(
                    labelText: context.l10n.contributionType,
                  ),
                  items: <DropdownMenuItem<_ContributionView>>[
                    DropdownMenuItem(
                      value: _ContributionView.total,
                      child: Text(context.l10n.totalPF),
                    ),
                    DropdownMenuItem(
                      value: _ContributionView.employee,
                      child: Text(context.l10n.employee),
                    ),
                    DropdownMenuItem(
                      value: _ContributionView.employer,
                      child: Text(context.l10n.employer),
                    ),
                    DropdownMenuItem(
                      value: _ContributionView.adjustment,
                      child: Text(context.l10n.adjustments),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onContributionChanged(value);
                    }
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: onPickRange,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(
                range == null
                    ? context.l10n.dateRange
                    : '${_formatShortDate(context, range!.start)} – ${_formatShortDate(context, range!.end)}',
              ),
            ),
            if (range != null)
              IconButton(
                tooltip: context.l10n.clearDateRange,
                onPressed: onClearRange,
                icon: const Icon(Icons.clear),
              ),
          ],
        ),
        const SizedBox(height: 20),
        ..._body(context),
      ],
    );
  }

  List<Widget> _body(BuildContext context) => switch (mode) {
    _ReportMode.statementYear => _statementWidgets(),
    _ReportMode.monthly => _monthlyWidgets(),
    _ReportMode.calendarYear => _yearlyWidgets(),
    _ReportMode.salary => _salaryWidgets(),
    _ReportMode.profit => _profitWidgets(),
  };

  List<Widget> _statementWidgets() {
    final filtered = reports.where((item) {
      return (year == null || item.summary.year.startYear == year) &&
          _inRange(item.summary.periodStart);
    }).toList();
    return _withSpacing(<Widget>[
      for (final item in filtered) _StatementCard(item),
    ]);
  }

  List<Widget> _monthlyWidgets() {
    final filtered = records.where((item) {
      return (year == null || item.month.year == year) &&
          (status == null || item.status == status) &&
          _inRange(item.month.firstDay);
    }).toList()..sort((a, b) => b.month.compareTo(a.month));
    return _withSpacing(<Widget>[
      for (final item in filtered)
        Card(
          child: ListTile(
            title: Text(DateFormat.yMMMM().format(item.month.firstDay)),
            subtitle: Text(formatPFStatus(item.status)),
            trailing: Text(_formatMoney(_amountFor(item))),
          ),
        ),
    ]);
  }

  List<Widget> _yearlyWidgets() {
    final grouped = <int, List<StoredMonthlyPFRecord>>{};
    for (final item in records) {
      if ((year == null || item.month.year == year) &&
          _inRange(item.month.firstDay)) {
        grouped.putIfAbsent(item.month.year, () => []).add(item);
      }
    }
    final years = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return _withSpacing(<Widget>[
      for (final itemYear in years)
        Card(
          child: ListTile(
            title: Text('$itemYear'),
            subtitle: Text('${grouped[itemYear]!.length} PF months'),
            trailing: Text(_formatMoney(_sumRecords(grouped[itemYear]!))),
          ),
        ),
    ]);
  }

  List<Widget> _salaryWidgets() {
    final filtered = salaries.where((item) {
      return (year == null || item.effectiveFrom.year == year) &&
          _inRange(item.effectiveFrom);
    }).toList()..sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));
    return _withSpacing(<Widget>[
      for (final item in filtered)
        Card(
          child: ListTile(
            title: Text(_formatMoney(item.grossSalary)),
            subtitle: Text(
              'Effective ${DateFormat.yMMMd().format(item.effectiveFrom)}',
            ),
          ),
        ),
    ]);
  }

  List<Widget> _profitWidgets() {
    final filtered = profits.where((item) {
      return (year == null || item.creditedDate.year == year) &&
          _inRange(item.creditedDate);
    }).toList()..sort((a, b) => b.creditedDate.compareTo(a.creditedDate));
    final widgets = <Widget>[];
    if (filtered.isNotEmpty) {
      widgets.add(
        Card(
          child: ListTile(
            title: const Text('Total known profit'),
            trailing: Text(_formatMoney(_sumProfits(filtered))),
          ),
        ),
      );
    }
    widgets.addAll(<Widget>[
      for (final item in filtered)
        Card(
          child: ListTile(
            title: Text(_formatMoney(item.amount)),
            subtitle: Text(
              'Credited ${DateFormat.yMMMd().format(item.creditedDate)}',
            ),
          ),
        ),
    ]);
    return _withSpacing(widgets);
  }

  bool _inRange(DateTime date) {
    if (range == null) {
      return true;
    }
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(range!.start) && !day.isAfter(range!.end);
  }

  Money _amountFor(StoredMonthlyPFRecord item) => switch (contribution) {
    _ContributionView.employee => item.employeeContribution,
    _ContributionView.employer => item.employerContribution,
    _ContributionView.adjustment => item.adjustment,
    _ContributionView.total =>
      item.employeeContribution + item.employerContribution + item.adjustment,
  };

  Money _sumRecords(List<StoredMonthlyPFRecord> items) {
    var total = Money.zero(
      decimalPlaces: items.first.grossSalary.decimalPlaces,
      currencyCode: items.first.grossSalary.currencyCode,
    );
    for (final item in items) {
      total += _amountFor(item);
    }
    return total;
  }

  Money _sumProfits(List<StoredProfitRecord> items) {
    var total = Money.zero(
      decimalPlaces: items.first.amount.decimalPlaces,
      currencyCode: items.first.amount.currencyCode,
    );
    for (final item in items) {
      total += item.amount;
    }
    return total;
  }

  List<Widget> _withSpacing(List<Widget> widgets) {
    if (widgets.isEmpty) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.all(24),
          child: Text('No records match the selected filters.'),
        ),
      ];
    }
    return <Widget>[
      for (var index = 0; index < widgets.length; index++) ...<Widget>[
        widgets[index],
        if (index != widgets.length - 1) const SizedBox(height: 12),
      ],
    ];
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
              onPressed: () => context.push(
                '/reports/${summary.year.startYear}/actual?currency=${snapshot.closingBalance!.currencyCode}',
              ),
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
    if (actual == null) {
      return const SizedBox.shrink();
    }
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

String _formatShortDate(BuildContext context, DateTime date) =>
    DateFormat.yMd(Localizations.localeOf(context).toLanguageTag())
        .format(date);

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
    if (statement.statementStartYear == startYear) {
      return statement;
    }
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
