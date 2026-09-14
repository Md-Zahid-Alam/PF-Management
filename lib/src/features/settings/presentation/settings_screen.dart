import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/automation_models.dart';
import 'package:pf_tracker/src/core/notifications/notification_provider.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: <Widget>[
          const _AutomationSettingsSection(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            subtitle: const Text('Employment and PF start information'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/setup/edit'),
          ),
          ListTile(
            leading: const Icon(Icons.business_outlined),
            title: const Text('Organization & PF Rules'),
            subtitle: const Text(
              'Contribution rates, maturity, and entitlement',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/setup/edit'),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Salary Schedule'),
            subtitle: const Text('Payment window and PF generation date'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/setup/edit'),
          ),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: const Text('Salary History'),
            subtitle: const Text('Effective-dated salary changes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/salary-history'),
          ),
          ListTile(
            leading: const Icon(Icons.trending_up),
            title: const Text('Profit History'),
            subtitle: const Text('Credited PF profit and statement details'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profit-history'),
          ),
          const Divider(),
          const ListTile(
            enabled: false,
            leading: Icon(Icons.backup_outlined),
            title: Text('Backup & Restore'),
            subtitle: Text('Available in a later Phase 6 UI slice'),
          ),
        ],
      ),
    );
  }
}

class _AutomationSettingsSection extends ConsumerWidget {
  const _AutomationSettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(automationSettingsProvider);
    return settings.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => ListTile(
        leading: const Icon(Icons.error_outline),
        title: const Text('Automation settings unavailable'),
        trailing: IconButton(
          tooltip: 'Retry automation settings',
          onPressed: () => ref.invalidate(automationSettingsProvider),
          icon: const Icon(Icons.refresh),
        ),
      ),
      data: (value) => Column(
        children: <Widget>[
          SwitchListTile(
            key: const Key('autoCalculateSwitch'),
            secondary: const Icon(Icons.autorenew),
            title: const Text('Auto Calculate PF'),
            subtitle: const Text(
              'Process all eligible due months when the app opens',
            ),
            value: value.autoCalculate,
            onChanged: (enabled) => _save(
              ref,
              value.copyWith(autoCalculate: enabled),
              runAutomation: enabled,
            ),
          ),
          SwitchListTile(
            key: const Key('automationNotificationsSwitch'),
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Automation notifications'),
            subtitle: const Text(
              'Show local alerts for due, missing, and calculated months',
            ),
            value: value.notificationsEnabled,
            onChanged: (enabled) async {
              if (enabled) {
                final granted = await ref
                    .read(automationNotificationGatewayProvider)
                    .requestPermission();
                if (!granted) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Notification permission was not granted.',
                        ),
                      ),
                    );
                  }
                  return;
                }
              }
              await _save(ref, value.copyWith(notificationsEnabled: enabled));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _save(
    WidgetRef ref,
    AutomationSettings settings, {
    bool runAutomation = false,
  }) async {
    await ref.read(automationSettingsRepositoryProvider).save(settings);
    ref.invalidate(automationSettingsProvider);
    if (runAutomation) {
      ref.invalidate(pfAutomationRunProvider);
    }
  }
}
