import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/schedules/local_schedule_profile_repository.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/time/app_clock.dart';
import 'package:dosey_app/features/today/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_scope_dependencies.dart';

void main() {
  testWidgets('Today keeps attention and the next actions together', (
    tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final clock = ControllableAppClock(DateTime.utc(2040, 1, 2, 9));
    addTearDown(database.close);
    addTearDown(clock.close);
    await LocalScheduleProfileRepository(database).upsertProfile(
      ScheduleProfile(
        id: ScheduleProfile.defaultProfileId,
        name: 'Home',
        isActive: true,
        createdAt: clock.now(),
        updatedAt: clock.now(),
      ),
    );
    await _seedSchedule(database, 'taken', 7);
    await _seedSchedule(database, 'skipped', 8);
    await _seedSchedule(database, 'upcoming', 10);
    await _seedSchedule(database, 'missed', 6);
    final log = DriftDoseLogRepository(database);
    await log.addEvent(
      DoseLogEvent.doseTakenConfirmed(
        doseId: 'taken:2040-01-02',
        occurredAt: DateTime(2040, 1, 2, 7, 5),
      ),
    );
    await log.addEvent(
      DoseLogEvent.doseSkipped(
        doseId: 'skipped:2040-01-02',
        occurredAt: DateTime(2040, 1, 2, 8, 5),
      ),
    );
    await log.addEvent(
      DoseLogEvent.doseMissed(
        doseId: 'missed:2040-01-02',
        occurredAt: DateTime(2040, 1, 2, 6, 30),
      ),
    );

    await tester.pumpWidget(
      DoseyAppScope(
        database: database,
        appClock: clock,
        bleGateway: FakeBleGateway(),
        connectivityGateway: FakeConnectivityGateway(),
        missedDoseReconciliationService: FakeMissedDoseReconciliationService(),
        child: MaterialApp(
          home: Scaffold(body: TodayScreen(onOpenMedications: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Next dose'), findsOneWidget);
    expect(find.textContaining('upcoming dose'), findsWidgets);
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('A missed dose needs review.'), findsOneWidget);
    expect(find.text('Review medications'), findsOneWidget);
    expect(find.text('Upcoming doses'), findsOneWidget);
    expect(find.text('Mark dose as taken'), findsOneWidget);
    expect(find.text('Carousel'), findsNothing);
    expect(find.text('Robot Face'), findsNothing);
  });

  testWidgets('Today does not add navigation shortcuts', (tester) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(
      DoseyAppScope(
        database: database,
        bleGateway: FakeBleGateway(),
        connectivityGateway: FakeConnectivityGateway(),
        missedDoseReconciliationService: FakeMissedDoseReconciliationService(),
        child: MaterialApp(home: const Scaffold(body: TodayScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Robot Face'), findsNothing);
    expect(find.text('Medications'), findsNothing);
  });

  testWidgets('Today ignores review slots from an inactive profile', (
    tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final now = DateTime.utc(2040, 1, 2, 9);
    addTearDown(database.close);
    await _seedActiveProfile(database, now);
    await _seedSchedule(database, 'inactive-schedule', 8, profileId: 'travel');
    await _insertSlot(
      database,
      id: 'inactive-slot',
      scheduleId: 'inactive-schedule',
      profileId: 'travel',
      status: 'needs_review',
      now: now,
    );

    await tester.pumpWidget(_todayApp(database));
    await tester.pumpAndSettle();

    expect(find.text('Needs attention'), findsNothing);
    expect(find.text('Review carousel'), findsNothing);
  });

  testWidgets('Today ignores review slots for disabled schedules', (
    tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final now = DateTime.utc(2040, 1, 2, 9);
    addTearDown(database.close);
    await _seedActiveProfile(database, now);
    await _seedSchedule(database, 'disabled-schedule', 8, isEnabled: false);
    await _insertSlot(
      database,
      id: 'disabled-slot',
      scheduleId: 'disabled-schedule',
      profileId: ScheduleProfile.defaultProfileId,
      status: 'needs_review',
      now: now,
    );

    await tester.pumpWidget(_todayApp(database));
    await tester.pumpAndSettle();

    expect(find.text('Needs attention'), findsNothing);
    expect(find.text('Review carousel'), findsNothing);
  });
}

Widget _todayApp(DoseyDatabase database) => DoseyAppScope(
  database: database,
  bleGateway: FakeBleGateway(),
  connectivityGateway: FakeConnectivityGateway(),
  missedDoseReconciliationService: FakeMissedDoseReconciliationService(),
  child: MaterialApp(home: const Scaffold(body: TodayScreen())),
);

Future<void> _seedActiveProfile(DoseyDatabase database, DateTime now) {
  return LocalScheduleProfileRepository(database).upsertProfile(
    ScheduleProfile(
      id: ScheduleProfile.defaultProfileId,
      name: 'Home',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

Future<void> _seedSchedule(
  DoseyDatabase database,
  String id,
  int hour, {
  String profileId = ScheduleProfile.defaultProfileId,
  bool isEnabled = true,
}) {
  return LocalReminderRepository(database).upsertSchedule(
    ReminderSchedule(
      id: id,
      label: '$id dose',
      profileId: profileId,
      hour: hour,
      minute: 0,
      isEnabled: isEnabled,
      createdAt: DateTime(2040),
      updatedAt: DateTime(2040),
    ),
  );
}

Future<void> _insertSlot(
  DoseyDatabase database, {
  required String id,
  required String scheduleId,
  required String profileId,
  required String status,
  required DateTime now,
}) {
  return database
      .into(database.carouselSlots)
      .insert(
        CarouselSlotsCompanion.insert(
          id: id,
          slotNumber: 1,
          prescriptionId: 'prescription',
          scheduleId: scheduleId,
          profileId: profileId,
          status: status,
          createdAt: now,
          updatedAt: now,
        ),
      );
}
