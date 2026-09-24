import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/database/drift_repositories.dart';
import 'package:pf_tracker/src/core/domain/automation_models.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class SalaryScheduleHistoryScreen extends ConsumerWidget {
  const SalaryScheduleHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(salaryScheduleHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.salaryScheduleHistory)),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(salaryScheduleHistoryProvider),
            icon: const Icon(Icons.refresh),
            label: Text(context.l10n.retryScheduleHistory),
          ),
        ),
        data: (items) => ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final schedule = items[items.length - 1 - index];
            final editable = ref.watch(
              salaryScheduleEditableProvider(schedule.id),
            );
            final canEdit = editable.asData?.value == true;
            return _ScheduleCard(
              schedule: schedule,
              isCurrent: index == 0,
              onEdit: canEdit
                  ? () => context.push(
                      '/salary-schedule-history/${schedule.id}/edit',
                    )
                  : null,
              onDelete: canEdit
                  ? () => _delete(context, ref, schedule)
                  : null,
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/salary-schedule-history/add'),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.newSchedule),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    EffectiveSalarySchedule schedule,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteSalaryScheduleTitle),
        content: Text(
          context.l10n.deleteSalaryScheduleMessage(
            _formatDate(context, schedule.effectiveFrom),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(salaryScheduleRepositoryProvider)
          .deleteUnused(
            schedule.id,
            DriftInitialSetupRepository.organizationId,
          );
      ref.invalidate(salaryScheduleHistoryProvider);
      ref.invalidate(salaryScheduleEditableProvider);
      ref.invalidate(pfAutomationRunProvider);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.scheduleDeleteProtectedError)),
        );
      }
    }
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.isCurrent,
    required this.onEdit,
    required this.onDelete,
  });

  final EffectiveSalarySchedule schedule;
  final bool isCurrent;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final value = schedule.schedule;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
        leading: CircleAvatar(
          child: Icon(isCurrent ? Icons.schedule : Icons.history),
        ),
        title: Text(
          context.l10n.scheduleWindowDescription(
            _monthLabel(context, value.paymentWindowStartMonthOffset),
            value.paymentWindowStartDay,
            _monthLabel(context, value.paymentMonthOffset),
            value.paymentWindowEndDay,
          ),
        ),
        subtitle: Text(
          context.l10n.scheduleEffectiveDescription(
            _formatDate(context, schedule.effectiveFrom),
            isCurrent ? ' · ${context.l10n.current}' : '',
          ),
        ),
        isThreeLine: true,
        trailing: onEdit == null
            ? null
            : PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit?.call();
                  } else if (value == 'delete') {
                    onDelete?.call();
                  }
                },
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(context.l10n.edit),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(context.l10n.delete),
                  ),
                ],
              ),
      ),
    );
  }
}

String _monthLabel(BuildContext context, int offset) => offset == 0
    ? context.l10n.sameMonthLower
    : context.l10n.followingMonthLower;

String _formatDate(BuildContext context, DateTime date) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
        .format(date);
