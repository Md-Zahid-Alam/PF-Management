import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/database/drift_repositories.dart';
import 'package:pf_tracker/src/core/domain/automation_models.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class SalaryScheduleFormScreen extends ConsumerStatefulWidget {
  const SalaryScheduleFormScreen({super.key, this.scheduleId});

  final String? scheduleId;

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
  var _initializedForEdit = false;

  @override
  void dispose() {
    _startDay.dispose();
    _endDay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.scheduleId case final String scheduleId) {
      final history = ref.watch(salaryScheduleHistoryProvider);
      return history.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, stackTrace) => Scaffold(
          appBar: AppBar(title: Text(context.l10n.editSalarySchedule)),
          body: Center(child: Text(context.l10n.scheduleSaveError)),
        ),
        data: (items) {
          final matches = items.where((item) => item.id == scheduleId);
          if (matches.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: Text(context.l10n.editSalarySchedule)),
              body: Center(child: Text(context.l10n.scheduleSaveError)),
            );
          }
          _initializeForEdit(matches.single);
          return _buildForm(context, editing: true);
        },
      );
    }
    return _buildForm(context, editing: false);
  }

  Widget _buildForm(BuildContext context, {required bool editing}) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          editing
              ? context.l10n.editSalarySchedule
              : context.l10n.newSalarySchedule,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.effectiveFrom),
              subtitle: Text(
                DateFormat.yMMMM(
                  Localizations.localeOf(context).toLanguageTag(),
                ).format(_effectiveFrom),
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickEffectiveMonth,
            ),
            const SizedBox(height: 12),
            _monthDropdown(
              label: context.l10n.paymentWindowStarts,
              value: _startOffset,
              onChanged: (value) => setState(() => _startOffset = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('scheduleStartDayField'),
              controller: _startDay,
              decoration: InputDecoration(labelText: context.l10n.startDay),
              keyboardType: TextInputType.number,
              validator: _validateDay,
            ),
            const SizedBox(height: 12),
            _monthDropdown(
              label: context.l10n.paymentWindowEnds,
              value: _endOffset,
              onChanged: (value) => setState(() => _endOffset = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('scheduleEndDayField'),
              controller: _endDay,
              decoration: InputDecoration(labelText: context.l10n.endDay),
              keyboardType: TextInputType.number,
              validator: _validateDay,
            ),
            const SizedBox(height: 12),
            Text(context.l10n.scheduleGenerationNotice),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('saveSalaryScheduleButton'),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(
                _saving
                    ? context.l10n.saving
                    : context.l10n.saveScheduleVersion,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _initializeForEdit(EffectiveSalarySchedule schedule) {
    if (_initializedForEdit) return;
    _initializedForEdit = true;
    _effectiveFrom = schedule.effectiveFrom;
    _startOffset = schedule.schedule.paymentWindowStartMonthOffset;
    _endOffset = schedule.schedule.paymentMonthOffset;
    _startDay.text = schedule.schedule.paymentWindowStartDay.toString();
    _endDay.text = schedule.schedule.paymentWindowEndDay.toString();
  }

  DropdownButtonFormField<int> _monthDropdown({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: <DropdownMenuItem<int>>[
        DropdownMenuItem(value: 0, child: Text(context.l10n.sameMonth)),
        DropdownMenuItem(value: 1, child: Text(context.l10n.followingMonth)),
      ],
      onChanged: (selected) => onChanged(selected ?? 1),
    );
  }

  String? _validateDay(String? value) {
    final day = int.tryParse(value ?? '');
    return day == null || day < 1 || day > 31
        ? context.l10n.dayFromOneToThirtyOne
        : null;
  }

  Future<void> _pickEffectiveMonth() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom,
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: context.l10n.selectEffectiveMonthHelp,
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
        SnackBar(content: Text(context.l10n.paymentWindowMustFollowStart)),
      );
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    try {
      final repository = ref.read(salaryScheduleRepositoryProvider);
      final schedule = EffectiveSalarySchedule(
        id: widget.scheduleId ?? 'schedule-${now.microsecondsSinceEpoch}',
        effectiveFrom: _effectiveFrom,
        schedule: SalarySchedule(
          paymentMonthOffset: _endOffset,
          paymentWindowStartMonthOffset: _startOffset,
          paymentWindowStartDay: startDay,
          paymentWindowEndDay: endDay,
        ),
      );
      if (widget.scheduleId == null) {
        await repository.save(
          organizationId: DriftInitialSetupRepository.organizationId,
          schedule: schedule,
          createdAt: now,
          updatedAt: now,
        );
      } else {
        await repository.updateUnused(
          organizationId: DriftInitialSetupRepository.organizationId,
          schedule: schedule,
          updatedAt: now,
        );
      }
      ref.invalidate(salaryScheduleHistoryProvider);
      ref.invalidate(salaryScheduleEditableProvider);
      ref.invalidate(pfAutomationRunProvider);
      if (mounted) context.pop();
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.scheduleSaveError)));
      }
    }
  }
}
