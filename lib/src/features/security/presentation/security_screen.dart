import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';
import 'package:pf_tracker/src/core/security/app_lock_controller.dart';
import 'package:pf_tracker/src/core/security/security_provider.dart';
import 'package:pf_tracker/src/core/security/security_repository.dart';

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPin = ref.watch(hasPinProvider);
    final preferences = ref.watch(securityPreferencesProvider);
    final biometricAvailability = ref.watch(biometricAvailabilityProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.security)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: <Widget>[
          hasPin.when(
            loading: () => ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: Text(context.l10n.securityStatus),
              trailing: const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (error, stackTrace) => ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text(context.l10n.securityStatus),
              subtitle: Text(context.l10n.securityDataUnavailable),
              trailing: IconButton(
                tooltip: context.l10n.tryAgain,
                onPressed: () => ref.invalidate(hasPinProvider),
                icon: const Icon(Icons.refresh),
              ),
            ),
            data: (enabled) => ListTile(
              key: const Key('securityStatusTile'),
              leading: const Icon(Icons.shield_outlined),
              title: Text(context.l10n.securityStatus),
              subtitle: Text(
                enabled
                    ? context.l10n.pinProtectionActive
                    : context.l10n.pinProtectionInactive,
              ),
              trailing: Icon(
                enabled ? Icons.verified_user : Icons.warning_amber_rounded,
              ),
            ),
          ),
          ListTile(
            key: const Key('changePinTile'),
            leading: const Icon(Icons.password_outlined),
            title: Text(context.l10n.changePin),
            subtitle: Text(context.l10n.changePinDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/security/change-pin'),
          ),
          biometricAvailability.when(
            loading: () => ListTile(
              leading: const Icon(Icons.fingerprint),
              title: Text(context.l10n.biometricUnlock),
              trailing: const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (error, stackTrace) => SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: Text(context.l10n.biometricUnlock),
              subtitle: Text(context.l10n.biometricUnavailable),
              value: false,
              onChanged: null,
            ),
            data: (available) {
              if (!available) {
                return SwitchListTile(
                  key: const Key('biometricUnavailableTile'),
                  secondary: const Icon(Icons.fingerprint),
                  title: Text(context.l10n.biometricUnlock),
                  subtitle: Text(context.l10n.biometricUnavailable),
                  value: false,
                  onChanged: null,
                );
              }
              return preferences.when(
                loading: () => ListTile(
                  leading: const Icon(Icons.fingerprint),
                  title: Text(context.l10n.biometricUnlock),
                  trailing: const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (error, stackTrace) => SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: Text(context.l10n.biometricUnlock),
                  subtitle: Text(context.l10n.securityDataUnavailable),
                  value: false,
                  onChanged: null,
                ),
                data: (value) => SwitchListTile(
                  key: const Key('biometricUnlockSwitch'),
                  secondary: const Icon(Icons.fingerprint),
                  title: Text(context.l10n.biometricUnlock),
                  subtitle: Text(context.l10n.biometricUnlockDescription),
                  value: value.biometricEnabled,
                  onChanged: (enabled) async {
                    if (enabled) {
                      final verified = await ref
                          .read(biometricGatewayProvider)
                          .authenticate(
                            reason: context.l10n.enableBiometricReason,
                          );
                      if (!context.mounted) {
                        return;
                      }
                      if (!verified) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.biometricNotVerified),
                          ),
                        );
                        return;
                      }
                    }
                    await ref
                        .read(securityRepositoryProvider)
                        .savePreferences(
                          value.copyWith(biometricEnabled: enabled),
                        );
                    ref.invalidate(securityPreferencesProvider);
                  },
                ),
              );
            },
          ),
          preferences.when(
            loading: () => ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text(context.l10n.autoLockDuration),
              trailing: const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (error, stackTrace) => ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text(context.l10n.autoLockDuration),
              subtitle: Text(context.l10n.securityDataUnavailable),
              trailing: IconButton(
                tooltip: context.l10n.tryAgain,
                onPressed: () => ref.invalidate(securityPreferencesProvider),
                icon: const Icon(Icons.refresh),
              ),
            ),
            data: (value) => ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text(context.l10n.autoLockDuration),
              subtitle: Text(context.l10n.autoLockDescription),
              trailing: DropdownButton<AutoLockDuration>(
                key: const Key('autoLockDurationDropdown'),
                value: value.autoLockDuration,
                items: AutoLockDuration.values
                    .map(
                      (duration) => DropdownMenuItem<AutoLockDuration>(
                        value: duration,
                        child: Text(_autoLockLabel(context, duration)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (selected) async {
                  if (selected == null) {
                    return;
                  }
                  await ref
                      .read(securityRepositoryProvider)
                      .savePreferences(
                        value.copyWith(autoLockDuration: selected),
                      );
                  ref.invalidate(securityPreferencesProvider);
                },
              ),
            ),
          ),
          const Divider(),
          ListTile(
            key: const Key('lockNowTile'),
            leading: const Icon(Icons.lock_outline_rounded),
            title: Text(context.l10n.lockNow),
            subtitle: Text(context.l10n.lockNowDescription),
            onTap: () => context.go(unlockLocation('/settings')),
          ),
        ],
      ),
    );
  }

  String _autoLockLabel(BuildContext context, AutoLockDuration duration) {
    return switch (duration) {
      AutoLockDuration.immediately => context.l10n.immediately,
      AutoLockDuration.oneMinute => context.l10n.oneMinute,
      AutoLockDuration.fiveMinutes => context.l10n.fiveMinutes,
      AutoLockDuration.fifteenMinutes => context.l10n.fifteenMinutes,
      AutoLockDuration.never => context.l10n.never,
    };
  }
}
