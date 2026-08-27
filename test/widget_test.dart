import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/app/pf_tracker_app.dart';

void main() {
  testWidgets('starts in the guided PF setup flow', (tester) async {
    await tester.pumpWidget(const PFTrackerApp());
    await tester.pumpAndSettle();

    expect(find.text('Set up PF Tracker'), findsOneWidget);
    expect(find.text('Start setup'), findsOneWidget);
  });
}
