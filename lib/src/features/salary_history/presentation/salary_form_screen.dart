import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/database/drift_repositories.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class SalaryFormScreen extends ConsumerStatefulWidget {
  const SalaryFormScreen({this.salaryId, super.key});

  final String? salaryId;

  @override
  ConsumerState<SalaryFormScreen> createState() => _SalaryFormScreenState();
}

class _SalaryFormScreenState extends ConsumerState<SalaryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _grossSalary = TextEditingController();
  final _notes = TextEditingController();
  var _effectiveFrom = DateTime.now();
  var _saving = false;
  StoredSalary? _original;

  @override
  void initState() {
    super.initState();
    if (widget.salaryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  void dispose() {
    _grossSalary.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.salaryId != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit Salary' : 'Add Salary')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              TextFormField(
                key: const Key('salaryAmountField'),
                controller: _grossSalary,
                decoration: const InputDecoration(
                  labelText: 'Gross salary',
                  prefixText: '৳ ',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final amount = int.tryParse(value ?? '');
                  return amount == null || amount <= 0
                      ? 'Enter a salary greater than zero'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Effective date'),
                subtitle: Text(DateFormat.yMMMd().format(_effectiveFrom)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickDate,
              ),
              const SizedBox(height: 16),
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
                key: const Key('saveSalaryButton'),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save salary'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _load() async {
    final items = await ref.read(salaryHistoryProvider.future);
    for (final item in items) {
      if (item.id == widget.salaryId && mounted) {
        setState(() {
          _original = item;
          _grossSalary.text = item.grossSalary.minorUnits.toString();
          _effectiveFrom = item.effectiveFrom;
          _notes.text = item.notes ?? '';
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
    final salary = StoredSalary(
      id: original?.id ?? 'salary-${now.microsecondsSinceEpoch}',
      employmentId: DriftInitialSetupRepository.employmentId,
      effectiveFrom: _effectiveFrom,
      grossSalary: Money.parse(_grossSalary.text),
      createdAt: original?.createdAt ?? now,
      updatedAt: now,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    try {
      await ref.read(salaryRepositoryProvider).save(salary);
      ref.invalidate(salaryHistoryProvider);
      if (mounted) {
        context.pop();
      }
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save salary. Check the effective date.'),
          ),
        );
      }
    }
  }
}
