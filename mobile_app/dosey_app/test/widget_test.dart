import 'package:dosey_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows prototype safety guidance and controller status', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DoseyApp());

    expect(find.text('Dosey'), findsOneWidget);
    expect(find.text('Prototype safety'), findsOneWidget);
    expect(
      find.text('Use candy, beads, dry beans, vitamins, or fake pills.'),
      findsOneWidget,
    );
    expect(find.text('Controller disconnected'), findsOneWidget);
    expect(find.text('Manual dispense test'), findsOneWidget);
    expect(find.text('Locked until a controller is connected'), findsOneWidget);
  });

  testWidgets('shows the first build milestones without marking doses taken', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DoseyApp());

    expect(find.text('Next build steps'), findsOneWidget);
    expect(find.text('1. Grove electronics bring-up'), findsOneWidget);
    expect(find.text('2. BLE command/status demo'), findsOneWidget);
    expect(find.text('3. Carousel one-slot test'), findsOneWidget);
    expect(
      find.text('Never mark a dose taken because the servo moved.'),
      findsOneWidget,
    );
  });
}
