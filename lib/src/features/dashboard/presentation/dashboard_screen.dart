import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/domain/automation_models.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/pf_calculation_engine.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/core/domain/pf_report_service.dart';
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
    final automation = ref.watch(pfAutomationRunProvider);
    final profits = ref.watch(profitHistoryProvider);
    final actualStatements = ref.watch(actualPFStatementsProvider);
    final statementDefinitions = ref.watch(statementYearDefinitionsProvider);
    final rules = ref.watch(pfRuleHistoryProvider);
    if (setup.isLoading ||
        records.isLoading ||
        settings.isLoading ||
        profits.isLoading ||
        actualStatements.isLoading ||
        statementDefinitions.isLoading ||
        rules.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (setup.hasError ||
        records.hasError ||
        settings.hasError ||
        profits.hasError ||
        actualStatements.hasError ||
        statementDefinitions.hasError ||
        rules.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('PF Dashboard')),
        body: Center(
          child: FilledButton.icon(
            onPressed: () {
              ref.invalidate(initialPFSetupProvider);
              ref.invalidate(monthlyPFRecordsProvider);
              ref.invalidate(automationSettingsProvider);
              ref.invalidate(profitHistoryProvider);
              ref.invalidate(actualPFStatementsProvider);
              ref.invalidate(statementYearDefinitionsProvider);
              ref.invalidate(pfRuleHistoryProvider);
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
      profits: profits.requireValue,
      actualStatements: actualStatements.requireValue,
      statementDefinitions: statementDefinitions.requireValue,
      rules: rules.requireValue,
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
          ref.invalidate(profitHistoryProvider);
          ref.invalidate(actualPFStatementsProvider);
          ref.invalidate(statementYearDefinitionsProvider);
          ref.invalidate(pfRuleHistoryProvider);
          ref.invalidate(pfAutomationRunProvider);
          await ref.read(monthlyPFRecordsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Text(
              'Hello, ${setupValue.employeeName}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (automation.hasError) ...<Widget>[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: const Text('PF automation check failed'),
                  subtitle: const Text('Retry to check for overdue PF months.'),
                  trailing: IconButton(
                    tooltip: 'Retry automation',
                    onPressed: () => ref.invalidate(pfAutomationRunProvider),
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ),
            ],
            if (automation.asData?.value
                case final List<AutomationPeriodResult> items)
              _PendingAutomationActions(items: items),
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
                    value: summary.profitEntered
                        ? formatMoney(summary.profit)
                        : 'Not entered',
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
            if (summary.latestClosingDifference != null) ...<Widget>[
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.compare_arrows),
                  title: const Text('Latest statement difference'),
                  subtitle: const Text(
                    'Official company statement compared with calculated balance',
                  ),
                  trailing: Text(
                    formatMoney(summary.latestClosingDifference!),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () => context.push('/reports'),
                ),
              ),
            ],
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
                    leading: const Icon(Icons.work_history_outlined),
                    title: const Text('Employment dates'),
                    subtitle: Text(
                      'Joined ${DateFormat.yMMMd().format(summary.joiningDate)}\n'
                      'PF started ${DateFormat.yMMMd().format(summary.pfStartDate)}',
                    ),
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

class _PendingAutomationActions extends StatelessWidget {
  const _PendingAutomationActions({required this.items});

  final List<AutomationPeriodResult> items;

  @override
  Widget build(BuildContext context) {
    final pending = items.where((item) {
      return item.status == AutomationPeriodStatus.readyForManualCalculation ||
          item.status == AutomationPeriodStatus.pendingSalaryInformation ||
          item.status == AutomationPeriodStatus.pendingRuleInformation;
    }).toList();
    if (pending.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Pending PF actions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final item in pending) _PendingAutomationTile(item: item),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingAutomationTile extends StatelessWidget {
  const _PendingAutomationTile({required this.item});

  final AutomationPeriodResult item;

  @override
  Widget build(BuildContext context) {
    final month = DateFormat.yMMMM().format(item.month.firstDay);
    final (message, action, route) = switch (item.status) {
      AutomationPeriodStatus.pendingSalaryInformation => (
        'Salary information required',
        'Add salary',
        '/salary-history/add',
      ),
      AutomationPeriodStatus.pendingRuleInformation => (
        'PF rule information required',
        'Add rule',
        '/pf-rule-history/add',
      ),
      _ => (
        '$month PF is ready for calculation',
        'Calculate PF',
        '/records/add?month=${item.month}',
      ),
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(month),
      subtitle: Text(message),
      trailing: TextButton(
        onPressed: () => context.push(route),
        child: Text(action),
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
            Text(
              summary.profitEntered
                  ? 'Includes ${formatMoney(summary.profit)} recorded profit.'
                  : 'Profit has not been entered.',
            ),
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
      child: InkWell(
        onTap: () => context.push('/maturity'),
        borderRadius: BorderRadius.circular(12),
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
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ),
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
    required this.profit,
    required this.profitEntered,
    required this.balance,
    required this.receivableToday,
    required this.afterMaturity,
    required this.monthCount,
    required this.maturityDate,
    required this.maturityDescription,
    required this.autoCalculate,
    required this.latestMonth,
    required this.joiningDate,
    required this.pfStartDate,
    required this.latestClosingDifference,
  });

  factory _DashboardSummary.from({
    required InitialPFSetup setup,
    required List<StoredMonthlyPFRecord> records,
    required List<StoredProfitRecord> profits,
    required List<StoredActualPFStatement> actualStatements,
    required List<StoredStatementYearDefinition> statementDefinitions,
    required List<StoredPFRule> rules,
    required AutomationSettings settings,
    required DateTime today,
  }) {
    final prototype = setup.salary.grossSalary;
    var employee = _zeroLike(prototype);
    var employer = _zeroLike(prototype);
    var adjustments = _zeroLike(prototype);
    var profit = _zeroLike(prototype);
    for (final record in records) {
      employee += record.employeeContribution;
      employer += record.employerContribution;
      adjustments += record.adjustment;
    }
    for (final item in profits) {
      profit += item.amount;
    }
    const engine = PFCalculationEngine();
    final rule = engine.selectMaturityRuleForDate(
      employment: setup.employmentDates,
      asOfDate: today,
      ruleHistory: rules.map((item) => item.rule),
    );
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
    final latestClosingDifference = _latestClosingDifference(
      records: records,
      profits: profits,
      actualStatements: actualStatements,
      definitions: statementDefinitions,
      today: today,
    );
    return _DashboardSummary(
      employee: employee,
      employer: employer,
      profit: profit,
      profitEntered: profits.isNotEmpty,
      balance: employee + employer + profit + adjustments,
      receivableToday: employee + receivedEmployer + profit + adjustments,
      afterMaturity:
          employee +
          (rule.employerEntitledAfterMaturity
              ? employer
              : _zeroLike(prototype)) +
          profit +
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
      joiningDate: setup.joiningDate,
      pfStartDate: setup.pfStartDate,
      latestClosingDifference: latestClosingDifference,
    );
  }

  final Money employee;
  final Money employer;
  final Money profit;
  final bool profitEntered;
  final Money balance;
  final Money receivableToday;
  final Money afterMaturity;
  final int monthCount;
  final DateTime maturityDate;
  final String maturityDescription;
  final bool autoCalculate;
  final String? latestMonth;
  final DateTime joiningDate;
  final DateTime pfStartDate;
  final Money? latestClosingDifference;

  static Money? _latestClosingDifference({
    required List<StoredMonthlyPFRecord> records,
    required List<StoredProfitRecord> profits,
    required List<StoredActualPFStatement> actualStatements,
    required List<StoredStatementYearDefinition> definitions,
    required DateTime today,
  }) {
    if (records.isEmpty || actualStatements.isEmpty) {
      return null;
    }
    var configuration = const StatementYearConfiguration(
      startMonth: DateTime.july,
      startDay: 1,
    );
    for (final definition in definitions) {
      if (!definition.effectiveFrom.isAfter(today)) {
        configuration = definition.configuration;
      }
    }
    final summaries = const PFReportService().statementSummaries(
      records: records,
      profits: profits,
      configuration: configuration,
    );
    for (final summary in summaries) {
      for (final actual in actualStatements) {
        if (actual.statementStartYear == summary.year.startYear) {
          return const PFCalculationEngine()
              .reconcileStatement(
                calculated: summary.snapshot,
                actual: actual.snapshot,
              )
              .closingDifference;
        }
      }
    }
    return null;
  }

  static Money _zeroLike(Money value) {
    return Money.zero(
      decimalPlaces: value.decimalPlaces,
      currencyCode: value.currencyCode,
    );
  }
}
