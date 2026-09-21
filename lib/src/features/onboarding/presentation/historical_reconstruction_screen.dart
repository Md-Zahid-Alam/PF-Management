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
import 'package:pf_tracker/src/core/presentation/localization.dart';
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
      appBar: AppBar(title: Text(context.l10n.historicalReconstruction)),
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
                context.l10n.reviewBeforeGenerating,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(context.l10n.historicalPreviewNotice),
              const SizedBox(height: 20),
              if (data.preview == null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(context.l10n.noDuePFMonth),
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
                        ? context.l10n.generating
                        : data.existingRecordCount == 0
                        ? context.l10n.generateHistoricalRecords
                        : context.l10n.recalculateHistoricalPF,
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _generating ? null : () => context.go('/'),
                child: Text(
                  data.existingRecordCount == 0
                      ? context.l10n.notNow
                      : context.l10n.done,
                ),
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
              ? context.l10n.generateHistoricalTitle
              : context.l10n.recalculateHistoricalTitle,
        ),
        content: Text(
          data.existingRecordCount == 0
              ? context.l10n.generateHistoricalMessage(data.preview!.monthCount)
              : _manualMonthsToReplace.isEmpty
              ? context.l10n.recalculatePreserveManualMessage
              : context.l10n.recalculateReplaceManualMessage(
                  _manualMonthsToReplace.length,
                ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.confirm),
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
          SnackBar(content: Text(context.l10n.historicalGenerationError)),
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
              context.l10n.pfStart,
              _formatMonth(context, preview.pfStart.firstDay),
            ),
            _Row(
              context.l10n.calculationThrough,
              _formatMonth(context, preview.calculationThrough.firstDay),
            ),
            _Row(context.l10n.numberOfMonths, '${preview.monthCount}'),
            _Row(
              context.l10n.employeeContribution,
              formatMoney(preview.employeeContribution),
            ),
            _Row(
              context.l10n.employerContribution,
              formatMoney(preview.employerContribution),
            ),
            _Row(context.l10n.knownProfit, context.l10n.notEntered),
            const Divider(),
            _Row(
              context.l10n.calculatedPF,
              formatMoney(preview.calculatedPF),
              strong: true,
            ),
            if (data.existingRecordCount > 0)
              _Row(context.l10n.existingRecords, '${data.existingRecordCount}'),
            const SizedBox(height: 8),
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                context.l10n.affectedMonthsAndVersions,
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
    final month = _formatMonth(context, period.month.firstDay);
    final ruleDate = _formatDate(context, period.ruleEffectiveFrom);
    final salaryDate = _formatDate(context, period.salaryEffectiveFrom);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(month),
      subtitle: Text(context.l10n.ruleEffectiveDate(ruleDate)),
      children: <Widget>[
        if (isManuallyAdjusted)
          CheckboxListTile(
            key: ValueKey('replaceManual-${period.month}'),
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.replaceManualAdjustment),
            subtitle: Text(context.l10n.preserveManualAdjustmentHelp),
            value: replaceManualAdjustment,
            onChanged: (value) => onReplaceChanged(value ?? false),
          ),
        _Row(context.l10n.ruleVersion, period.ruleVersionId),
        _Row(context.l10n.salaryEffective, salaryDate),
        _Row(context.l10n.salaryVersion, period.salaryHistoryId),
        _Row(
          context.l10n.employeeContribution,
          formatMoney(period.employeeContribution),
        ),
        _Row(
          context.l10n.employerContribution,
          formatMoney(period.employerContribution),
        ),
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
        label: Text(context.l10n.retryHistoricalPreview),
      ),
    );
  }
}

String _formatDate(BuildContext context, DateTime date) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
        .format(date);

String _formatMonth(BuildContext context, DateTime date) =>
    DateFormat.yMMMM(Localizations.localeOf(context).toLanguageTag())
        .format(date);

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
