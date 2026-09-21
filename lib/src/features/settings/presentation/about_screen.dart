import 'package:flutter/material.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          Text(
            context.l10n.appSummary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
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
