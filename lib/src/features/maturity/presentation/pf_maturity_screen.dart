import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/domain/calculation_policy.dart';
import 'package:pf_tracker/src/core/domain/pf_calculation_engine.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/core/domain/setup_models.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class PFMaturityScreen extends ConsumerWidget {
  const PFMaturityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(initialPFSetupProvider);
    final rules = ref.watch(pfRuleHistoryProvider);
    Widget body;
    if (setup.isLoading || rules.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (setup.hasError || rules.hasError) {
      body = Center(
        child: FilledButton.icon(
          onPressed: () {
            ref.invalidate(initialPFSetupProvider);
            ref.invalidate(pfRuleHistoryProvider);
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Retry maturity details'),
        ),
      );
    } else if (setup.requireValue == null) {
      body = const Center(child: Text('Complete PF setup first.'));
    } else {
      try {
        const engine = PFCalculationEngine();
        final value = setup.requireValue!;
        final rule = engine.selectMaturityRuleForDate(
          employment: value.employmentDates,
          asOfDate: DateTime.now(),
          ruleHistory: rules.requireValue.map((item) => item.rule),
        );
        body = _MaturityDetails(setup: value, rule: rule);
      } on MissingCalculationInput catch (error) {
        body = Center(child: Text(error.message));
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('PF Maturity')),
      body: body,
    );
  }
}

class _MaturityDetails extends StatelessWidget {
  const _MaturityDetails({required this.setup, required this.rule});

  final InitialPFSetup setup;
  final PFRuleVersion rule;

  @override
  Widget build(BuildContext context) {
    const engine = PFCalculationEngine();
    final maturityDate = engine.calculateMaturityDate(
      setup.employmentDates,
      rule,
    );
    final today = DateTime.now();
    final status = engine.maturityStatus(today, maturityDate);
    final remaining = maturityDate
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    final employerEntitled = status == MaturityStatus.mature
        ? rule.employerEntitledAfterMaturity
        : rule.employerEntitledBeforeMaturity;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Card(
          color: status == MaturityStatus.mature
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: <Widget>[
                Icon(
                  status == MaturityStatus.mature
                      ? Icons.verified_outlined
                      : Icons.hourglass_bottom_outlined,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  status == MaturityStatus.mature
                      ? 'PF is mature'
                      : '${remaining < 0 ? 0 : remaining} days remaining',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: <Widget>[
              _DetailRow('Joining date', setup.joiningDate),
              _DetailRow('PF start date', setup.pfStartDate),
              _DetailRow('Maturity date', maturityDate),
              ListTile(
                title: const Text('Maturity period'),
                trailing: Text('${rule.maturityMonths} months'),
              ),
              ListTile(
                title: const Text('Maturity basis'),
                trailing: Text(_basis(rule.maturityBasis)),
              ),
              ListTile(
                title: const Text('Employer contribution entitlement'),
                trailing: Text(employerEntitled ? 'Entitled' : 'Not entitled'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.date);

  final String label;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: Text(DateFormat.yMMMd().format(date)),
    );
  }
}

String _basis(MaturityBasis value) => switch (value) {
  MaturityBasis.joiningDate => 'Joining date',
  MaturityBasis.pfStartDate => 'PF start date',
  MaturityBasis.permanentDate => 'Permanent date',
};
