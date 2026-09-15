import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/app/app_shell.dart';

void main() {
  test('navigation changes at the large-screen breakpoint', () {
    expect(useNavigationRailForWidth(759), isFalse);
    expect(useNavigationRailForWidth(760), isTrue);
    expect(useNavigationRailForWidth(1200), isTrue);
  });
}
