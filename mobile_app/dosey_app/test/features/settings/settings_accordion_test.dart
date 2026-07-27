import 'dart:ui';

import 'package:dosey_app/features/settings/settings_accordion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('exposes button state and removes collapsed content', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

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
    semantics.dispose();
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
