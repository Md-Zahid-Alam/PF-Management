import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: const <Widget>[
          ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Profile'),
            subtitle: Text('Employment and PF start information'),
          ),
          ListTile(
            leading: Icon(Icons.business_outlined),
            title: Text('Organization & PF Rules'),
            subtitle: Text('Contribution rates, maturity, and entitlement'),
          ),
          ListTile(
            leading: Icon(Icons.calendar_month_outlined),
            title: Text('Salary Schedule'),
            subtitle: Text('Payment window and PF generation date'),
          ),
          ListTile(
            leading: Icon(Icons.backup_outlined),
            title: Text('Backup & Restore'),
            subtitle: Text('Manage an offline copy of your PF data'),
          ),
        ],
      ),
    );
  }
}
