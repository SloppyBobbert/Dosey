import 'dart:async';

import 'package:dosey_app/core/notifications/reminder_notification_tap_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
