import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/presentation/formatters.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class MonthlyRecordDetailScreen extends ConsumerWidget {
  const MonthlyRecordDetailScreen({required this.recordId, super.key});

  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(monthlyPFRecordsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.pfRecordDetails)),
      body: records.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text(context.l10n.recordLoadError)),
        data: (items) {
          final record = _findRecord(items);
          if (record == null) {
            return Center(child: Text(context.l10n.recordNotFound));
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
        title: Text(context.l10n.confirmPFRecordTitle),
        content: Text(context.l10n.confirmPFRecordMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.confirm),
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
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      children: <Widget>[
        Text(
          _formatMonth(context, record.month.firstDay),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Chip(label: Text(_statusLabel(context, record.status))),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: <Widget>[
                _DetailRow(
                  label: context.l10n.grossSalary,
                  value: formatMoney(record.grossSalary),
                ),
                _DetailRow(
                  label: context.l10n.basicSalary,
                  value: formatMoney(record.basicSalary),
                ),
                _DetailRow(
                  label: context.l10n.employeeContribution,
                  value: formatMoney(record.employeeContribution),
                ),
                _DetailRow(
                  label: context.l10n.companyContribution,
                  value: formatMoney(record.employerContribution),
                ),
                _DetailRow(
                  label: context.l10n.otherAdjustment,
                  value: formatMoney(record.adjustment),
                ),
                const Divider(),
                _DetailRow(
                  label: context.l10n.totalContribution,
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
                _DetailRow(
                  label: context.l10n.source,
                  value: _sourceLabel(context, record.source),
                ),
                _DetailRow(
                  label: context.l10n.scheduledGeneration,
                  value: _date(context, record.scheduledGenerationDate),
                ),
                _DetailRow(
                  label: context.l10n.actualGeneration,
                  value: _date(context, record.actualGenerationDate),
                ),
                _DetailRow(
                  label: context.l10n.salaryCredited,
                  value: _date(context, record.salaryCreditedDate),
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
                    context.l10n.originalCalculation,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _DetailRow(
                    label: context.l10n.originalGross,
                    value: formatMoney(record.originalGrossSalary!),
                  ),
                  _DetailRow(
                    label: context.l10n.originalEmployeePF,
                    value: formatMoney(record.originalEmployeeContribution!),
                  ),
                  _DetailRow(
                    label: context.l10n.originalCompanyPF,
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
          label: Text(context.l10n.adjustRecord),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onConfirm,
          icon: const Icon(Icons.verified_outlined),
          label: Text(
            onConfirm == null
                ? context.l10n.recordConfirmed
                : context.l10n.confirmRecord,
          ),
        ),
      ],
    );
  }

  static String _date(BuildContext context, DateTime? date) {
    return date == null
        ? context.l10n.notRecorded
        : DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
              .format(date);
  }
}

String _formatMonth(BuildContext context, DateTime date) =>
    DateFormat.yMMMM(Localizations.localeOf(context).toLanguageTag())
        .format(date);

String _statusLabel(BuildContext context, String status) => switch (status) {
  'automaticallyCalculated' => context.l10n.automatic,
  'manuallyCalculated' => context.l10n.manual,
  'manuallyAdjusted' => context.l10n.adjusted,
  'confirmed' => context.l10n.confirmed,
  _ => formatPFStatus(status),
};

String _sourceLabel(BuildContext context, String source) => switch (source) {
  'historicalAutomatic' => context.l10n.historicalAutomatic,
  'automatic' => context.l10n.automaticSource,
  'manual' => context.l10n.manualSource,
  _ => source,
};

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
