import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pf_tracker/src/core/database/database_backup_service.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';
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
      appBar: AppBar(title: Text(context.l10n.backupAndRestore)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Text(context.l10n.backupSensitiveWarning),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: Text(context.l10n.exportBackup),
              subtitle: Text(context.l10n.exportBackupDescription),
              enabled: !_busy,
              onTap: _export,
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings_backup_restore),
              title: Text(context.l10n.restoreBackup),
              subtitle: Text(context.l10n.restoreBackupDescription),
              enabled: !_busy,
              onTap: _restore,
            ),
          ),
          const Divider(height: 32),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_forever_outlined),
              title: Text(context.l10n.deleteAllData),
              subtitle: Text(context.l10n.deleteAllDataDescription),
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
    final dialogTitle = context.l10n.saveBackupDialogTitle;
    setState(() => _busy = true);
    try {
      final backup = await DatabaseBackupService(ref.read(appDatabaseProvider))
          .exportAll(appVersion: '0.1.0', exportedAt: DateTime.now());
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final output = await FilePicker.saveFile(
        dialogTitle: dialogTitle,
        fileName: 'pf-ledger-backup-$date.json',
        bytes: Uint8List.fromList(utf8.encode(jsonEncode(backup))),
      );
      if (output != null && mounted) {
        _message(context.l10n.backupExported);
      }
    } on Object {
      if (mounted) _message(context.l10n.backupExportError);
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
        title: Text(context.l10n.replaceAllDataTitle),
        content: Text(context.l10n.replaceAllDataWarning),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.restore),
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
      if (mounted) _message(context.l10n.backupRestored);
    } on Object {
      if (mounted) {
        _message(context.l10n.invalidBackupError);
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
          title: Text(context.l10n.deleteAllPFDataTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(context.l10n.deleteAllPFDataWarning),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: context.l10n.typeDeleteToConfirm,
                ),
                onChanged: (value) => setDialogState(() {}),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: controller.text == 'DELETE'
                  ? () => Navigator.pop(context, true)
                  : null,
              child: Text(context.l10n.deleteEverything),
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
      if (mounted) _message(context.l10n.allDataDeleted);
    } on Object {
      if (mounted) _message(context.l10n.deleteLocalDataError);
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
