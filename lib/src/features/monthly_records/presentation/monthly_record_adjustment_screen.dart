import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class MonthlyRecordAdjustmentScreen extends ConsumerStatefulWidget {
  const MonthlyRecordAdjustmentScreen({required this.recordId, super.key});

  final String recordId;

  @override
  ConsumerState<MonthlyRecordAdjustmentScreen> createState() =>
      _MonthlyRecordAdjustmentScreenState();
}

class _MonthlyRecordAdjustmentScreenState
    extends ConsumerState<MonthlyRecordAdjustmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _gross = TextEditingController();
  final _basic = TextEditingController();
  final _employee = TextEditingController();
  final _employer = TextEditingController();
  final _adjustment = TextEditingController();
  final _notes = TextEditingController();
  StoredMonthlyPFRecord? _record;
  DateTime? _salaryCreditedDate;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _gross,
      _basic,
      _employee,
      _employer,
      _adjustment,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    return Scaffold(
      appBar: AppBar(title: const Text('Adjust PF Record')),
      body: record == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: <Widget>[
                    Text(
                      DateFormat.yMMMM().format(record.month.firstDay),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The original calculated values will be retained for audit and comparison.',
                    ),
                    const SizedBox(height: 20),
                    _moneyField(_gross, 'Gross salary'),
                    const SizedBox(height: 12),
                    _moneyField(_basic, 'Basic salary'),
                    const SizedBox(height: 12),
                    _moneyField(_employee, 'Employee PF contribution'),
                    const SizedBox(height: 12),
                    _moneyField(_employer, 'Company PF contribution'),
                    const SizedBox(height: 12),
                    _moneyField(
                      _adjustment,
                      'Other adjustment',
                      allowNegative: true,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Salary credited date'),
                      subtitle: Text(
                        _salaryCreditedDate == null
                            ? 'Not recorded'
                            : DateFormat.yMMMd().format(_salaryCreditedDate!),
                      ),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: _pickSalaryDate,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notes,
                      decoration: const InputDecoration(
                        labelText: 'Adjustment notes (optional)',
                      ),
                      minLines: 2,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Saving…' : 'Save adjustment'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  TextFormField _moneyField(
    TextEditingController controller,
    String label, {
    bool allowNegative = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, prefixText: '৳ '),
      keyboardType: TextInputType.numberWithOptions(
        signed: allowNegative,
        decimal: true,
      ),
      validator: (value) {
        final number = double.tryParse(value ?? '');
        if (number == null || (!allowNegative && number < 0)) {
          return 'Enter a valid whole BDT amount';
        }
        return null;
      },
    );
  }

  Future<void> _load() async {
    final items = await ref.read(monthlyPFRecordsProvider.future);
    for (final item in items) {
      if (item.id == widget.recordId && mounted) {
        setState(() {
          _record = item;
          _gross.text = _editableAmount(item.grossSalary);
          _basic.text = _editableAmount(item.basicSalary);
          _employee.text = _editableAmount(item.employeeContribution);
          _employer.text = _editableAmount(item.employerContribution);
          _adjustment.text = _editableAmount(item.adjustment);
          _salaryCreditedDate = item.salaryCreditedDate;
          _notes.text = item.notes ?? '';
        });
        return;
      }
    }
  }

  Future<void> _pickSalaryDate() async {
    final record = _record!;
    final selected = await showDatePicker(
      context: context,
      initialDate: _salaryCreditedDate ?? record.month.lastDay,
      firstDate: record.month.firstDay,
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null && mounted) {
      setState(() => _salaryCreditedDate = selected);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final record = _record!;
    setState(() => _saving = true);
    final now = DateTime.now();
    final adjusted = StoredMonthlyPFRecord(
      id: record.id,
      employmentId: record.employmentId,
      month: record.month,
      grossSalary: _parseLike(_gross.text, record.grossSalary),
      basicSalary: _parseLike(_basic.text, record.basicSalary),
      employeeContribution: _parseLike(
        _employee.text,
        record.employeeContribution,
      ),
      employerContribution: _parseLike(
        _employer.text,
        record.employerContribution,
      ),
      adjustment: _parseLike(_adjustment.text, record.adjustment),
      basicRate: record.basicRate,
      employeeRate: record.employeeRate,
      employerRate: record.employerRate,
      source: 'manual',
      status: 'manuallyAdjusted',
      createdAt: record.createdAt,
      updatedAt: now,
      salaryHistoryId: record.salaryHistoryId,
      ruleVersionId: record.ruleVersionId,
      salaryCreditedDate: _salaryCreditedDate,
      scheduledGenerationDate: record.scheduledGenerationDate,
      actualGenerationDate: record.actualGenerationDate,
      originalGrossSalary: record.originalGrossSalary,
      originalBasicSalary: record.originalBasicSalary,
      originalEmployeeContribution: record.originalEmployeeContribution,
      originalEmployerContribution: record.originalEmployerContribution,
      manuallyAdjustedAt: now,
      confirmedAt: null,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    try {
      await ref
          .read(monthlyPFRepositoryProvider)
          .saveManualAdjustment(adjusted);
      ref.invalidate(monthlyPFRecordsProvider);
      if (mounted) {
        context.pop();
      }
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save this adjustment.')),
        );
      }
    }
  }

  static String _editableAmount(Money money) {
    if (money.decimalPlaces == 0) {
      return money.minorUnits.toString();
    }
    final negative = money.minorUnits.isNegative;
    final digits = money.minorUnits.abs().toString().padLeft(
      money.decimalPlaces + 1,
      '0',
    );
    final split = digits.length - money.decimalPlaces;
    return '${negative ? '-' : ''}${digits.substring(0, split)}.${digits.substring(split)}';
  }

  static Money _parseLike(String value, Money prototype) {
    return Money.parse(
      value,
      decimalPlaces: prototype.decimalPlaces,
      currencyCode: prototype.currencyCode,
    );
  }
}
