import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/database/drift_repositories.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';
import 'package:pf_tracker/src/features/reports/presentation/pf_reports_screen.dart';

class StatementYearScreen extends ConsumerStatefulWidget {
  const StatementYearScreen({super.key});

  @override
  ConsumerState<StatementYearScreen> createState() =>
      _StatementYearScreenState();
}

class _StatementYearScreenState extends ConsumerState<StatementYearScreen> {
  var _startMonth = DateTime.july;
  var _startDay = 1;
  var _effectiveFrom = DateTime.now();
  var _saving = false;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(statementYearDefinitionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Statement Year')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Choose when the organization’s PF statement year starts. Existing definitions remain effective-dated.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _startMonth,
              decoration: const InputDecoration(labelText: 'Start month'),
              items: <DropdownMenuItem<int>>[
                for (var month = 1; month <= 12; month++)
                  DropdownMenuItem(
                    value: month,
                    child: Text(
                      DateFormat.MMMM().format(DateTime(2000, month)),
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _startMonth = value;
                    final maximum = _daysInMonth(value);
                    if (_startDay > maximum) _startDay = maximum;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _startDay,
              decoration: const InputDecoration(labelText: 'Start day'),
              items: <DropdownMenuItem<int>>[
                for (var day = 1; day <= _daysInMonth(_startMonth); day++)
                  DropdownMenuItem(value: day, child: Text('$day')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _startDay = value);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Effective from'),
              subtitle: Text(DateFormat.yMMMd().format(_effectiveFrom)),
              onTap: _pickDate,
            ),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save new definition'),
            ),
            const SizedBox(height: 24),
            Text('History', style: Theme.of(context).textTheme.titleLarge),
            history.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) =>
                  const Text('Could not load history.'),
              data: (items) => Column(
                children: <Widget>[
                  for (final item in items.reversed)
                    ListTile(
                      title: Text(
                        '${DateFormat.MMMM().format(DateTime(2000, item.configuration.startMonth))} ${item.configuration.startDay}',
                      ),
                      subtitle: Text(
                        'Effective ${DateFormat.yMMMd().format(item.effectiveFrom)}',
                      ),
                    ),
                  if (items.isEmpty)
                    const ListTile(title: Text('Default: July 1')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom,
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null && mounted) setState(() => _effectiveFrom = selected);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final now = DateTime.now();
    try {
      await ref
          .read(statementYearDefinitionRepositoryProvider)
          .save(
            StoredStatementYearDefinition(
              id: 'statement-year-${now.microsecondsSinceEpoch}',
              organizationId: DriftInitialSetupRepository.organizationId,
              effectiveFrom: _effectiveFrom,
              configuration: StatementYearConfiguration(
                startMonth: _startMonth,
                startDay: _startDay,
              ),
              createdAt: now,
              updatedAt: now,
            ),
          );
      ref.invalidate(statementYearDefinitionsProvider);
      ref.invalidate(pfStatementReportsProvider);
      if (mounted) context.pop();
    } on Object {
      if (mounted) setState(() => _saving = false);
    }
  }
}

int _daysInMonth(int month) => DateTime(2000, month + 1, 0).day;
