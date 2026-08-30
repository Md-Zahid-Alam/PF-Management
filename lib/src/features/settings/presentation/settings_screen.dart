import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: <Widget>[
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
