import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/pf_calculation_engine.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';
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
  final maturityRule = engine.selectMaturityRuleForDate(
    employment: setup.employmentDates,
    asOfDate: exitDate,
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
      appBar: AppBar(title: Text(context.l10n.exitEstimate)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.expectedExitDate),
            subtitle: Text(_formatDate(context, _exitDate)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickDate,
          ),
          result.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(context.l10n.estimateUnavailable('$error')),
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
                  ? context.l10n.matureAtExit
                  : context.l10n.beforeMaturity,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              context.l10n.maturityDateValue(
                _formatDate(context, view.maturityDate),
              ),
            ),
            const SizedBox(height: 12),
            _EstimateRow(
              context.l10n.employeeContribution,
              estimate.employeeContribution,
            ),
            _EstimateRow(
              context.l10n.receivableEmployerContribution,
              estimate.employerContribution,
            ),
            _EstimateRow(context.l10n.knownProfit, estimate.knownProfit),
            _EstimateRow(context.l10n.adjustments, estimate.adjustments),
            _EstimateRow(
              context.l10n.forfeitedEmployerContribution,
              estimate.forfeitedEmployerContribution,
            ),
            const Divider(),
            _EstimateRow(
              context.l10n.estimatedReceivable,
              estimate.estimatedReceivable,
              bold: true,
            ),
            const SizedBox(height: 12),
            Text(context.l10n.exitProfitWarning),
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

String _formatDate(BuildContext context, DateTime date) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
        .format(date);
