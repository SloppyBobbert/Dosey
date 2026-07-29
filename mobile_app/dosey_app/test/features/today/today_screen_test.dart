import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/schedules/local_schedule_profile_repository.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/time/app_clock.dart';
import 'package:dosey_app/features/today/today_screen.dart';
import 'package:dosey_app/features/today/today_next_dose_helper.dart';
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
        child: MaterialApp(home: const Scaffold(body: TodayScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Next dose'), findsOneWidget);
    expect(find.textContaining('upcoming dose'), findsWidgets);
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('A missed dose needs review.'), findsOneWidget);
    expect(find.text('Review medications'), findsNothing);
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

  testWidgets(
    'Today timeline shows four eligible reminders without a control',
    (tester) async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedTimelineSchedules(database, const [
        'First reminder',
        'Second reminder',
        'Third reminder',
        'Fourth reminder',
      ]);

      await tester.pumpWidget(_todayApp(database));
      await tester.pumpAndSettle();

      expect(find.text('First reminder'), findsNWidgets(2));
      for (final label in const [
        'Second reminder',
        'Third reminder',
        'Fourth reminder',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Show all reminders'), findsNothing);
      expect(find.text('Show fewer'), findsNothing);
    },
  );

  testWidgets('Today timeline expands and collapses eligible reminders', (
    tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final clock = ControllableAppClock(DateTime.utc(2040, 1, 2, 9));
    addTearDown(database.close);
    addTearDown(clock.close);
    await _seedTimelineSchedules(database, const [
      'First reminder',
      'Terminal reminder',
      'Third reminder',
      'Fourth reminder',
      'Fifth reminder',
      'Sixth reminder',
    ]);
    await DriftDoseLogRepository(database).addEvent(
      DoseLogEvent.doseSkipped(
        doseId: TodayNextDoseHelper.doseIdForDate('timeline-2', clock.now()),
        occurredAt: clock.now(),
      ),
    );

    await tester.pumpWidget(_todayApp(database, appClock: clock));
    await tester.pumpAndSettle();

    expect(find.text('First reminder'), findsNWidgets(2));
    for (final label in const [
      'Third reminder',
      'Fourth reminder',
      'Fifth reminder',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Terminal reminder'), findsNothing);
    expect(find.text('Sixth reminder'), findsNothing);
    expect(find.text('Show all reminders'), findsOneWidget);
    _expectTimelineRowsInVerticalOrder(tester, const [
      'First reminder',
      'Third reminder',
      'Fourth reminder',
      'Fifth reminder',
    ]);

    await tester.scrollUntilVisible(find.text('Show all reminders'), 200);
    await tester.tap(find.text('Show all reminders').hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Sixth reminder'), findsOneWidget);
    expect(find.text('Show fewer'), findsOneWidget);
    expect(find.text('Show all reminders'), findsNothing);
    _expectTimelineRowsInVerticalOrder(tester, const [
      'First reminder',
      'Third reminder',
      'Fourth reminder',
      'Fifth reminder',
      'Sixth reminder',
    ]);

    await tester.scrollUntilVisible(find.text('Show fewer'), 200);
    await tester.tap(find.text('Show fewer').hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Sixth reminder'), findsNothing);
    expect(find.text('Show all reminders'), findsOneWidget);
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

  testWidgets('Today shows active enabled review slots', (tester) async {
    final database = DoseyDatabase.inMemory();
    final now = DateTime.utc(2040, 1, 2, 9);
    addTearDown(database.close);
    await _seedActiveProfile(database, now);
    await _seedSchedule(database, 'review-schedule', 8);
    await _insertSlot(
      database,
      id: 'review-slot',
      scheduleId: 'review-schedule',
      profileId: ScheduleProfile.defaultProfileId,
      status: 'needs_review',
      now: now,
    );

    await tester.pumpWidget(_todayApp(database, onOpenCarousel: () {}));
    await tester.pumpAndSettle();

    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('Review carousel'), findsOneWidget);
    expect(find.text('1 loaded slot need review.'), findsOneWidget);
  });
}

Widget _todayApp(
  DoseyDatabase database, {
  AppClock? appClock,
  VoidCallback? onOpenCarousel,
}) => DoseyAppScope(
  database: database,
  appClock: appClock,
  bleGateway: FakeBleGateway(),
  connectivityGateway: FakeConnectivityGateway(),
  missedDoseReconciliationService: FakeMissedDoseReconciliationService(),
  child: MaterialApp(
    home: Scaffold(body: TodayScreen(onOpenCarousel: onOpenCarousel)),
  ),
);

void _expectTimelineRowsInVerticalOrder(
  WidgetTester tester,
  List<String> labels,
) {
  final timelineCard = find.ancestor(
    of: find.text('Upcoming doses'),
    matching: find.byType(Card),
  );
  expect(timelineCard, findsOneWidget);

  var previousTop = double.negativeInfinity;
  for (final label in labels) {
    final rowLabel = find.descendant(
      of: timelineCard,
      matching: find.text(label),
    );
    expect(rowLabel, findsOneWidget);

    final top = tester.getTopLeft(rowLabel).dy;
    expect(
      top,
      greaterThan(previousTop),
      reason: '$label must follow the prior row',
    );
    previousTop = top;
  }
}

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
  String? label,
}) {
  return LocalReminderRepository(database).upsertSchedule(
    ReminderSchedule(
      id: id,
      label: label ?? '$id dose',
      profileId: profileId,
      hour: hour,
      minute: 0,
      isEnabled: isEnabled,
      createdAt: DateTime(2040),
      updatedAt: DateTime(2040),
    ),
  );
}

Future<void> _seedTimelineSchedules(
  DoseyDatabase database,
  List<String> labels,
) async {
  for (var index = 0; index < labels.length; index++) {
    await _seedSchedule(
      database,
      'timeline-${index + 1}',
      7 + index,
      label: labels[index],
    );
  }
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
