import 'dart:async';

import 'package:dosey_app/core/notifications/reminder_notification_tap_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('raw dose payload is delivered as a dose reminder tap', () async {
    final controller = ReminderNotificationTapController();
    addTearDown(controller.dispose);
    final tapFuture = controller.taps.first;

    controller.handleTap(' dose-17 ');

    final tap = await tapFuture.timeout(const Duration(milliseconds: 50));
    expect(tap, const ReminderNotificationTap.doseReminder('dose-17'));
  });

  test('shortage payload extracts alert id and ignores metadata', () async {
    final controller = ReminderNotificationTapController();
    addTearDown(controller.dispose);
    final tapFuture = controller.taps.first;

    controller.handleTap(
      'shortage:shortage-1|slot:2|scheduledAt:2026-06-15T08:30:00.000Z|audience:household|delivery:local_only',
    );

    final tap = await tapFuture.timeout(const Duration(milliseconds: 50));
    expect(tap, const ReminderNotificationTap.shortage('shortage-1'));
  });

  test('typed tap before listener is delivered to first subscriber', () async {
    final controller = ReminderNotificationTapController();
    addTearDown(controller.dispose);

    controller.handleTap(' dose-42 ');

    final tap = await controller.taps.first.timeout(
      const Duration(milliseconds: 50),
    );

    expect(tap, const ReminderNotificationTap.doseReminder('dose-42'));
  });

  test('pending cold-start tap can be consumed atomically', () async {
    final controller = ReminderNotificationTapController();
    addTearDown(controller.dispose);
    controller.handleTap('dose-cold-start');

    expect(
      controller.takePendingTap(),
      const ReminderNotificationTap.doseReminder('dose-cold-start'),
    );
    expect(controller.takePendingTap(), isNull);
    await expectLater(
      controller.taps.first.timeout(const Duration(milliseconds: 50)),
      throwsA(isA<TimeoutException>()),
    );
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

  test('shortage tap without alert id is ignored', () async {
    final controller = ReminderNotificationTapController();
    addTearDown(controller.dispose);

    controller.handleTap('shortage:|slot:2');

    await expectLater(
      controller.taps.first.timeout(const Duration(milliseconds: 50)),
      throwsA(isA<TimeoutException>()),
    );
  });
}
