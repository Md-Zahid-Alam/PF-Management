import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/database/drift_repositories.dart';
import 'package:pf_tracker/src/core/domain/automation_models.dart';
import 'package:pf_tracker/src/core/domain/pf_automation_service.dart';
import 'package:pf_tracker/src/core/domain/pf_calculation_engine.dart';
import 'package:pf_tracker/src/core/domain/repositories.dart';
import 'package:pf_tracker/src/core/domain/year_month.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class ManualPFRecordScreen extends ConsumerStatefulWidget {
  const ManualPFRecordScreen({this.initialMonth, super.key});

  final YearMonth? initialMonth;

  @override
  ConsumerState<ManualPFRecordScreen> createState() =>
      _ManualPFRecordScreenState();
}

class _ManualPFRecordScreenState extends ConsumerState<ManualPFRecordScreen> {
  late YearMonth _month;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth ?? YearMonth.fromDate(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.calculatePFMonth)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Text(
              context.l10n.createMonthlyPFRecord,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(context.l10n.manualCalculationNotice),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                title: Text(context.l10n.pfSalaryMonth),
                subtitle: Text(
                  DateFormat.yMMMM(
                    Localizations.localeOf(context).toLanguageTag(),
                  ).format(_month.firstDay),
                ),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: _pickMonth,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('calculateMonthButton'),
              onPressed: _saving ? null : _calculate,
              icon: const Icon(Icons.calculate_outlined),
              label: Text(
                _saving
                    ? context.l10n.calculating
                    : context.l10n.calculateAndSave,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMonth() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _month.firstDay,
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: context.l10n.selectPFMonthHelp,
    );
    if (selected != null && mounted) {
      setState(() => _month = YearMonth.fromDate(selected));
    }
  }

  Future<void> _calculate() async {
    setState(() => _saving = true);
    try {
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
      final schedules = await ref
          .read(salaryScheduleRepositoryProvider)
          .getForOrganization(DriftInitialSetupRepository.organizationId);
      final service = PFAutomationService(
        engine: const PFCalculationEngine(),
        monthlyRepository: ref.read(monthlyPFRepositoryProvider),
        settingsRepository: _UnusedSettingsRepository(),
        notificationGateway: _UnusedNotificationGateway(),
      );
      await service.calculateManually(
        now: DateTime.now(),
        employmentId: DriftInitialSetupRepository.employmentId,
        employment: setup.employmentDates,
        month: _month,
        salaryHistory: salaries,
        ruleHistory: rules,
        schedules: schedules,
      );
      ref.invalidate(monthlyPFRecordsProvider);
      ref.invalidate(pfAutomationRunProvider);
      if (mounted) {
        context.pop();
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_messageFor(error))));
      }
    }
  }

  String _messageFor(Object error) {
    final message = error.toString();
    if (message.contains('Salary information')) {
      return context.l10n.salaryRequiredForMonth;
    }
    if (message.contains('PF rule information')) {
      return context.l10n.pfRuleRequiredForMonth;
    }
    if (message.contains('Complete PF setup')) {
      return context.l10n.completeSetupBeforeMonth;
    }
    return context.l10n.calculateMonthError;
  }
}

class _UnusedSettingsRepository implements AutomationSettingsRepository {
  @override
  Future<AutomationSettings> get() async => const AutomationSettings();

  @override
  Future<void> save(AutomationSettings settings) async {}
}

class _UnusedNotificationGateway implements AutomationNotificationGateway {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> show(AutomationNotification notification) async {}
}
