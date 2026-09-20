import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/database/drift_repositories.dart';
import 'package:pf_tracker/src/core/domain/automation_models.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class SalaryScheduleFormScreen extends ConsumerStatefulWidget {
  const SalaryScheduleFormScreen({super.key});

  @override
  ConsumerState<SalaryScheduleFormScreen> createState() =>
      _SalaryScheduleFormScreenState();
}

class _SalaryScheduleFormScreenState
    extends ConsumerState<SalaryScheduleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _startDay = TextEditingController(text: '1');
  final _endDay = TextEditingController(text: '5');
  var _effectiveFrom = DateTime(DateTime.now().year, DateTime.now().month);
  var _startOffset = 1;
  var _endOffset = 1;
  var _saving = false;

  @override
  void dispose() {
    _startDay.dispose();
    _endDay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Salary Schedule')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Effective from'),
              subtitle: Text(DateFormat.yMMMM().format(_effectiveFrom)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickEffectiveMonth,
            ),
            const SizedBox(height: 12),
            _monthDropdown(
              label: 'Payment window starts',
              value: _startOffset,
              onChanged: (value) => setState(() => _startOffset = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('scheduleStartDayField'),
              controller: _startDay,
              decoration: const InputDecoration(labelText: 'Start day'),
              keyboardType: TextInputType.number,
              validator: _validateDay,
            ),
            const SizedBox(height: 12),
            _monthDropdown(
              label: 'Payment window ends',
              value: _endOffset,
              onChanged: (value) => setState(() => _endOffset = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('scheduleEndDayField'),
              controller: _endDay,
              decoration: const InputDecoration(labelText: 'End day'),
              keyboardType: TextInputType.number,
              validator: _validateDay,
            ),
            const SizedBox(height: 12),
            const Text(
              'The final payment-window day becomes the scheduled PF generation date. Existing PF records are never changed automatically.',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('saveSalaryScheduleButton'),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving…' : 'Save schedule version'),
            ),
          ],
        ),
      ),
    );
  }

  DropdownButtonFormField<int> _monthDropdown({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: const <DropdownMenuItem<int>>[
        DropdownMenuItem(value: 0, child: Text('Same month')),
        DropdownMenuItem(value: 1, child: Text('Following month')),
      ],
      onChanged: (selected) => onChanged(selected ?? 1),
    );
  }

  String? _validateDay(String? value) {
    final day = int.tryParse(value ?? '');
    return day == null || day < 1 || day > 31
        ? 'Enter a day from 1 to 31'
        : null;
  }

  Future<void> _pickEffectiveMonth() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom,
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: 'Select any day in the effective month',
    );
    if (selected != null && mounted) {
      setState(() => _effectiveFrom = DateTime(selected.year, selected.month));
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final startDay = int.parse(_startDay.text);
    final endDay = int.parse(_endDay.text);
    if (_endOffset < _startOffset ||
        (_endOffset == _startOffset && endDay < startDay)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment window end must follow its start.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    try {
      await ref
          .read(salaryScheduleRepositoryProvider)
          .save(
            organizationId: DriftInitialSetupRepository.organizationId,
            schedule: EffectiveSalarySchedule(
              id: 'schedule-${now.microsecondsSinceEpoch}',
              effectiveFrom: _effectiveFrom,
              schedule: SalarySchedule(
                paymentMonthOffset: _endOffset,
                paymentWindowStartMonthOffset: _startOffset,
                paymentWindowStartDay: startDay,
                paymentWindowEndDay: endDay,
              ),
            ),
            createdAt: now,
            updatedAt: now,
          );
      ref.invalidate(salaryScheduleHistoryProvider);
      ref.invalidate(pfAutomationRunProvider);
      if (mounted) context.pop();
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save this schedule. Its effective month may already exist.',
            ),
          ),
        );
      }
    }
  }
}
