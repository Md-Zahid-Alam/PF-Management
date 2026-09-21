import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/database/drift_repositories.dart';
import 'package:pf_tracker/src/core/domain/automation_models.dart';
import 'package:pf_tracker/src/core/domain/historical_pf_service.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/pf_automation_service.dart';
import 'package:pf_tracker/src/core/domain/pf_calculation_engine.dart';
import 'package:pf_tracker/src/core/domain/setup_models.dart';
import 'package:pf_tracker/src/core/domain/year_month.dart';
import 'package:pf_tracker/src/core/presentation/formatters.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class HistoricalReconstructionScreen extends ConsumerStatefulWidget {
  const HistoricalReconstructionScreen({super.key});

  @override
  ConsumerState<HistoricalReconstructionScreen> createState() =>
      _HistoricalReconstructionScreenState();
}

class _HistoricalReconstructionScreenState
    extends ConsumerState<HistoricalReconstructionScreen> {
  late Future<_HistoricalViewData> _data;
  final Set<YearMonth> _manualMonthsToReplace = <YearMonth>{};
  var _generating = false;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historical PF Reconstruction')),
      body: FutureBuilder<_HistoricalViewData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(onRetry: _reload);
          }
          final data = snapshot.data!;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.paddingOf(context).bottom,
            ),
            children: <Widget>[
              Text(
                'Review before generating records',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'The preview uses your effective-dated salary history and PF rules. Official company statements are never changed.',
              ),
              const SizedBox(height: 20),
              if (data.preview == null)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No PF month has reached its scheduled generation date yet.',
                    ),
                  ),
                )
              else
                _PreviewCard(
                  data: data,
                  manualMonthsToReplace: _manualMonthsToReplace,
                  onManualMonthChanged: (month, replace) {
                    setState(() {
                      if (replace) {
                        _manualMonthsToReplace.add(month);
                      } else {
                        _manualMonthsToReplace.remove(month);
                      }
                    });
                  },
                ),
              const SizedBox(height: 16),
              if (data.preview != null)
                FilledButton.icon(
                  key: const Key('generateHistoricalPFButton'),
                  onPressed: _generating
                      ? null
                      : () => _confirmAndGenerate(data),
                  icon: const Icon(Icons.history),
                  label: Text(
                    _generating
                        ? 'Generating…'
                        : data.existingRecordCount == 0
                        ? 'Generate Historical PF Records'
                        : 'Recalculate Historical PF',
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _generating ? null : () => context.go('/'),
                child: Text(data.existingRecordCount == 0 ? 'Not now' : 'Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<_HistoricalViewData> _load() async {
    final setup = await ref.read(initialSetupRepositoryProvider).load();
    if (setup == null) {
      throw StateError('Complete PF setup first.');
    }
    final salaries = await ref
        .read(salaryRepositoryProvider)
        .getForEmployment(DriftInitialSetupRepository.employmentId);
    final rules = await ref
        .read(pfRuleRepositoryProvider)
        .getForOrganization(DriftInitialSetupRepository.organizationId);
    final records = await ref
        .read(monthlyPFRepositoryProvider)
        .getForEmployment(DriftInitialSetupRepository.employmentId);
    final schedules = await ref
        .read(salaryScheduleRepositoryProvider)
        .getForOrganization(DriftInitialSetupRepository.organizationId);
    final due = DuePeriodDetector(const PFCalculationEngine()).findDuePeriods(
      today: DateTime.now(),
      employment: setup.employmentDates,
      schedules: schedules,
    );
    final service = HistoricalPFService(
      engine: const PFCalculationEngine(),
      monthlyRepository: ref.read(monthlyPFRepositoryProvider),
    );
    final preview = due.isEmpty
        ? null
        : service.preview(
            employment: setup.employmentDates,
            calculationThrough: due.last,
            salaryHistory: salaries,
            ruleHistory: rules,
            schedules: schedules,
          );
    final manualAdjustedMonths = records
        .where((record) => record.status == 'manuallyAdjusted')
        .map((record) => record.month)
        .toSet();
    _manualMonthsToReplace.removeWhere(
      (month) => !manualAdjustedMonths.contains(month),
    );
    return _HistoricalViewData(
      setup: setup,
      salaries: salaries,
      rules: rules,
      schedules: schedules,
      preview: preview,
      existingRecordCount: records.length,
      manualAdjustedMonths: manualAdjustedMonths,
    );
  }

  Future<void> _confirmAndGenerate(_HistoricalViewData data) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          data.existingRecordCount == 0
              ? 'Generate historical PF records?'
              : 'Recalculate historical PF?',
        ),
        content: Text(
          data.existingRecordCount == 0
              ? 'This creates ${data.preview!.monthCount} calculated monthly records. Review your salary and rule histories first.'
              : _manualMonthsToReplace.isEmpty
              ? 'Calculated records will use the current effective histories. All manually adjusted records and official statements will remain unchanged.'
              : 'Calculated records will use the current effective histories. ${_manualMonthsToReplace.length} selected manually adjusted month(s) will be replaced. Other manual records and official statements will remain unchanged.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _generating = true);
    try {
      final service = HistoricalPFService(
        engine: const PFCalculationEngine(),
        monthlyRepository: ref.read(monthlyPFRepositoryProvider),
      );
      await service.generate(
        generatedAt: DateTime.now(),
        employmentId: DriftInitialSetupRepository.employmentId,
        employment: data.setup.employmentDates,
        calculationThrough: data.preview!.calculationThrough,
        salaryHistory: data.salaries,
        ruleHistory: data.rules,
        schedules: data.schedules,
        replaceManualMonths: Set<YearMonth>.unmodifiable(
          _manualMonthsToReplace,
        ),
      );
      ref.invalidate(monthlyPFRecordsProvider);
      ref.invalidate(pfAutomationRunProvider);
      if (mounted) context.go('/');
    } on Object {
      if (mounted) {
        setState(() => _generating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Historical PF could not be generated. Check salary and PF rule history.',
            ),
          ),
        );
      }
    }
  }

  void _reload() {
    setState(() => _data = _load());
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.data,
    required this.manualMonthsToReplace,
    required this.onManualMonthChanged,
  });

  final _HistoricalViewData data;
  final Set<YearMonth> manualMonthsToReplace;
  final void Function(YearMonth month, bool replace) onManualMonthChanged;

  @override
  Widget build(BuildContext context) {
    final preview = data.preview!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            _Row(
              'PF start',
              DateFormat.yMMMM().format(preview.pfStart.firstDay),
            ),
            _Row(
              'Calculation through',
              DateFormat.yMMMM().format(preview.calculationThrough.firstDay),
            ),
            _Row('Number of months', '${preview.monthCount}'),
            _Row(
              'Employee contribution',
              formatMoney(preview.employeeContribution),
            ),
            _Row(
              'Employer contribution',
              formatMoney(preview.employerContribution),
            ),
            _Row('Known profit', 'Not entered'),
            const Divider(),
            _Row(
              'Calculated PF',
              formatMoney(preview.calculatedPF),
              strong: true,
            ),
            if (data.existingRecordCount > 0)
              _Row('Existing records', '${data.existingRecordCount}'),
            const SizedBox(height: 8),
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Affected months and versions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 4),
            for (final period in preview.periods)
              _AffectedPeriodTile(
                period: period,
                isManuallyAdjusted: data.manualAdjustedMonths.contains(
                  period.month,
                ),
                replaceManualAdjustment: manualMonthsToReplace.contains(
                  period.month,
                ),
                onReplaceChanged: (replace) =>
                    onManualMonthChanged(period.month, replace),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong ? Theme.of(context).textTheme.titleMedium : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: style)),
          Expanded(
            child: Text(value, style: style, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

class _AffectedPeriodTile extends StatelessWidget {
  const _AffectedPeriodTile({
    required this.period,
    required this.isManuallyAdjusted,
    required this.replaceManualAdjustment,
    required this.onReplaceChanged,
  });

  final HistoricalPFPreviewPeriod period;
  final bool isManuallyAdjusted;
  final bool replaceManualAdjustment;
  final ValueChanged<bool> onReplaceChanged;

  @override
  Widget build(BuildContext context) {
    final month = DateFormat.yMMMM().format(period.month.firstDay);
    final ruleDate = DateFormat.yMMMd().format(period.ruleEffectiveFrom);
    final salaryDate = DateFormat.yMMMd().format(period.salaryEffectiveFrom);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(month),
      subtitle: Text('Rule effective $ruleDate'),
      children: <Widget>[
        if (isManuallyAdjusted)
          CheckboxListTile(
            key: ValueKey('replaceManual-${period.month}'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Replace manual adjustment'),
            subtitle: const Text(
              'Leave unchecked to preserve this manually adjusted month.',
            ),
            value: replaceManualAdjustment,
            onChanged: (value) => onReplaceChanged(value ?? false),
          ),
        _Row('Rule version', period.ruleVersionId),
        _Row('Salary effective', salaryDate),
        _Row('Salary version', period.salaryHistoryId),
        _Row('Employee contribution', formatMoney(period.employeeContribution)),
        _Row('Employer contribution', formatMoney(period.employerContribution)),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Retry historical preview'),
      ),
    );
  }
}

class _HistoricalViewData {
  const _HistoricalViewData({
    required this.setup,
    required this.salaries,
    required this.rules,
    required this.schedules,
    required this.preview,
    required this.existingRecordCount,
    required this.manualAdjustedMonths,
  });

  final InitialPFSetup setup;
  final List<StoredSalary> salaries;
  final List<StoredPFRule> rules;
  final List<EffectiveSalarySchedule> schedules;
  final HistoricalPFPreview? preview;
  final int existingRecordCount;
  final Set<YearMonth> manualAdjustedMonths;
}
