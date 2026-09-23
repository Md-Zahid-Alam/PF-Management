import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';
import 'package:pf_tracker/src/core/security/security_provider.dart';

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPin = ref.watch(hasPinProvider);
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
        ],
      ),
    );
  }
}
