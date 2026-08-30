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
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class ManualPFRecordScreen extends ConsumerStatefulWidget {
  const ManualPFRecordScreen({super.key});

  @override
  ConsumerState<ManualPFRecordScreen> createState() =>
      _ManualPFRecordScreenState();
}

class _ManualPFRecordScreenState extends ConsumerState<ManualPFRecordScreen> {
  var _month = YearMonth.fromDate(DateTime.now());
  var _saving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calculate PF Month')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Text(
              'Create a monthly PF record',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'The effective salary and PF rule for the selected month will be used. Existing months are never duplicated.',
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                title: const Text('PF / salary month'),
                subtitle: Text(DateFormat.yMMMM().format(_month.firstDay)),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: _pickMonth,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('calculateMonthButton'),
              onPressed: _saving ? null : _calculate,
              icon: const Icon(Icons.calculate_outlined),
              label: Text(_saving ? 'Calculating…' : 'Calculate and save'),
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
      helpText: 'Select any day in the PF month',
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
        schedules: <EffectiveSalarySchedule>[setup.salarySchedule],
      );
      ref.invalidate(monthlyPFRecordsProvider);
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

  static String _messageFor(Object error) {
    final message = error.toString();
    if (message.contains('Salary information')) {
      return 'Salary information is required for this month.';
    }
    if (message.contains('PF rule information')) {
      return 'PF rule information is required for this month.';
    }
    if (message.contains('Complete PF setup')) {
      return 'Complete PF setup before calculating a month.';
    }
    return 'Could not calculate this PF month.';
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
