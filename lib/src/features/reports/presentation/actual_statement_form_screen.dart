import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/database/drift_repositories.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';
import 'package:pf_tracker/src/features/reports/presentation/pf_reports_screen.dart';

class ActualStatementFormScreen extends ConsumerStatefulWidget {
  const ActualStatementFormScreen({
    required this.startYear,
    this.currencyCode = 'BDT',
    super.key,
  });

  final int startYear;
  final String currencyCode;

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
          context.l10n.actualStatementTitle(
            widget.startYear,
            (widget.startYear + 1).toString().substring(2),
          ),
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
                Text(context.l10n.actualStatementInstructions),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.statementDateOptional),
                  subtitle: Text(
                    _statementDate == null
                        ? context.l10n.notSpecified
                        : DateFormat.yMMMd(
                            Localizations.localeOf(context).toLanguageTag(),
                          ).format(_statementDate!),
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _pickDate,
                ),
                _moneyField(_opening, context.l10n.openingBalance),
                _moneyField(_employee, context.l10n.employeeContribution),
                _moneyField(_employer, context.l10n.employerContribution),
                _moneyField(_profit, context.l10n.profit),
                _moneyField(_adjustments, context.l10n.adjustments),
                _moneyField(
                  _closing,
                  context.l10n.closingBalance,
                  key: const Key('actualClosingBalanceField'),
                ),
                if (_emptyStatement)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      context.l10n.atLeastOneStatementAmount,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                TextFormField(
                  controller: _notes,
                  decoration: InputDecoration(
                    labelText: context.l10n.notesOptional,
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('saveActualStatementButton'),
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving
                        ? context.l10n.saving
                        : context.l10n.saveActualStatement,
                  ),
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
        decoration: InputDecoration(
          labelText: label,
          prefixText: '${_original?.currencyCode ?? widget.currencyCode} ',
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return null;
          }
          try {
            _money(value);
            return null;
          } on Object {
            return context.l10n.validWholeBDTAmount;
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
    if (selected != null && mounted) {
      setState(() => _statementDate = selected);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!_hasAnyAmount()) {
      setState(() => _emptyStatement = true);
      return;
    }
    if (_emptyStatement) {
      setState(() => _emptyStatement = false);
    }
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
      currencyCode: original?.currencyCode ?? widget.currencyCode,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      createdAt: original?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      await ref.read(actualPFStatementRepositoryProvider).save(statement);
      ref.invalidate(actualPFStatementsProvider);
      ref.invalidate(pfStatementReportsProvider);
      if (mounted) {
        context.pop();
      }
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.actualStatementSaveError)),
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

  Money? _money(String value) => value.trim().isEmpty
      ? null
      : Money.parse(
          value,
          currencyCode: _original?.currencyCode ?? widget.currencyCode,
        );
}

String _input(Money? value) => value?.minorUnits.toString() ?? '';
