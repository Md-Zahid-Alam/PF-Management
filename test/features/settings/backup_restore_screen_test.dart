import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/features/settings/presentation/backup_restore_screen.dart';

void main() {
  testWidgets('backup screen exposes native export and restore actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: BackupRestoreScreen())),
    );

    expect(find.text('Export backup'), findsOneWidget);
    expect(find.text('Restore backup'), findsOneWidget);
    expect(find.text('Delete all data'), findsOneWidget);
    expect(find.textContaining('financial information'), findsOneWidget);
  });
}
