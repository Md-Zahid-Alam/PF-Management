import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/features/settings/presentation/about_screen.dart';

void main() {
  testWidgets('shows PF Ledger branding and logo', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));

    expect(find.text('About PF Ledger'), findsOneWidget);
    expect(find.text('PF Ledger'), findsOneWidget);
    expect(find.textContaining('PF Tracker'), findsNothing);
    expect(find.byKey(const Key('pfLedgerLogo')), findsOneWidget);
  });
}
