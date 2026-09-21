import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/pf_calculation_engine.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';

class PFCalculatorScreen extends StatefulWidget {
  const PFCalculatorScreen({super.key});

  @override
  State<PFCalculatorScreen> createState() => _PFCalculatorScreenState();
}

class _PFCalculatorScreenState extends State<PFCalculatorScreen> {
  static const _engine = PFCalculationEngine();

  final _formKey = GlobalKey<FormState>();
  final _grossController = TextEditingController(text: '30000');
  final _basicRateController = TextEditingController(text: '60');
  final _employeeRateController = TextEditingController(text: '10');
  final _employerRateController = TextEditingController(text: '10');

  _CalculatorResult? _result;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  void dispose() {
    _grossController.dispose();
    _basicRateController.dispose();
    _employeeRateController.dispose();
    _employerRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pfCalculator)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Text(
              l10n.calculatorEstimateHeading,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(l10n.calculatorEstimateNotice),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: <Widget>[
                      TextFormField(
                        key: const Key('grossSalaryField'),
                        controller: _grossController,
                        decoration: InputDecoration(
                          labelText: l10n.grossSalary,
                          prefixText: '৳ ',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: _validateGrossSalary,
                      ),
                      const SizedBox(height: 16),
                      _RateField(
                        label: l10n.basicSalaryPercentage,
                        controller: _basicRateController,
                      ),
                      const SizedBox(height: 16),
                      _RateField(
                        label: l10n.employeePFPercentage,
                        controller: _employeeRateController,
                      ),
                      const SizedBox(height: 16),
                      _RateField(
                        label: l10n.employerPFPercentage,
                        controller: _employerRateController,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const Key('calculateButton'),
                          onPressed: _calculate,
                          icon: const Icon(Icons.calculate_outlined),
                          label: Text(l10n.calculatePF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_result case final result?) ...<Widget>[
              const SizedBox(height: 20),
              _ResultsCard(result: result),
            ],
          ],
        ),
      ),
    );
  }

  String? _validateGrossSalary(String? value) {
    final amount = int.tryParse(value ?? '');
    if (amount == null || amount <= 0) {
      return context.l10n.grossSalaryGreaterThanZero;
    }
    return null;
  }

  void _calculate() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    try {
      final gross = Money.parse(_grossController.text);
      final basicRate = Rate.fromPercent(_basicRateController.text);
      final employeeRate = Rate.fromPercent(_employeeRateController.text);
      final employerRate = Rate.fromPercent(_employerRateController.text);
      final basic = _engine.calculateBasicSalary(gross, basicRate);
      final employee = _engine.calculateEmployeeContribution(
        basic,
        employeeRate,
      );
      final employer = _engine.calculateEmployerContribution(
        basic,
        employerRate,
      );
      setState(() {
        _result = _CalculatorResult(
          basicSalary: basic,
          employeeContribution: employee,
          employerContribution: employer,
        );
      });
    } on FormatException {
      setState(() => _result = null);
    }
  }
}

class _RateField extends StatelessWidget {
  const _RateField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, suffixText: '%'),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d{0,4})?')),
      ],
      validator: (value) {
        final rate = double.tryParse(value ?? '');
        if (rate == null || rate < 0 || rate > 100) {
          return context.l10n.percentageRangeError;
        }
        return null;
      },
    );
  }
}

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({required this.result});

  final _CalculatorResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final monthlyTotal =
        result.employeeContribution + result.employerContribution;
    final annualEmployee = _annual(result.employeeContribution);
    final annualEmployer = _annual(result.employerContribution);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.calculationResult,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _ResultRow(label: l10n.basicSalary, amount: result.basicSalary),
            _ResultRow(
              label: l10n.employeePF,
              amount: result.employeeContribution,
            ),
            _ResultRow(
              label: l10n.employerPF,
              amount: result.employerContribution,
            ),
            const Divider(height: 28),
            _ResultRow(
              label: l10n.totalMonthlyPF,
              amount: monthlyTotal,
              emphasized: true,
            ),
            const SizedBox(height: 20),
            Text(
              l10n.annualProjection,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _ResultRow(label: l10n.employeeAnnual, amount: annualEmployee),
            _ResultRow(label: l10n.employerAnnual, amount: annualEmployer),
            _ResultRow(
              label: l10n.totalAnnualPF,
              amount: annualEmployee + annualEmployer,
              emphasized: true,
            ),
          ],
        ),
      ),
    );
  }

  static Money _annual(Money monthly) {
    return Money.fromMinorUnits(
      monthly.minorUnits * 12,
      decimalPlaces: monthly.decimalPlaces,
      currencyCode: monthly.currencyCode,
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.amount,
    this.emphasized = false,
  });

  final String label;
  final Money amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: style)),
          Text(_formatMoney(context, amount), style: style),
        ],
      ),
    );
  }
}

class _CalculatorResult {
  const _CalculatorResult({
    required this.basicSalary,
    required this.employeeContribution,
    required this.employerContribution,
  });

  final Money basicSalary;
  final Money employeeContribution;
  final Money employerContribution;
}

String _formatMoney(BuildContext context, Money money) {
  return NumberFormat.currency(
    locale: Localizations.localeOf(context).toLanguageTag(),
    symbol: '৳',
    decimalDigits: money.decimalPlaces,
  ).format(money.minorUnits);
}
