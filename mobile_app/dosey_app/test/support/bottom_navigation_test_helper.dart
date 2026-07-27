import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openBottomDestination(
  WidgetTester tester,
  String label, {
  required Future<void> Function() pumpFrame,
}) async {
  var navigationBar = find.byType(NavigationBar);
  if (navigationBar.evaluate().isEmpty) {
    await tester.pageBack();
    await pumpFrame();
    navigationBar = find.byType(NavigationBar);
  }
  await tester.tap(
    find
        .descendant(of: navigationBar, matching: find.text(label))
        .hitTestable(),
  );
  await pumpFrame();
}
