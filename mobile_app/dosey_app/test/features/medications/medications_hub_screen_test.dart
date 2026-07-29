import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/schedules/local_schedule_profile_repository.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/medications/medications_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_scope_dependencies.dart';

void main() {
  testWidgets('truthfully explains when all medication times are paused', (
    tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final now = DateTime.utc(2040, 1, 2, 9);
    addTearDown(database.close);
    await LocalScheduleProfileRepository(database).upsertProfile(
      ScheduleProfile(
        id: ScheduleProfile.defaultProfileId,
        name: 'Home',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await LocalReminderRepository(database).upsertSchedule(
      ReminderSchedule(
        id: 'paused-schedule',
        label: 'Morning medicine',
        hour: 8,
        minute: 0,
        isEnabled: false,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await tester.pumpWidget(
      DoseyAppScope(
        database: database,
        bleGateway: FakeBleGateway(),
        connectivityGateway: FakeConnectivityGateway(),
        missedDoseReconciliationService: FakeMissedDoseReconciliationService(),
        child: MaterialApp(
          home: Scaffold(
            body: MedicationsHubScreen(
              onOpenSchedules: () {},
              onOpenPrescriptions: () {},
              onManageCarousel: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Medication times are paused.'), findsOneWidget);
    expect(find.text('No medication times are active.'), findsOneWidget);
    expect(find.text('No medication times set yet.'), findsNothing);
  });

  testWidgets(
    'Carousel readiness excludes disabled and inactive-profile slots',
    (tester) async {
      final database = DoseyDatabase.inMemory();
      final now = DateTime.utc(2040, 1, 2, 9);
      addTearDown(database.close);
      await LocalScheduleProfileRepository(database).upsertProfile(
        ScheduleProfile(
          id: ScheduleProfile.defaultProfileId,
          name: 'Home',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await _seedSchedule(database, 'enabled', true, now);
      await _seedSchedule(database, 'disabled', false, now);
      await _seedSchedule(database, 'travel', true, now, profileId: 'travel');
      await _insertSlot(
        database,
        'enabled-slot',
        'enabled',
        'schedule-1',
        1,
        now,
      );
      await _insertSlot(
        database,
        'disabled-slot',
        'disabled',
        'schedule-1',
        2,
        now,
      );
      await _insertSlot(database, 'travel-slot', 'travel', 'travel', 1, now);

      await tester.pumpWidget(
        DoseyAppScope(
          database: database,
          bleGateway: FakeBleGateway(),
          connectivityGateway: FakeConnectivityGateway(),
          missedDoseReconciliationService:
              FakeMissedDoseReconciliationService(),
          child: MaterialApp(
            home: Scaffold(
              body: MedicationsHubScreen(
                onOpenSchedules: () {},
                onOpenPrescriptions: () {},
                onManageCarousel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 slot ready.'), findsOneWidget);
      expect(find.text('2 slots ready.'), findsNothing);
      expect(find.text('3 slots ready.'), findsNothing);
    },
  );

  testWidgets('shows remaining enabled medication times as a Schedule link', (
    tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final now = DateTime.utc(2040, 1, 2, 9);
    var scheduleOpens = 0;
    addTearDown(database.close);
    await LocalScheduleProfileRepository(database).upsertProfile(
      ScheduleProfile(
        id: ScheduleProfile.defaultProfileId,
        name: 'Home',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    for (var hour = 8; hour <= 12; hour++) {
      await LocalReminderRepository(database).upsertSchedule(
        ReminderSchedule(
          id: 'time-$hour',
          label: 'Medicine $hour',
          hour: hour,
          minute: 0,
          isEnabled: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    await tester.pumpWidget(
      _medicationsApp(
        database: database,
        onOpenSchedules: () => scheduleOpens++,
      ),
    );
    await tester.pumpAndSettle();

    for (final label in [
      'Medicine 8',
      'Medicine 9',
      'Medicine 10',
      'Medicine 11',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Medicine 12'), findsNothing);
    await tester.tap(find.text('1 more medication time'));
    expect(scheduleOpens, 1);
  });

  testWidgets('does not add an overflow link for four or fewer enabled times', (
    tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final now = DateTime.utc(2040, 1, 2, 9);
    addTearDown(database.close);
    await LocalScheduleProfileRepository(database).upsertProfile(
      ScheduleProfile(
        id: ScheduleProfile.defaultProfileId,
        name: 'Home',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    for (var hour = 8; hour <= 11; hour++) {
      await _seedSchedule(database, 'time-$hour', true, now);
    }

    await tester.pumpWidget(_medicationsApp(database: database));
    await tester.pumpAndSettle();

    expect(find.textContaining('more medication time'), findsNothing);
  });
}

Widget _medicationsApp({
  required DoseyDatabase database,
  VoidCallback? onOpenSchedules,
}) {
  return DoseyAppScope(
    database: database,
    bleGateway: FakeBleGateway(),
    connectivityGateway: FakeConnectivityGateway(),
    missedDoseReconciliationService: FakeMissedDoseReconciliationService(),
    child: MaterialApp(
      home: Scaffold(
        body: MedicationsHubScreen(
          onOpenSchedules: onOpenSchedules ?? () {},
          onOpenPrescriptions: () {},
          onManageCarousel: () {},
        ),
      ),
    ),
  );
}

Future<void> _seedSchedule(
  DoseyDatabase database,
  String id,
  bool isEnabled,
  DateTime now, {
  String profileId = ScheduleProfile.defaultProfileId,
}) {
  return LocalReminderRepository(database).upsertSchedule(
    ReminderSchedule(
      id: id,
      label: id,
      profileId: profileId,
      hour: 8,
      minute: 0,
      isEnabled: isEnabled,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

Future<void> _insertSlot(
  DoseyDatabase database,
  String id,
  String scheduleId,
  String profileId,
  int slotNumber,
  DateTime now,
) {
  return database
      .into(database.carouselSlots)
      .insert(
        CarouselSlotsCompanion.insert(
          id: id,
          slotNumber: slotNumber,
          prescriptionId: 'prescription',
          scheduleId: scheduleId,
          profileId: profileId,
          status: 'loaded',
          createdAt: now,
          updatedAt: now,
        ),
      );
}
