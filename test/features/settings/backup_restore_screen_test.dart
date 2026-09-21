import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/l10n/generated/app_localizations.dart';
import 'package:pf_tracker/src/features/settings/presentation/backup_restore_screen.dart';

void main() {
  testWidgets('backup screen exposes native export and restore actions', (
    tester,
  ) async {
    await tester.pumpWidget(ProviderScope(child: _backupApp()));

    expect(find.text('Export backup'), findsOneWidget);
    expect(find.text('Restore backup'), findsOneWidget);
    expect(find.text('Delete all data'), findsOneWidget);
    expect(find.textContaining('financial information'), findsOneWidget);
  });

  testWidgets('shows backup security actions in Bangla', (tester) async {
    await tester.pumpWidget(
      ProviderScope(child: _backupApp(locale: const Locale('bn'))),
    );

    expect(find.text('ব্যাকআপ ও পুনরুদ্ধার'), findsOneWidget);
    expect(find.text('ব্যাকআপ export করুন'), findsOneWidget);
    expect(find.text('সব তথ্য মুছুন'), findsOneWidget);
  });
}

Widget _backupApp({Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const BackupRestoreScreen(),
);
