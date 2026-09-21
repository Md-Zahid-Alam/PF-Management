import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/domain/calculation_policy.dart';
import 'package:pf_tracker/src/core/domain/pf_calculation_engine.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/core/domain/setup_models.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';
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
          label: Text(context.l10n.retryMaturityDetails),
        ),
      );
    } else if (setup.requireValue == null) {
      body = Center(child: Text(context.l10n.completePFSetupFirst));
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
      } on MissingCalculationInput {
        body = Center(child: Text(context.l10n.maturityDataUnavailable));
      }
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.pfMaturity)),
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
    final l10n = context.l10n;
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
                      ? l10n.pfIsMature
                      : l10n.daysRemaining(remaining < 0 ? 0 : remaining),
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
              _DetailRow(l10n.joiningDate, setup.joiningDate),
              _DetailRow(l10n.pfStartDate, setup.pfStartDate),
              _DetailRow(l10n.maturityDate, maturityDate),
              ListTile(
                title: Text(l10n.maturityPeriod),
                trailing: Text(l10n.monthsCount(rule.maturityMonths)),
              ),
              ListTile(
                title: Text(l10n.maturityBasis),
                trailing: Text(_basis(context, rule.maturityBasis)),
              ),
              ListTile(
                title: Text(l10n.employerContributionEntitlement),
                trailing: Text(
                  employerEntitled ? l10n.entitled : l10n.notEntitled,
                ),
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
      trailing: Text(
        DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
            .format(date),
      ),
    );
  }
}

String _basis(BuildContext context, MaturityBasis value) => switch (value) {
  MaturityBasis.joiningDate => context.l10n.joiningDate,
  MaturityBasis.pfStartDate => context.l10n.pfStartDate,
  MaturityBasis.permanentDate => context.l10n.permanentDate,
};
