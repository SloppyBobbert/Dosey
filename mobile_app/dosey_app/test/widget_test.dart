import 'package:dosey_app/main.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
    final disabledButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Dispense disabled'),
    );
    expect(disabledButton.onPressed, isNull);
  });

  testWidgets('settings only offers iOS personal role on iOS', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    try {
      await tester.pumpWidget(DoseyApp(database: database));
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('iOS personal phone'), findsOneWidget);
      expect(find.text('Android robot phone'), findsNothing);
      expect(find.text('Android personal phone'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('reminders tab adds edits toggles and deletes reminders', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.tap(find.text('Reminders'));
    await tester.pumpAndSettle();

    expect(find.text('No reminders yet.'), findsOneWidget);
    expect(find.text('Add reminder'), findsOneWidget);

    await tester.tap(find.text('Add reminder'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Label'),
      'Vitamin D',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Hour'), '8');
    await tester.enterText(find.widgetWithText(TextFormField, 'Minute'), '30');
    await tester.tap(find.text('Save reminder'));
    await tester.pumpAndSettle();

    expect(find.text('Vitamin D'), findsOneWidget);
    expect(find.text('08:30'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.byTooltip('Edit reminder'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Label'),
      'Morning vitamin',
    );
    await tester.tap(find.text('Save reminder'));
    await tester.pumpAndSettle();

    expect(find.text('Vitamin D'), findsNothing);
    expect(find.text('Morning vitamin'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete reminder'));
    await tester.pumpAndSettle();

    expect(find.text('Morning vitamin'), findsNothing);
    expect(find.text('No reminders yet.'), findsOneWidget);
  });
}
