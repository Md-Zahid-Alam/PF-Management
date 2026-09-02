import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/database/drift_repositories.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class ProfitFormScreen extends ConsumerStatefulWidget {
  const ProfitFormScreen({this.profitId, super.key});

  final String? profitId;

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
      appBar: AppBar(title: Text(editing ? 'Edit Profit' : 'Add Profit')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              TextFormField(
                key: const Key('profitAmountField'),
                controller: _amount,
                decoration: const InputDecoration(
                  labelText: 'Profit amount',
                  prefixText: '৳ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _validateAmount,
              ),
              const SizedBox(height: 12),
              _DateTile(
                label: 'Credited date',
                value: _creditedDate,
                required: true,
                onTap: () => _pickDate(
                  initial: _creditedDate,
                  onSelected: (date) => _creditedDate = date,
                ),
              ),
              _DateTile(
                label: 'Period start (optional)',
                value: _periodStart,
                onTap: () => _pickDate(
                  initial: _periodStart ?? _creditedDate,
                  onSelected: (date) => _periodStart = date,
                ),
                onClear: () => setState(() => _periodStart = null),
              ),
              _DateTile(
                label: 'Period end (optional)',
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
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Period end must not be before period start.',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              TextFormField(
                controller: _rate,
                decoration: const InputDecoration(
                  labelText: 'Profit rate (optional)',
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
                decoration: const InputDecoration(
                  labelText: 'Calculation method (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sourceReference,
                decoration: const InputDecoration(
                  labelText: 'Statement/reference (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes'),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('saveProfitButton'),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save profit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateAmount(String? value) {
    try {
      return Money.parse(value ?? '').minorUnits > 0
          ? null
          : 'Enter an amount greater than zero';
    } on FormatException {
      return 'Enter a valid profit amount';
    }
  }

  String? _validateRate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    try {
      final rate = Rate.fromPercent(value);
      return rate.partsPerMillion < 0 ? 'Rate cannot be negative' : null;
    } on Object {
      return 'Enter a valid percentage';
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
      amount: Money.parse(_amount.text),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the profit entry.')),
        );
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
        value == null ? 'Not set' : DateFormat.yMMMd().format(value!),
      ),
      trailing: value != null && !required
          ? IconButton(
              tooltip: 'Clear date',
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
