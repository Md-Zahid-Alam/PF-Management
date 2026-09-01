import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/presentation/formatters.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class MonthlyRecordDetailScreen extends ConsumerWidget {
  const MonthlyRecordDetailScreen({required this.recordId, super.key});

  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(monthlyPFRecordsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('PF Record Details')),
      body: records.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            const Center(child: Text('Could not load this PF record.')),
        data: (items) {
          final record = _findRecord(items);
          if (record == null) {
            return const Center(child: Text('PF record not found.'));
          }
          return _RecordDetails(
            record: record,
            onAdjust: () => context.push('/records/$recordId/adjust'),
            onConfirm: record.status == 'confirmed'
                ? null
                : () => _confirm(context, ref, record),
          );
        },
      ),
    );
  }

  StoredMonthlyPFRecord? _findRecord(List<StoredMonthlyPFRecord> items) {
    for (final item in items) {
      if (item.id == recordId) {
        return item;
      }
    }
    return null;
  }

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    StoredMonthlyPFRecord record,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm PF record?'),
        content: const Text(
          'Confirm that you have reviewed this calculated record. You can still preserve an audited adjustment later.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) {
      return;
    }
    await ref
        .read(monthlyPFRepositoryProvider)
        .confirm(record.id, DateTime.now());
    ref.invalidate(monthlyPFRecordsProvider);
  }
}

class _RecordDetails extends StatelessWidget {
  const _RecordDetails({
    required this.record,
    required this.onAdjust,
    required this.onConfirm,
  });

  final StoredMonthlyPFRecord record;
  final VoidCallback onAdjust;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final total = record.employeeContribution + record.employerContribution;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Text(
          DateFormat.yMMMM().format(record.month.firstDay),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Chip(label: Text(formatPFStatus(record.status))),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: <Widget>[
                _DetailRow(
                  label: 'Gross salary',
                  value: formatMoney(record.grossSalary),
                ),
                _DetailRow(
                  label: 'Basic salary',
                  value: formatMoney(record.basicSalary),
                ),
                _DetailRow(
                  label: 'Employee contribution',
                  value: formatMoney(record.employeeContribution),
                ),
                _DetailRow(
                  label: 'Company contribution',
                  value: formatMoney(record.employerContribution),
                ),
                _DetailRow(
                  label: 'Other adjustment',
                  value: formatMoney(record.adjustment),
                ),
                const Divider(),
                _DetailRow(
                  label: 'Total contribution',
                  value: formatMoney(total),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: <Widget>[
                _DetailRow(label: 'Source', value: record.source),
                _DetailRow(
                  label: 'Scheduled generation',
                  value: _date(record.scheduledGenerationDate),
                ),
                _DetailRow(
                  label: 'Actual generation',
                  value: _date(record.actualGenerationDate),
                ),
                _DetailRow(
                  label: 'Salary credited',
                  value: _date(record.salaryCreditedDate),
                ),
              ],
            ),
          ),
        ),
        if (record.originalGrossSalary != null) ...<Widget>[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Original calculation',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _DetailRow(
                    label: 'Original gross',
                    value: formatMoney(record.originalGrossSalary!),
                  ),
                  _DetailRow(
                    label: 'Original employee PF',
                    value: formatMoney(record.originalEmployeeContribution!),
                  ),
                  _DetailRow(
                    label: 'Original company PF',
                    value: formatMoney(record.originalEmployerContribution!),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onAdjust,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Adjust record'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onConfirm,
          icon: const Icon(Icons.verified_outlined),
          label: Text(
            onConfirm == null ? 'Record confirmed' : 'Confirm record',
          ),
        ),
      ],
    );
  }

  static String _date(DateTime? date) {
    return date == null ? 'Not recorded' : DateFormat.yMMMd().format(date);
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}
