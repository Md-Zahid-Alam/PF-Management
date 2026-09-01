import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/domain/automation_models.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/pf_calculation_engine.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/core/domain/setup_models.dart';
import 'package:pf_tracker/src/core/presentation/formatters.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(initialPFSetupProvider);
    final records = ref.watch(monthlyPFRecordsProvider);
    final settings = ref.watch(automationSettingsProvider);
    if (setup.isLoading || records.isLoading || settings.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (setup.hasError || records.hasError || settings.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('PF Dashboard')),
        body: Center(
          child: FilledButton.icon(
            onPressed: () {
              ref.invalidate(initialPFSetupProvider);
              ref.invalidate(monthlyPFRecordsProvider);
              ref.invalidate(automationSettingsProvider);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry dashboard'),
          ),
        ),
      );
    }
    final setupValue = setup.requireValue;
    if (setupValue == null) {
      return const _SetupRequiredDashboard();
    }
    final summary = _DashboardSummary.from(
      setup: setupValue,
      records: records.requireValue,
      settings: settings.requireValue,
      today: DateTime.now(),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('PF Dashboard')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(initialPFSetupProvider);
          ref.invalidate(monthlyPFRecordsProvider);
          ref.invalidate(automationSettingsProvider);
          await ref.read(monthlyPFRecordsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Text(
              'Hello, ${setupValue.employeeName}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _BalanceCard(summary: summary),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _SummaryCard(
                    label: 'My contribution',
                    value: formatMoney(summary.employee),
                    icon: Icons.person_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: 'Company contribution',
                    value: formatMoney(summary.employer),
                    icon: Icons.business_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _SummaryCard(
                    label: 'Known profit',
                    value: 'Unknown',
                    icon: Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: 'PF months',
                    value: '${summary.monthCount}',
                    icon: Icons.calendar_month_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _MaturityCard(summary: summary),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: Icon(
                      summary.autoCalculate
                          ? Icons.autorenew
                          : Icons.pause_circle_outline,
                    ),
                    title: const Text('Auto Calculate PF'),
                    trailing: Text(summary.autoCalculate ? 'ON' : 'OFF'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: const Text('Latest PF month'),
                    subtitle: Text(summary.latestMonth ?? 'No records yet'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/records'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary});

  final _DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'CURRENT CALCULATED PF BALANCE',
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: colors.onPrimaryContainer),
            ),
            const SizedBox(height: 8),
            Text(
              formatMoney(summary.balance),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Estimated if leaving today: ${formatMoney(summary.receivableToday)}',
            ),
            const Text('Known profit is not included.'),
          ],
        ),
      ),
    );
  }
}

class _MaturityCard extends StatelessWidget {
  const _MaturityCard({required this.summary});

  final _DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            const CircleAvatar(child: Icon(Icons.flag_outlined)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Maturity',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(DateFormat.yMMMd().format(summary.maturityDate)),
                  Text(summary.maturityDescription),
                ],
              ),
            ),
            Text(formatMoney(summary.afterMaturity)),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _SetupRequiredDashboard extends StatelessWidget {
  const _SetupRequiredDashboard();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PF Dashboard')),
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/setup'),
          child: const Text('Complete PF setup'),
        ),
      ),
    );
  }
}

class _DashboardSummary {
  const _DashboardSummary({
    required this.employee,
    required this.employer,
    required this.balance,
    required this.receivableToday,
    required this.afterMaturity,
    required this.monthCount,
    required this.maturityDate,
    required this.maturityDescription,
    required this.autoCalculate,
    required this.latestMonth,
  });

  factory _DashboardSummary.from({
    required InitialPFSetup setup,
    required List<StoredMonthlyPFRecord> records,
    required AutomationSettings settings,
    required DateTime today,
  }) {
    final prototype = setup.salary.grossSalary;
    var employee = _zeroLike(prototype);
    var employer = _zeroLike(prototype);
    var adjustments = _zeroLike(prototype);
    for (final record in records) {
      employee += record.employeeContribution;
      employer += record.employerContribution;
      adjustments += record.adjustment;
    }
    const engine = PFCalculationEngine();
    final rule = setup.rule.rule;
    final maturityDate = engine.calculateMaturityDate(
      setup.employmentDates,
      rule,
    );
    final status = engine.maturityStatus(today, maturityDate);
    final entitledToday = status == MaturityStatus.mature
        ? rule.employerEntitledAfterMaturity
        : rule.employerEntitledBeforeMaturity;
    final receivedEmployer = entitledToday ? employer : _zeroLike(prototype);
    final days = maturityDate
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    final latest = records.isEmpty
        ? null
        : records
              .map((record) => record.month)
              .reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
    return _DashboardSummary(
      employee: employee,
      employer: employer,
      balance: employee + employer + adjustments,
      receivableToday: employee + receivedEmployer + adjustments,
      afterMaturity:
          employee +
          (rule.employerEntitledAfterMaturity
              ? employer
              : _zeroLike(prototype)) +
          adjustments,
      monthCount: records.length,
      maturityDate: maturityDate,
      maturityDescription: status == MaturityStatus.mature
          ? 'Mature'
          : 'Matures in ${days < 0 ? 0 : days} days',
      autoCalculate: settings.autoCalculate,
      latestMonth: latest == null
          ? null
          : DateFormat.yMMMM().format(latest.firstDay),
    );
  }

  final Money employee;
  final Money employer;
  final Money balance;
  final Money receivableToday;
  final Money afterMaturity;
  final int monthCount;
  final DateTime maturityDate;
  final String maturityDescription;
  final bool autoCalculate;
  final String? latestMonth;

  static Money _zeroLike(Money value) {
    return Money.zero(
      decimalPlaces: value.decimalPlaces,
      currencyCode: value.currencyCode,
    );
  }
}
