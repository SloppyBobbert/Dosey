import 'package:dosey_app/core/caregiver/caregiver_snapshot.dart';
import 'package:dosey_app/core/caregiver/caregiver_status_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final medication = CaregiverMedication(
    id: 'med-1',
    name: 'Morning medicine',
    instructions: 'Take with water',
    active: true,
    version: 1,
  );

  CaregiverSnapshot snapshot({
    required CaregiverSchedule schedule,
    List<CaregiverDoseEvent> events = const [],
  }) => CaregiverSnapshot(
    householdId: 'household-1',
    revision: 'revision-1',
    generatedAt: DateTime.utc(2026, 7, 29, 8),
    medications: [medication],
    schedules: [schedule],
    events: events,
  );

  test('projects upcoming, due, and missed daily doses', () {
    final schedule = CaregiverSchedule(
      id: 'schedule-1',
      medicationId: medication.id,
      label: 'Breakfast',
      hour: 9,
      minute: 0,
      enabled: true,
      version: 1,
    );

    expect(
      projectCaregiverDay(
        snapshot: snapshot(schedule: schedule),
        now: DateTime.utc(2026, 7, 29, 8, 30),
      ).single.status,
      CaregiverDoseStatus.upcoming,
    );
    expect(
      projectCaregiverDay(
        snapshot: snapshot(schedule: schedule),
        now: DateTime.utc(2026, 7, 29, 9, 10),
      ).single.status,
      CaregiverDoseStatus.due,
    );
    expect(
      projectCaregiverDay(
        snapshot: snapshot(schedule: schedule),
        now: DateTime.utc(2026, 7, 29, 11),
      ).single.status,
      CaregiverDoseStatus.missed,
    );
  });

  test('event status overrides derived schedule status', () {
    final schedule = CaregiverSchedule(
      id: 'schedule-1',
      medicationId: medication.id,
      label: 'Breakfast',
      hour: 9,
      minute: 0,
      enabled: true,
      version: 1,
    );
    for (final action in CaregiverDoseAction.values) {
      final dueAt = DateTime.utc(2026, 7, 29, 9);
      final result = projectCaregiverDay(
        snapshot: snapshot(
          schedule: schedule,
          events: [
            CaregiverDoseEvent(
              id: 'event-1',
              scheduleId: schedule.id,
              scheduledFor: dueAt,
              occurredAt: dueAt.add(const Duration(minutes: 4)),
              action: action,
            ),
          ],
        ),
        now: DateTime.utc(2026, 7, 29, 11),
      ).single;

      expect(result.status, switch (action) {
        CaregiverDoseAction.taken => CaregiverDoseStatus.taken,
        CaregiverDoseAction.skipped => CaregiverDoseStatus.skipped,
        CaregiverDoseAction.snoozed => CaregiverDoseStatus.snoozed,
        CaregiverDoseAction.helpRequested => CaregiverDoseStatus.helpRequested,
      });
    }
  });

  test('projects wall-clock schedules in their canonical timezone', () {
    final schedule = CaregiverSchedule(
      id: 'schedule-1',
      medicationId: medication.id,
      label: 'Breakfast',
      hour: 9,
      minute: 0,
      timezoneId: 'America/Los_Angeles',
      enabled: true,
      version: 1,
    );

    final result = projectCaregiverDay(
      snapshot: snapshot(schedule: schedule),
      now: DateTime.utc(2026, 7, 29, 16, 10),
    ).single;

    expect(result.status, CaregiverDoseStatus.due);
    expect(result.scheduledFor, DateTime.utc(2026, 7, 29, 16));
  });

  test('excludes disabled schedules and inactive medications', () {
    final schedule = CaregiverSchedule(
      id: 'schedule-1',
      medicationId: medication.id,
      label: 'Breakfast',
      hour: 9,
      minute: 0,
      enabled: false,
      version: 1,
    );
    expect(
      projectCaregiverDay(
        snapshot: snapshot(schedule: schedule),
        now: DateTime.utc(2026, 7, 29, 9),
      ),
      isEmpty,
    );
  });

  test('rejects invalid schedule times', () {
    expect(
      () => CaregiverSchedule(
        id: 'schedule-1',
        medicationId: medication.id,
        label: 'Breakfast',
        hour: 24,
        minute: 0,
        enabled: true,
        version: 1,
      ),
      throwsArgumentError,
    );
  });
}
