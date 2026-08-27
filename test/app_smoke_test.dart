import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/app/pf_tracker_app.dart';

void main() {
  testWidgets('opens the first-time setup flow', (tester) async {
    await tester.pumpWidget(const PFTrackerApp());
    await tester.pumpAndSettle();

    expect(find.text('Set up PF Tracker'), findsOneWidget);
    expect(find.text('Start setup'), findsOneWidget);
  });
}
