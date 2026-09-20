import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/database/drift_repositories.dart';
import 'package:pf_tracker/src/core/domain/automation_models.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class SalaryScheduleHistoryScreen extends ConsumerWidget {
  const SalaryScheduleHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(salaryScheduleHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Salary Schedule History')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(salaryScheduleHistoryProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry schedule history'),
          ),
        ),
        data: (items) => ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final schedule = items[items.length - 1 - index];
            return _ScheduleCard(
              schedule: schedule,
              isCurrent: index == 0,
              onDelete: () => _delete(context, ref, schedule),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/salary-schedule-history/add'),
        icon: const Icon(Icons.add),
        label: const Text('New schedule'),
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
        title: const Text('Delete salary schedule?'),
        content: Text(
          'Delete the schedule effective ${DateFormat.yMMMd().format(schedule.effectiveFrom)}? Schedules are protected after PF records exist.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
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
      ref.invalidate(pfAutomationRunProvider);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This schedule is required or PF records already exist.',
            ),
          ),
        );
      }
    }
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.isCurrent,
    required this.onDelete,
  });

  final EffectiveSalarySchedule schedule;
  final bool isCurrent;
  final VoidCallback onDelete;

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
          '${_monthLabel(value.paymentWindowStartMonthOffset)} day ${value.paymentWindowStartDay} '
          'to ${_monthLabel(value.paymentMonthOffset)} day ${value.paymentWindowEndDay}',
        ),
        subtitle: Text(
          'Effective ${DateFormat.yMMMd().format(schedule.effectiveFrom)}'
          '${isCurrent ? ' · Current' : ''}\n'
          'PF generation uses the final window day.',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (_) => onDelete(),
          itemBuilder: (context) => const <PopupMenuEntry<String>>[
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

String _monthLabel(int offset) =>
    offset == 0 ? 'same month' : 'following month';
