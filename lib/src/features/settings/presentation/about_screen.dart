import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About PF Ledger')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          const Icon(Icons.account_balance_wallet_outlined, size: 64),
          const SizedBox(height: 16),
          Text(
            'PF Ledger',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'An offline-first provident fund tracker for personal financial record keeping.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: Icon(Icons.offline_bolt_outlined),
                  title: Text('Offline by design'),
                  subtitle: Text(
                    'Core features do not require an account, server, or internet connection.',
                  ),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Your data stays on this device'),
                  subtitle: Text(
                    'Backups are created or restored only when you explicitly request them.',
                  ),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.calculate_outlined),
                  title: Text('Calculated values are estimates'),
                  subtitle: Text(
                    'Your organization’s official PF statement and policies remain authoritative.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
