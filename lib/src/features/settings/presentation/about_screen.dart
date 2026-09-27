import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pf_tracker/src/core/branding/app_version_provider.dart';
import 'package:pf_tracker/src/core/branding/brand_identity.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.aboutPFApp)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Image.asset(
            'assets/branding/pf_ledger_icon.png',
            key: const Key('pfLedgerLogo'),
            width: 96,
            height: 96,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.appName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(context.l10n.appSummary, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Card(
            key: const Key('brandIdentityCard'),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _IdentityRow(
                    label: context.l10n.developedBy,
                    value: BrandIdentity.brandName,
                    valueKey: const Key('aboutDeveloperBrand'),
                  ),
                  const SizedBox(height: 16),
                  _IdentityRow(
                    label: context.l10n.productOwner,
                    value: BrandIdentity.productOwnerName,
                    valueKey: const Key('aboutProductOwner'),
                  ),
                  const SizedBox(height: 16),
                  _IdentityRow(
                    label: context.l10n.versionLabel,
                    value: version.when(
                      data: (value) => value.displayValue,
                      loading: () => '…',
                      error: (error, stackTrace) =>
                          context.l10n.versionUnavailable,
                    ),
                    valueKey: const Key('aboutAppVersion'),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.l10n.copyrightNotice(
                      BrandIdentity.copyrightYear,
                      BrandIdentity.copyrightOwner,
                    ),
                    key: const Key('aboutCopyright'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.offline_bolt_outlined),
                  title: Text(context.l10n.offlineByDesign),
                  subtitle: Text(context.l10n.offlineByDesignDescription),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(context.l10n.dataStaysOnDevice),
                  subtitle: Text(context.l10n.dataStaysOnDeviceDescription),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.calculate_outlined),
                  title: Text(context.l10n.calculatedValuesAreEstimates),
                  subtitle: Text(context.l10n.calculatedValuesDescription),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityRow extends StatelessWidget {
  const _IdentityRow({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final String label;
  final String value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          key: valueKey,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}
