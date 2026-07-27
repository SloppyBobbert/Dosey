import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/time/app_clock.dart';
import 'package:dosey_app/features/dashboard/dashboard_screen.dart';
import 'package:dosey_app/features/today/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_scope_dependencies.dart';

void main() {
  testWidgets('shows compact dose summary, shortcuts, and Today details', (
    tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final clock = ControllableAppClock(DateTime.utc(2040, 1, 2, 9));
    addTearDown(database.close);
    addTearDown(clock.close);
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
          home: Scaffold(
            body: DashboardScreen(
              showRobotFaceShortcut: true,
              onOpenSchedule: () {},
              onOpenCarousel: () {},
              onOpenSettings: () {},
              onOpenRobotFace: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Next dose'), findsOneWidget);
    expect(find.textContaining('upcoming dose'), findsWidgets);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Carousel'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Robot Face'), findsOneWidget);
    expect(find.text('Taken 1'), findsOneWidget);
    expect(find.text('Skipped 1'), findsOneWidget);
    expect(find.text('Upcoming 1'), findsOneWidget);
    expect(find.text('Missed 1'), findsOneWidget);
    expect(find.text('Missed dose needs attention'), findsOneWidget);
    expect(find.text('Prototype-safe'), findsNothing);
    expect(find.text('Local-only'), findsNothing);
    expect(find.textContaining('Safety acknowledgement'), findsNothing);

    await tester.tap(find.text("Today's doses"));
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('hides Robot Face shortcut when unavailable', (tester) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(
      DoseyAppScope(
        database: database,
        bleGateway: FakeBleGateway(),
        connectivityGateway: FakeConnectivityGateway(),
        missedDoseReconciliationService: FakeMissedDoseReconciliationService(),
        child: MaterialApp(
          home: Scaffold(
            body: DashboardScreen(
              showRobotFaceShortcut: false,
              onOpenSchedule: () {},
              onOpenCarousel: () {},
              onOpenSettings: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Robot Face'), findsNothing);
  });
}

Future<void> _seedSchedule(DoseyDatabase database, String id, int hour) {
  return LocalReminderRepository(database).upsertSchedule(
    ReminderSchedule(
      id: id,
      label: '$id dose',
      hour: hour,
      minute: 0,
      isEnabled: true,
      createdAt: DateTime(2040),
      updatedAt: DateTime(2040),
    ),
  );
}
