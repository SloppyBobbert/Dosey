import 'package:dosey_app/main.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows local-first app tabs and safety guidance', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(DoseyApp(database: database));

    expect(find.text('Dosey'), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Reminders'), findsOneWidget);
    expect(find.text('Controller'), findsOneWidget);
    expect(find.text('Log'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Prototype safety'), findsOneWidget);
    expect(
      find.text('Use candy, beads, dry beans, vitamins, or fake pills.'),
      findsOneWidget,
    );
  });

  testWidgets('controller tab keeps manual dispense disabled by default', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.tap(find.text('Controller'));
    await tester.pumpAndSettle();

    expect(find.text('Controller disconnected'), findsOneWidget);
    expect(find.text('Manual dispense test'), findsOneWidget);
    expect(
      find.text(
        'Locked until Android robot mode and a controller connection are active.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Never mark a dose taken because the servo moved.'),
      findsOneWidget,
    );
  });
}
