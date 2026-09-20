import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/features/salary_schedule/presentation/salary_schedule_form_screen.dart';

void main() {
  testWidgets('salary schedule rejects an end before its start', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SalaryScheduleFormScreen())),
    );

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
}
