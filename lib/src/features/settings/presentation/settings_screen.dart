import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/domain/automation_models.dart';
import 'package:pf_tracker/src/core/domain/app_preferences.dart';
import 'package:pf_tracker/src/core/notifications/notification_provider.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings)),
      body: ListView(
        children: <Widget>[
          const _AutomationSettingsSection(),
          const Divider(),
          const _AppearanceSettingsSection(),
          const _LanguageSettingsSection(),
          const Divider(),
          ListTile(
            key: const Key('securitySettingsTile'),
            leading: const Icon(Icons.security_outlined),
            title: Text(context.l10n.security),
            subtitle: Text(context.l10n.securityDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/security'),
          ),
          ListTile(
            key: const Key('profileSettingsTile'),
            leading: const Icon(Icons.person_outline),
            title: Text(context.l10n.profile),
            subtitle: Text(context.l10n.profileDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/setup/edit'),
          ),
          ListTile(
            key: const Key('organizationAndRulesSettingsTile'),
            leading: const Icon(Icons.business_outlined),
            title: Text(context.l10n.organizationAndRules),
            subtitle: Text(context.l10n.organizationAndRulesDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/setup/edit?section=organization'),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: Text(context.l10n.salarySchedule),
            subtitle: Text(context.l10n.salaryScheduleDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/salary-schedule-history'),
          ),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: Text(context.l10n.salaryHistory),
            subtitle: Text(context.l10n.salaryHistoryDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/salary-history'),
          ),
          ListTile(
            leading: const Icon(Icons.history_outlined),
            title: Text(context.l10n.historicalReconstruction),
            subtitle: Text(context.l10n.historicalReconstructionDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/historical-reconstruction'),
          ),
          ListTile(
            leading: const Icon(Icons.rule_outlined),
            title: Text(context.l10n.pfRuleHistory),
            subtitle: Text(context.l10n.pfRuleHistoryDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/pf-rule-history'),
          ),
          ListTile(
            leading: const Icon(Icons.trending_up),
            title: Text(context.l10n.profitHistory),
            subtitle: Text(context.l10n.profitHistoryDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profit-history'),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              context.l10n.tools,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.calculate_outlined),
            title: Text(context.l10n.pfCalculator),
            subtitle: Text(context.l10n.pfCalculatorDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/calculator'),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text(context.l10n.pfMaturity),
            subtitle: Text(context.l10n.pfMaturityDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/maturity'),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: Text(context.l10n.backupAndRestore),
            subtitle: Text(context.l10n.backupAndRestoreDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/backup-restore'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(context.l10n.about),
            subtitle: Text(context.l10n.aboutDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/about'),
          ),
        ],
      ),
    );
  }
}

class _AppearanceSettingsSection extends ConsumerWidget {
  const _AppearanceSettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(appThemePreferenceProvider);
    return preference.when(
      loading: () => ListTile(
        leading: const Icon(Icons.palette_outlined),
        title: Text(context.l10n.appearance),
        trailing: const SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, stackTrace) => ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text(context.l10n.appearanceUnavailable),
        trailing: IconButton(
          tooltip: context.l10n.retryAppearance,
          onPressed: () => ref.invalidate(appThemePreferenceProvider),
          icon: const Icon(Icons.refresh),
        ),
      ),
      data: (value) => ListTile(
        leading: const Icon(Icons.palette_outlined),
        title: Text(context.l10n.appearance),
        subtitle: Text(context.l10n.appearanceDescription),
        trailing: DropdownButton<AppThemePreference>(
          key: const Key('themePreferenceDropdown'),
          value: value,
          items: <DropdownMenuItem<AppThemePreference>>[
            DropdownMenuItem(
              value: AppThemePreference.system,
              child: Text(context.l10n.systemTheme),
            ),
            DropdownMenuItem(
              value: AppThemePreference.light,
              child: Text(context.l10n.lightTheme),
            ),
            DropdownMenuItem(
              value: AppThemePreference.dark,
              child: Text(context.l10n.darkTheme),
            ),
          ],
          onChanged: (selected) async {
            if (selected == null) {
              return;
            }
            await ref.read(themePreferenceRepositoryProvider).save(selected);
            ref.invalidate(appThemePreferenceProvider);
          },
        ),
      ),
    );
  }
}

class _LanguageSettingsSection extends ConsumerWidget {
  const _LanguageSettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(appLocalePreferenceProvider);
    return preference.when(
      loading: () => ListTile(
        leading: const Icon(Icons.language_outlined),
        title: Text(context.l10n.language),
        trailing: const SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, stackTrace) => ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text(context.l10n.languageUnavailable),
        trailing: IconButton(
          tooltip: context.l10n.retryLanguage,
          onPressed: () => ref.invalidate(appLocalePreferenceProvider),
          icon: const Icon(Icons.refresh),
        ),
      ),
      data: (value) => ListTile(
        leading: const Icon(Icons.language_outlined),
        title: Text(context.l10n.language),
        subtitle: Text(context.l10n.languageDescription),
        trailing: DropdownButton<AppLocalePreference>(
          key: const Key('languagePreferenceDropdown'),
          value: value,
          items: <DropdownMenuItem<AppLocalePreference>>[
            DropdownMenuItem(
              value: AppLocalePreference.bangla,
              child: Text(context.l10n.bangla),
            ),
            DropdownMenuItem(
              value: AppLocalePreference.english,
              child: Text(context.l10n.english),
            ),
          ],
          onChanged: (selected) async {
            if (selected == null) {
              return;
            }
            await ref.read(localePreferenceRepositoryProvider).save(selected);
            ref.invalidate(appLocalePreferenceProvider);
          },
        ),
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
        title: Text(context.l10n.automationSettingsUnavailable),
        trailing: IconButton(
          tooltip: context.l10n.retryAutomationSettings,
          onPressed: () => ref.invalidate(automationSettingsProvider),
          icon: const Icon(Icons.refresh),
        ),
      ),
      data: (value) => Column(
        children: <Widget>[
          SwitchListTile(
            key: const Key('autoCalculateSwitch'),
            secondary: const Icon(Icons.autorenew),
            title: Text(context.l10n.autoCalculatePF),
            subtitle: Text(context.l10n.autoCalculateDescription),
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
            title: Text(context.l10n.automationNotifications),
            subtitle: Text(context.l10n.automationNotificationsDescription),
            value: value.notificationsEnabled,
            onChanged: (enabled) async {
              if (enabled) {
                final granted = await ref
                    .read(automationNotificationGatewayProvider)
                    .requestPermission();
                if (!granted) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.l10n.notificationPermissionDenied,
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
