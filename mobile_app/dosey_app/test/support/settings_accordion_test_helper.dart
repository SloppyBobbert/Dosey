import 'package:dosey_app/features/settings/settings_accordion.dart';
import 'package:dosey_app/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder settingsAccordion(String title) {
  return find.byWidgetPredicate(
    (widget) => widget is SettingsAccordion && widget.title == title,
  );
}

Future<void> openSettingsAccordion(
  WidgetTester tester,
  String title, {
  required Future<void> Function() pumpAfterTap,
}) async {
  final accordion = settingsAccordion(title);
  final settingsScrollable = find
      .descendant(
        of: find.byType(SettingsScreen),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(
    accordion,
    240,
    scrollable: settingsScrollable,
  );
  await tester.ensureVisible(accordion);
  await tester.pump();
  await tester.tap(
    find
        .descendant(of: accordion, matching: find.byType(InkWell))
        .hitTestable()
        .first,
  );
  await pumpAfterTap();
}
