import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/database/drift_repositories.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class ProfitFormScreen extends ConsumerStatefulWidget {
  const ProfitFormScreen({this.profitId, this.currencyCode = 'BDT', super.key});

  final String? profitId;
  final String currencyCode;

  @override
  ConsumerState<ProfitFormScreen> createState() => _ProfitFormScreenState();
}

class _ProfitFormScreenState extends ConsumerState<ProfitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _rate = TextEditingController();
  final _calculationMethod = TextEditingController();
  final _sourceReference = TextEditingController();
  final _notes = TextEditingController();
  var _creditedDate = DateTime.now();
  DateTime? _periodStart;
  DateTime? _periodEnd;
  StoredProfitRecord? _original;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.profitId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _rate.dispose();
    _calculationMethod.dispose();
    _sourceReference.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.profitId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? context.l10n.editProfit : context.l10n.addProfit),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  key: const Key('profitAmountField'),
                  controller: _amount,
                  decoration: InputDecoration(
                    labelText: context.l10n.profitAmount,
                    prefixText: '${widget.currencyCode} ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validateAmount,
                ),
                const SizedBox(height: 12),
                _DateTile(
                  label: context.l10n.creditedDate,
                  value: _creditedDate,
                  required: true,
                  onTap: () => _pickDate(
                    initial: _creditedDate,
                    onSelected: (date) => _creditedDate = date,
                  ),
                ),
                _DateTile(
                  label: context.l10n.periodStartOptional,
                  value: _periodStart,
                  onTap: () => _pickDate(
                    initial: _periodStart ?? _creditedDate,
                    onSelected: (date) => _periodStart = date,
                  ),
                  onClear: () => setState(() => _periodStart = null),
                ),
                _DateTile(
                  label: context.l10n.periodEndOptional,
                  value: _periodEnd,
                  onTap: () => _pickDate(
                    initial: _periodEnd ?? _creditedDate,
                    onSelected: (date) => _periodEnd = date,
                  ),
                  onClear: () => setState(() => _periodEnd = null),
                ),
                if (_periodStart != null &&
                    _periodEnd != null &&
                    _periodEnd!.isBefore(_periodStart!))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      context.l10n.periodEndBeforeStartError,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                TextFormField(
                  controller: _rate,
                  decoration: InputDecoration(
                    labelText: context.l10n.profitRateOptional,
                    suffixText: '%',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validateRate,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _calculationMethod,
                  decoration: InputDecoration(
                    labelText: context.l10n.calculationMethodOptional,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sourceReference,
                  decoration: InputDecoration(
                    labelText: context.l10n.statementReferenceOptional,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  decoration: InputDecoration(labelText: context.l10n.notes),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('saveProfitButton'),
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving ? context.l10n.saving : context.l10n.saveProfit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validateAmount(String? value) {
    try {
      return Money.parse(
                value ?? '',
                currencyCode:
                    _original?.amount.currencyCode ?? widget.currencyCode,
              ).minorUnits >=
              0
          ? null
          : context.l10n.profitAmountNegativeError;
    } on FormatException {
      return context.l10n.validProfitAmountError;
    }
  }

  String? _validateRate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    try {
      final rate = Rate.fromPercent(value);
      return rate.partsPerMillion < 0 ? context.l10n.rateNegativeError : null;
    } on Object {
      return context.l10n.validPercentageError;
    }
  }

  Future<void> _load() async {
    final items = await ref.read(profitHistoryProvider.future);
    for (final item in items) {
      if (item.id == widget.profitId && mounted) {
        setState(() {
          _original = item;
          _amount.text = _moneyInput(item.amount);
          _creditedDate = item.creditedDate;
          _periodStart = item.periodStart;
          _periodEnd = item.periodEnd;
          _rate.text = item.optionalRate == null
              ? ''
              : _rateInput(item.optionalRate!);
          _calculationMethod.text = item.calculationMethod ?? '';
          _sourceReference.text = item.sourceReference ?? '';
          _notes.text = item.notes ?? '';
        });
        return;
      }
    }
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null && mounted) {
      setState(() => onSelected(selected));
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) ||
        (_periodStart != null &&
            _periodEnd != null &&
            _periodEnd!.isBefore(_periodStart!))) {
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final original = _original;
    final record = StoredProfitRecord(
      id: original?.id ?? 'profit-${now.microsecondsSinceEpoch}',
      employmentId: DriftInitialSetupRepository.employmentId,
      creditedDate: _creditedDate,
      amount: Money.parse(
        _amount.text,
        currencyCode: original?.amount.currencyCode ?? widget.currencyCode,
      ),
      periodStart: _periodStart,
      periodEnd: _periodEnd,
      optionalRate: _rate.text.trim().isEmpty
          ? null
          : Rate.fromPercent(_rate.text),
      calculationMethod: _textOrNull(_calculationMethod.text),
      sourceReference: _textOrNull(_sourceReference.text),
      notes: _textOrNull(_notes.text),
      createdAt: original?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      await ref.read(profitRepositoryProvider).save(record);
      ref.invalidate(profitHistoryProvider);
      if (mounted) {
        context.pop();
      }
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.profitSaveError)));
      }
    }
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.required = false,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final bool required;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        value == null
            ? context.l10n.notSet
            : DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
                  .format(value!),
      ),
      trailing: value != null && !required
          ? IconButton(
              tooltip: context.l10n.clearDate,
              onPressed: onClear,
              icon: const Icon(Icons.clear),
            )
          : const Icon(Icons.calendar_today_outlined),
      onTap: onTap,
    );
  }
}

String? _textOrNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _moneyInput(Money money) {
  if (money.decimalPlaces == 0) {
    return money.minorUnits.toString();
  }
  final scale = _powerOfTen(money.decimalPlaces);
  final absolute = money.minorUnits.abs();
  final sign = money.minorUnits < 0 ? '-' : '';
  final fraction = (absolute % scale).toString().padLeft(
    money.decimalPlaces,
    '0',
  );
  return '$sign${absolute ~/ scale}.$fraction';
}

String _rateInput(Rate rate) {
  final negative = rate.partsPerMillion < 0;
  final absolute = rate.partsPerMillion.abs();
  final whole = absolute ~/ 10000;
  final fraction = (absolute % 10000).toString().padLeft(4, '0');
  final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
  return '${negative ? '-' : ''}$whole${trimmed.isEmpty ? '' : '.$trimmed'}';
}

int _powerOfTen(int exponent) {
  var result = 1;
  for (var index = 0; index < exponent; index++) {
    result *= 10;
  }
  return result;
}
