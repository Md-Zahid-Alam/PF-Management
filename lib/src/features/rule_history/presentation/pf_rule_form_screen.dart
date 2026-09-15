import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/database/drift_repositories.dart';
import 'package:pf_tracker/src/core/domain/calculation_policy.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class PFRuleFormScreen extends ConsumerStatefulWidget {
  const PFRuleFormScreen({this.ruleId, this.sourceRuleId, super.key});

  final String? ruleId;
  final String? sourceRuleId;

  @override
  ConsumerState<PFRuleFormScreen> createState() => _PFRuleFormScreenState();
}

class _PFRuleFormScreenState extends ConsumerState<PFRuleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _basicRate = TextEditingController(text: '60');
  final _employeeRate = TextEditingController(text: '10');
  final _employerRate = TextEditingController(text: '10');
  final _maturityMonths = TextEditingController(text: '24');
  final _notes = TextEditingController();
  var _effectiveFrom = DateTime.now();
  var _maturityBasis = MaturityBasis.joiningDate;
  var _partialMonthPolicy = PartialMonthPolicy.fullContribution;
  var _effectiveVersionPolicy = EffectiveVersionPolicy.monthEnd;
  var _beforeMaturity = false;
  var _afterMaturity = true;
  var _saving = false;
  StoredPFRule? _original;

  @override
  void initState() {
    super.initState();
    if (widget.ruleId != null || widget.sourceRuleId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  void dispose() {
    _basicRate.dispose();
    _employeeRate.dispose();
    _employerRate.dispose();
    _maturityMonths.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.ruleId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit PF Rule' : 'New PF Rule Version'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Effective from'),
                  subtitle: Text(DateFormat.yMMMd().format(_effectiveFrom)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 12),
                _PercentageField(
                  fieldKey: const Key('basicRateField'),
                  controller: _basicRate,
                  label: 'Basic salary percentage',
                ),
                const SizedBox(height: 12),
                _PercentageField(
                  fieldKey: const Key('employeeRateField'),
                  controller: _employeeRate,
                  label: 'Employee PF percentage',
                ),
                const SizedBox(height: 12),
                _PercentageField(
                  fieldKey: const Key('employerRateField'),
                  controller: _employerRate,
                  label: 'Employer PF percentage',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('maturityMonthsField'),
                  controller: _maturityMonths,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Maturity period',
                    suffixText: 'months',
                  ),
                  validator: (value) {
                    final months = int.tryParse(value ?? '');
                    return months == null || months < 0
                        ? 'Enter a valid maturity period'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<MaturityBasis>(
                  initialValue: _maturityBasis,
                  decoration: const InputDecoration(
                    labelText: 'Maturity basis',
                  ),
                  items: const <DropdownMenuItem<MaturityBasis>>[
                    DropdownMenuItem(
                      value: MaturityBasis.joiningDate,
                      child: Text('Joining date'),
                    ),
                    DropdownMenuItem(
                      value: MaturityBasis.pfStartDate,
                      child: Text('PF start date'),
                    ),
                    DropdownMenuItem(
                      value: MaturityBasis.permanentDate,
                      child: Text('Permanent employee date'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _maturityBasis = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Partial PF-start month'),
                  subtitle: Text('Full contribution'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<EffectiveVersionPolicy>(
                  initialValue: _effectiveVersionPolicy,
                  decoration: const InputDecoration(
                    labelText: 'Mid-month rule selection',
                  ),
                  items: const <DropdownMenuItem<EffectiveVersionPolicy>>[
                    DropdownMenuItem(
                      value: EffectiveVersionPolicy.monthEnd,
                      child: Text('Rule active at month end'),
                    ),
                    DropdownMenuItem(
                      value: EffectiveVersionPolicy.monthStart,
                      child: Text('Rule active at month start'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _effectiveVersionPolicy = value);
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Employer PF entitled before maturity'),
                  value: _beforeMaturity,
                  onChanged: (value) => setState(() => _beforeMaturity = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Employer PF entitled after maturity'),
                  value: _afterMaturity,
                  onChanged: (value) => setState(() => _afterMaturity = value),
                ),
                TextFormField(
                  controller: _notes,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('savePFRuleButton'),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save rule version'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _load() async {
    final id = widget.ruleId ?? widget.sourceRuleId;
    final history = await ref.read(pfRuleHistoryProvider.future);
    for (final stored in history) {
      if (stored.rule.id == id && mounted) {
        setState(() {
          _original = widget.ruleId == null ? null : stored;
          _basicRate.text = _rateInput(stored.rule.basicSalaryRate);
          _employeeRate.text = _rateInput(stored.rule.employeePFRate);
          _employerRate.text = _rateInput(stored.rule.employerPFRate);
          _maturityMonths.text = stored.rule.maturityMonths.toString();
          _maturityBasis = stored.rule.maturityBasis;
          _partialMonthPolicy = PartialMonthPolicy.fullContribution;
          _effectiveVersionPolicy = stored.effectiveVersionPolicy;
          _beforeMaturity = stored.rule.employerEntitledBeforeMaturity;
          _afterMaturity = stored.rule.employerEntitledAfterMaturity;
          _notes.text = stored.notes ?? '';
          if (widget.ruleId != null) {
            _effectiveFrom = stored.rule.effectiveFrom;
          }
        });
        return;
      }
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom,
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null && mounted) {
      setState(() => _effectiveFrom = selected);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final original = _original;
    final stored = StoredPFRule(
      rule: PFRuleVersion(
        id: original?.rule.id ?? 'pf-rule-${now.microsecondsSinceEpoch}',
        effectiveFrom: _effectiveFrom,
        basicSalaryRate: Rate.fromPercent(_basicRate.text),
        employeePFRate: Rate.fromPercent(_employeeRate.text),
        employerPFRate: Rate.fromPercent(_employerRate.text),
        maturityMonths: int.parse(_maturityMonths.text),
        maturityBasis: _maturityBasis,
        employerEntitledBeforeMaturity: _beforeMaturity,
        employerEntitledAfterMaturity: _afterMaturity,
      ),
      organizationId: DriftInitialSetupRepository.organizationId,
      partialMonthPolicy: _partialMonthPolicy,
      effectiveVersionPolicy: _effectiveVersionPolicy,
      createdAt: original?.createdAt ?? now,
      updatedAt: now,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    try {
      await ref.read(pfRuleRepositoryProvider).save(stored);
      ref.invalidate(pfRuleHistoryProvider);
      ref.invalidate(pfAutomationRunProvider);
      if (mounted) {
        context.pop();
      }
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the rule. Check the effective date.'),
          ),
        );
      }
    }
  }
}

class _PercentageField extends StatelessWidget {
  const _PercentageField({
    required this.controller,
    required this.label,
    this.fieldKey,
  });

  final TextEditingController controller;
  final String label;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: '%'),
      validator: (value) {
        try {
          final rate = Rate.fromPercent(value ?? '');
          return rate.partsPerMillion < 0
              ? 'Percentage cannot be negative'
              : null;
        } on Object {
          return 'Enter a valid percentage';
        }
      },
    );
  }
}

String _rateInput(Rate rate) {
  final value = rate.partsPerMillion / 10000;
  return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 4);
}
