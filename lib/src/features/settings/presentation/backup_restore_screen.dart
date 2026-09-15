import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pf_tracker/src/core/database/database_backup_service.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/features/pf_data_providers.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          const Text(
            'A backup contains personal employment and financial information. Store it securely.',
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Export backup'),
              subtitle: const Text('Save all local PF data to a JSON file'),
              enabled: !_busy,
              onTap: _export,
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings_backup_restore),
              title: const Text('Restore backup'),
              subtitle: const Text(
                'Replace local data with a validated backup file',
              ),
              enabled: !_busy,
              onTap: _restore,
            ),
          ),
          const Divider(height: 32),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_forever_outlined),
              title: const Text('Delete all data'),
              subtitle: const Text('Permanently erase all local PF data'),
              enabled: !_busy,
              onTap: _deleteAll,
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final backup = await DatabaseBackupService(ref.read(appDatabaseProvider))
          .exportAll(appVersion: '0.1.0', exportedAt: DateTime.now());
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final output = await FilePicker.saveFile(
        dialogTitle: 'Save PF Tracker backup',
        fileName: 'pf-tracker-backup-$date.json',
        bytes: Uint8List.fromList(utf8.encode(jsonEncode(backup))),
      );
      if (output != null && mounted) {
        _message('Backup exported successfully.');
      }
    } on Object {
      if (mounted) _message('Could not export the backup.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
    );
    if (file == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace all local data?'),
        content: const Text(
          'The selected backup will replace every current PF record and setting. This cannot be undone unless you export the current data first.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final decoded = jsonDecode(utf8.decode(await file.readAsBytes()));
      if (decoded is! Map<Object?, Object?>) {
        throw const InvalidBackup('Backup root is malformed.');
      }
      await DatabaseBackupService(ref.read(appDatabaseProvider))
          .restoreAll(Map<String, Object?>.from(decoded));
      _invalidateData();
      if (mounted) _message('Backup restored successfully.');
    } on Object {
      if (mounted) {
        _message('Invalid or corrupted backup. No data was changed.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAll() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Delete all PF data?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'This permanently deletes every profile, rule, salary, record, statement, and setting. Export a backup first if needed.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Type DELETE to confirm',
                ),
                onChanged: (value) => setDialogState(() {}),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: controller.text == 'DELETE'
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Delete everything'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await DatabaseBackupService(ref.read(appDatabaseProvider)).deleteAll();
      _invalidateData();
      if (mounted) _message('All local PF data was deleted.');
    } on Object {
      if (mounted) _message('Could not delete local data.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _invalidateData() {
    ref.invalidate(initialPFSetupProvider);
    ref.invalidate(salaryHistoryProvider);
    ref.invalidate(pfRuleHistoryProvider);
    ref.invalidate(monthlyPFRecordsProvider);
    ref.invalidate(profitHistoryProvider);
    ref.invalidate(actualPFStatementsProvider);
    ref.invalidate(statementYearDefinitionsProvider);
    ref.invalidate(automationSettingsProvider);
    ref.invalidate(pfAutomationRunProvider);
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
