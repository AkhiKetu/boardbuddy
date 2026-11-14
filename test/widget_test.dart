
import 'package:flutter_test/flutter_test.dart';
import 'package:boardbuddy/app.dart';

void main() {
  testWidgets('BoardBuddy app loads', (tester) async {
    // Start our application
    await tester.pumpWidget(const BoardBuddyApp());

    // Check that the welcome text appears
    expect(
      find.text('Your Boards'),
      findsOneWidget,
    );
  });
}
