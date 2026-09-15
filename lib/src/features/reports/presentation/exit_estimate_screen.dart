import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/pf_calculation_engine.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class ExitEstimateView {
  const ExitEstimateView({required this.estimate, required this.maturityDate});

  final ExitEstimate estimate;
  final DateTime maturityDate;
}

final exitEstimateProvider = FutureProvider.family<ExitEstimateView, DateTime>((
  ref,
  exitDate,
) async {
  final setup = await ref.watch(initialPFSetupProvider.future);
  if (setup == null) {
    throw const MissingCalculationInput('Initial setup is required.');
  }
  final storedRecords = await ref.watch(monthlyPFRecordsProvider.future);
  final storedProfits = await ref.watch(profitHistoryProvider.future);
  final storedRules = await ref.watch(pfRuleHistoryProvider.future);
  const engine = PFCalculationEngine();
  final rules = storedRules.map((item) => item.rule).toList(growable: false);
  PFRuleVersion? ruleAtExit;
  for (final rule in rules) {
    if (!rule.effectiveFrom.isAfter(exitDate) &&
        (ruleAtExit == null ||
            rule.effectiveFrom.isAfter(ruleAtExit.effectiveFrom))) {
      ruleAtExit = rule;
    }
  }
  if (ruleAtExit == null) {
    throw const MissingCalculationInput('No PF rule applies on the exit date.');
  }
  final maturityRule = engine.selectMaturityRule(
    employment: setup.employmentDates,
    basis: ruleAtExit.maturityBasis,
    ruleHistory: rules,
  );
  final records = <MonthlyPFCalculation>[
    for (final record in storedRecords)
      MonthlyPFCalculation(
        month: record.month,
        grossSalary: record.grossSalary,
        basicSalary: record.basicSalary,
        employeeContribution: record.employeeContribution,
        employerContribution: record.employerContribution,
        totalContribution:
            record.employeeContribution + record.employerContribution,
        ruleVersionId: record.ruleVersionId ?? '',
        scheduledGenerationDate:
            record.scheduledGenerationDate ?? record.month.lastDay,
      ),
  ];
  final estimate = engine.estimateExit(
    exitDate: exitDate,
    employment: setup.employmentDates,
    maturityRule: maturityRule,
    records: records,
    knownProfit: <DatedMoney>[
      for (final profit in storedProfits)
        DatedMoney(date: profit.creditedDate, amount: profit.amount),
    ],
    adjustments: <DatedMoney>[
      for (final record in storedRecords)
        if (record.adjustment.minorUnits != 0)
          DatedMoney(date: record.month.lastDay, amount: record.adjustment),
    ],
    profitComplete: false,
  );
  return ExitEstimateView(
    estimate: estimate,
    maturityDate: engine.calculateMaturityDate(
      setup.employmentDates,
      maturityRule,
    ),
  );
});

class ExitEstimateScreen extends ConsumerStatefulWidget {
  const ExitEstimateScreen({super.key});

  @override
  ConsumerState<ExitEstimateScreen> createState() => _ExitEstimateScreenState();
}

class _ExitEstimateScreenState extends ConsumerState<ExitEstimateScreen> {
  late DateTime _exitDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _exitDate = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(exitEstimateProvider(_exitDate));
    return Scaffold(
      appBar: AppBar(title: const Text('Exit Estimate')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Expected exit date'),
            subtitle: Text(DateFormat.yMMMd().format(_exitDate)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickDate,
          ),
          result.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Estimate unavailable: $error'),
              ),
            ),
            data: (view) => _EstimateCard(view),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _exitDate,
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 36500)),
    );
    if (selected != null && mounted) setState(() => _exitDate = selected);
  }
}

class _EstimateCard extends StatelessWidget {
  const _EstimateCard(this.view);

  final ExitEstimateView view;

  @override
  Widget build(BuildContext context) {
    final estimate = view.estimate;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              estimate.status == MaturityStatus.mature
                  ? 'Mature at exit'
                  : 'Before maturity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'Maturity date: ${DateFormat.yMMMd().format(view.maturityDate)}',
            ),
            const SizedBox(height: 12),
            _EstimateRow(
              'Employee contribution',
              estimate.employeeContribution,
            ),
            _EstimateRow(
              'Receivable employer contribution',
              estimate.employerContribution,
            ),
            _EstimateRow('Known profit', estimate.knownProfit),
            _EstimateRow('Adjustments', estimate.adjustments),
            _EstimateRow(
              'Forfeited employer contribution',
              estimate.forfeitedEmployerContribution,
            ),
            const Divider(),
            _EstimateRow(
              'Estimated receivable',
              estimate.estimatedReceivable,
              bold: true,
            ),
            const SizedBox(height: 12),
            const Text(
              'Profit is incomplete unless every official profit credit has been entered. This estimate does not predict unknown future profit.',
            ),
          ],
        ),
      ),
    );
  }
}

class _EstimateRow extends StatelessWidget {
  const _EstimateRow(this.label, this.amount, {this.bold = false});

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
          Text(_money(amount), style: style),
        ],
      ),
    );
  }
}

String _money(Money amount) => NumberFormat.currency(
  locale: 'en_US',
  symbol: amount.currencyCode == 'BDT' ? '৳' : '${amount.currencyCode} ',
  decimalDigits: amount.decimalPlaces,
).format(amount.minorUnits / _scale(amount.decimalPlaces));

int _scale(int decimalPlaces) {
  var value = 1;
  for (var index = 0; index < decimalPlaces; index++) {
    value *= 10;
  }
  return value;
}
