import 'dart:async';

import 'package:dosey_app/core/notifications/reminder_notification_tap_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tap with active listener is delivered immediately', () async {
    final controller = ReminderNotificationTapController();
    addTearDown(controller.dispose);
    final tapFuture = controller.taps.first;

    controller.handleTap(' dose-17 ');

    final tap = await tapFuture.timeout(const Duration(milliseconds: 50));
    expect(tap.doseId, 'dose-17');
  });

  test('tap before listener is delivered to the first subscriber', () async {
    final controller = ReminderNotificationTapController();
    addTearDown(controller.dispose);

    controller.handleTap(' dose-42 ');

    final tap = await controller.taps.first.timeout(
      const Duration(milliseconds: 50),
    );

    expect(tap.doseId, 'dose-42');
  });

  test('blank taps are ignored', () async {
    final controller = ReminderNotificationTapController();
    addTearDown(controller.dispose);

    controller.handleTap('   ');

    await expectLater(
      controller.taps.first.timeout(const Duration(milliseconds: 50)),
      throwsA(isA<TimeoutException>()),
    );
  });
}
