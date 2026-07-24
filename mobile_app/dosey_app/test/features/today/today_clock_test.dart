import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/time/app_clock.dart';
import 'package:dosey_app/features/today/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Today derives the current dose date from the app clock', (
    tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final clock = ControllableAppClock(DateTime.utc(2040, 1, 1, 8));
    addTearDown(database.close);
    addTearDown(clock.close);
    final createdAt = DateTime.utc(2026, 1, 1);
    await LocalReminderRepository(database).upsertSchedule(
      ReminderSchedule(
        id: 'fake-schedule',
        label: 'FAKE Demo Dose',
        hour: 8,
        minute: 30,
        isEnabled: true,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );
    await DriftDoseLogRepository(database).addEvent(
      DoseLogEvent.doseSkipped(
        doseId: 'fake-schedule:2040-01-01',
        occurredAt: DateTime.utc(2040, 1, 1, 9),
      ),
    );

    await tester.pumpWidget(
      DoseyAppScope(
        database: database,
        appClock: clock,
        child: const MaterialApp(home: Scaffold(body: TodayScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Current dose'), findsNothing);
    expect(find.text('1 scheduled today'), findsOneWidget);

    clock.advance(const Duration(days: 1));
    await tester.pump();

    expect(find.text('Current dose'), findsOneWidget);
    expect(find.textContaining('FAKE Demo Dose'), findsWidgets);
  });

  testWidgets('Today reads the app clock after Action PIN authorization', (
    tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final clock = _SilentMutableClock(DateTime.utc(2040, 1, 2, 8, 25));
    addTearDown(database.close);
    await LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    ).setActionPin('1234');
    await LocalReminderRepository(database).upsertSchedule(
      ReminderSchedule(
        id: 'pin-clock-schedule',
        label: 'PIN clock dose',
        hour: 8,
        minute: 30,
        isEnabled: true,
        createdAt: DateTime.utc(2040),
        updatedAt: DateTime.utc(2040),
      ),
    );
    await tester.pumpWidget(
      DoseyAppScope(
        database: database,
        appClock: clock,
        child: const MaterialApp(home: Scaffold(body: TodayScreen())),
      ),
    );
    await tester.pumpAndSettle();

    final confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm dose taken manually'),
    );
    final pendingConfirmation = (confirmButton.onPressed as dynamic)();
    await tester.pumpAndSettle();
    clock.value = clock.value.add(const Duration(minutes: 10));
    await tester.enterText(find.byKey(const Key('action-pin-field')), '1234');
    await tester.tap(find.text('Continue'));
    if (pendingConfirmation is Future<void>) {
      await pendingConfirmation;
    }
    await tester.pump();

    final event = (await database.select(database.doseLogEvents).get()).single;
    expect(event.occurredAt.toUtc(), DateTime.utc(2040, 1, 2, 8, 35));
  });
}

class _SilentMutableClock implements AppClock {
  _SilentMutableClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;

  @override
  Stream<DateTime> get ticks => const Stream<DateTime>.empty();
}
