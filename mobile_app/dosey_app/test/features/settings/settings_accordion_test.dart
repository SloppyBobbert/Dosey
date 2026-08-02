import 'dart:ui';

import 'package:dosey_app/features/settings/settings_accordion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('exposes button state and removes collapsed content', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var semanticsDisposed = false;
    void disposeSemantics() {
      if (semanticsDisposed) return;
      semantics.dispose();
      semanticsDisposed = true;
    }

    addTearDown(disposeSemantics);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SettingsAccordion(
            title: 'History & data',
            child: Text('Dose history'),
          ),
        ),
      ),
    );

    expect(find.text('Dose history'), findsNothing);
    expect(
      tester.getSize(find.byType(InkWell)).height,
      greaterThanOrEqualTo(48),
    );
    final collapsed = tester.getSemantics(find.text('History & data'));
    expect(collapsed.label, 'History & data');
    expect(collapsed.flagsCollection.isButton, isTrue);
    expect(collapsed.flagsCollection.isExpanded, Tristate.isFalse);
    expect(collapsed.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    await tester.tap(find.text('History & data'));
    await tester.pumpAndSettle();
    expect(find.text('Dose history'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.text('History & data'))
          .flagsCollection
          .isExpanded,
      Tristate.isTrue,
    );
    await tester.tap(find.text('History & data'));
    await tester.pumpAndSettle();
    expect(find.text('Dose history'), findsNothing);
    disposeSemantics();
  });

  testWidgets('wraps a long title at 200 percent without losing the chevron', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SettingsAccordion(
                title:
                    'Medication reminders, notification preferences, and history',
                child: Text('Expanded content'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(
      find.text('Medication reminders, notification preferences, and history'),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
    expect(find.text('Expanded content'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accordions expand independently', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SettingsAccordion(title: 'First', child: Text('First content')),
              SettingsAccordion(title: 'Second', child: Text('Second content')),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('First'));
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();

    expect(find.text('First content'), findsOneWidget);
    expect(find.text('Second content'), findsOneWidget);
  });
}
