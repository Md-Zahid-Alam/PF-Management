import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/database/drift_repositories.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';
import 'package:pf_tracker/src/features/reports/presentation/pf_reports_screen.dart';

class ActualStatementFormScreen extends ConsumerStatefulWidget {
  const ActualStatementFormScreen({required this.startYear, super.key});

  final int startYear;

  @override
  ConsumerState<ActualStatementFormScreen> createState() =>
      _ActualStatementFormScreenState();
}

class _ActualStatementFormScreenState
    extends ConsumerState<ActualStatementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _opening = TextEditingController();
  final _employee = TextEditingController();
  final _employer = TextEditingController();
  final _profit = TextEditingController();
  final _adjustments = TextEditingController();
  final _closing = TextEditingController();
  final _notes = TextEditingController();
  StoredActualPFStatement? _original;
  DateTime? _statementDate;
  var _saving = false;
  var _emptyStatement = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _opening,
      _employee,
      _employer,
      _profit,
      _adjustments,
      _closing,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Actual Statement ${widget.startYear}–${(widget.startYear + 1).toString().substring(2)}',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  'Enter values exactly as shown on the official statement. Blank fields remain unknown and do not produce a difference.',
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Statement date (optional)'),
                  subtitle: Text(
                    _statementDate == null
                        ? 'Not specified'
                        : DateFormat.yMMMd().format(_statementDate!),
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _pickDate,
                ),
                _moneyField(_opening, 'Opening balance'),
                _moneyField(_employee, 'Employee contribution'),
                _moneyField(_employer, 'Employer contribution'),
                _moneyField(_profit, 'Profit'),
                _moneyField(_adjustments, 'Adjustments'),
                _moneyField(
                  _closing,
                  'Closing balance',
                  key: const Key('actualClosingBalanceField'),
                ),
                if (_emptyStatement)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Enter at least one official statement amount.',
                      style: TextStyle(color: Colors.red),
                    ),
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
                  key: const Key('saveActualStatementButton'),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save actual statement'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _moneyField(
    TextEditingController controller,
    String label, {
    Key? key,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: key,
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        decoration: InputDecoration(labelText: label, prefixText: '৳ '),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return null;
          try {
            Money.parse(value);
            return null;
          } on Object {
            return 'Enter a valid whole BDT amount';
          }
        },
      ),
    );
  }

  Future<void> _load() async {
    final statements = await ref.read(actualPFStatementsProvider.future);
    for (final statement in statements) {
      if (statement.statementStartYear == widget.startYear && mounted) {
        setState(() {
          _original = statement;
          _statementDate = statement.statementDate;
          _opening.text = _input(statement.snapshot.openingBalance);
          _employee.text = _input(statement.snapshot.employeeContribution);
          _employer.text = _input(statement.snapshot.employerContribution);
          _profit.text = _input(statement.snapshot.profit);
          _adjustments.text = _input(statement.snapshot.adjustments);
          _closing.text = _input(statement.snapshot.closingBalance);
          _notes.text = statement.notes ?? '';
        });
        return;
      }
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _statementDate ?? DateTime(widget.startYear + 1, 6, 30),
      firstDate: DateTime(widget.startYear),
      lastDate: DateTime(widget.startYear + 2),
    );
    if (selected != null && mounted) setState(() => _statementDate = selected);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_hasAnyAmount()) {
      setState(() => _emptyStatement = true);
      return;
    }
    if (_emptyStatement) setState(() => _emptyStatement = false);
    setState(() => _saving = true);
    final now = DateTime.now();
    final original = _original;
    final statement = StoredActualPFStatement(
      id: original?.id ?? 'actual-statement-${widget.startYear}',
      employmentId: DriftInitialSetupRepository.employmentId,
      statementStartYear: widget.startYear,
      statementDate: _statementDate,
      snapshot: StatementSnapshot(
        openingBalance: _money(_opening.text),
        employeeContribution: _money(_employee.text),
        employerContribution: _money(_employer.text),
        profit: _money(_profit.text),
        adjustments: _money(_adjustments.text),
        closingBalance: _money(_closing.text),
      ),
      decimalPlaces: 0,
      currencyCode: 'BDT',
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      createdAt: original?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      await ref.read(actualPFStatementRepositoryProvider).save(statement);
      ref.invalidate(actualPFStatementsProvider);
      ref.invalidate(pfStatementReportsProvider);
      if (mounted) context.pop();
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save actual statement.')),
        );
      }
    }
  }

  bool _hasAnyAmount() => <TextEditingController>[
    _opening,
    _employee,
    _employer,
    _profit,
    _adjustments,
    _closing,
  ].any((controller) => controller.text.trim().isNotEmpty);
}

Money? _money(String value) => value.trim().isEmpty ? null : Money.parse(value);

String _input(Money? value) => value?.minorUnits.toString() ?? '';
