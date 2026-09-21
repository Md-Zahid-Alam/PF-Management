import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/l10n/generated/app_localizations.dart';
import 'package:pf_tracker/src/features/salary_schedule/presentation/salary_schedule_form_screen.dart';

void main() {
  testWidgets('salary schedule rejects an end before its start', (
    tester,
  ) async {
    await tester.pumpWidget(ProviderScope(child: _scheduleApp()));

    await tester.enterText(
      find.byKey(const Key('scheduleStartDayField')),
      '10',
    );
    await tester.enterText(find.byKey(const Key('scheduleEndDayField')), '5');
    final save = find.byKey(const Key('saveSalaryScheduleButton'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();

    expect(
      find.text('Payment window end must follow its start.'),
      findsOneWidget,
    );
  });

  testWidgets('shows salary schedule form labels in Bangla', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(child: _scheduleApp(locale: const Locale('bn'))),
    );

    expect(find.text('নতুন বেতন প্রদানের সময়সূচি'), findsOneWidget);
    expect(find.text('বেতন প্রদানের সময় শুরু'), findsOneWidget);
    expect(find.text('সময়সূচির সংস্করণ সংরক্ষণ করুন'), findsOneWidget);
  });
}

Widget _scheduleApp({Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const SalaryScheduleFormScreen(),
);
