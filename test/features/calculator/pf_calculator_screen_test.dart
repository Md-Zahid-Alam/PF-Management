import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/features/calculator/presentation/pf_calculator_screen.dart';

void main() {
  testWidgets('calculates approved monthly and annual PF example', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: PFCalculatorScreen()));

    await tester.ensureVisible(find.byKey(const Key('calculateButton')));
    await tester.tap(find.byKey(const Key('calculateButton')));
    await tester.pumpAndSettle();

    expect(find.text('Basic salary'), findsOneWidget);
    expect(find.text('৳18,000'), findsOneWidget);
    expect(find.text('৳1,800'), findsNWidgets(2));
    expect(find.text('৳3,600'), findsOneWidget);
    expect(find.text('৳43,200'), findsOneWidget);
  });

  testWidgets('rejects a zero gross salary', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PFCalculatorScreen()));
    await tester.enterText(find.byKey(const Key('grossSalaryField')), '0');
    await tester.ensureVisible(find.byKey(const Key('calculateButton')));
    await tester.tap(find.byKey(const Key('calculateButton')));
    await tester.pump();

    expect(find.text('Enter a gross salary greater than zero'), findsOneWidget);
  });
}
