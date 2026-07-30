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
              occurrenceId: 'schedule-1:1:2026-07-29T09:00:00.000Z',
              scheduleId: schedule.id,
              scheduleRevision: schedule.version,
              scheduledFor: dueAt,
              localDate: '2026-07-29',
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
      expect(
        result.hasTerminalOutcome,
        action == CaregiverDoseAction.taken ||
            action == CaregiverDoseAction.skipped,
      );
    }
  });

  test('matches events by exact occurrence identity and schedule revision', () {
    final schedule = _schedule(version: 2);
    final dueAt = DateTime.utc(2026, 7, 29, 9);
    final result = projectCaregiverDay(
      snapshot: snapshot(
        schedule: schedule,
        events: [
          _event(
            id: 'old-revision',
            occurrenceId: 'schedule-1:1:2026-07-29T09:00:00.000Z',
            revision: 1,
            scheduledFor: dueAt,
            action: CaregiverDoseAction.taken,
          ),
          _event(
            id: 'wrong-occurrence',
            occurrenceId: 'schedule-1:2:2026-07-29T09:00:30.000Z',
            revision: 2,
            scheduledFor: dueAt,
            action: CaregiverDoseAction.taken,
          ),
        ],
      ),
      now: dueAt.add(const Duration(minutes: 10)),
    ).single;

    expect(result.status, CaregiverDoseStatus.due);
    expect(result.hasTerminalOutcome, isFalse);
  });

  test('ignores events with any mismatched occurrence identity field', () {
    final schedule = _schedule();
    final dueAt = DateTime.utc(2026, 7, 29, 9);
    final occurrenceId = 'schedule-1:1:2026-07-29T09:00:00.000Z';
    final events = <CaregiverDoseEvent>[
      _event(
        id: 'wrong-occurrence-id',
        occurrenceId: 'other-occurrence',
        scheduledFor: dueAt,
        action: CaregiverDoseAction.taken,
      ),
      _event(
        id: 'wrong-schedule-id',
        occurrenceId: occurrenceId,
        scheduleId: 'other-schedule',
        scheduledFor: dueAt,
        action: CaregiverDoseAction.taken,
      ),
      _event(
        id: 'wrong-revision',
        occurrenceId: occurrenceId,
        revision: 2,
        scheduledFor: dueAt,
        action: CaregiverDoseAction.taken,
      ),
      _event(
        id: 'wrong-instant',
        occurrenceId: occurrenceId,
        scheduledFor: dueAt.add(const Duration(minutes: 1)),
        action: CaregiverDoseAction.taken,
      ),
      _event(
        id: 'wrong-timezone',
        occurrenceId: occurrenceId,
        scheduledFor: dueAt,
        timezoneId: 'America/Los_Angeles',
        action: CaregiverDoseAction.taken,
      ),
      _event(
        id: 'wrong-local-date',
        occurrenceId: occurrenceId,
        scheduledFor: dueAt,
        localDate: '2026-07-28',
        action: CaregiverDoseAction.taken,
      ),
    ];

    final result = projectCaregiverDay(
      snapshot: snapshot(schedule: schedule, events: events),
      now: dueAt.add(const Duration(minutes: 10)),
    ).single;

    expect(result.status, CaregiverDoseStatus.due);
    expect(result.event, isNull);
  });

  test('orders equal instants by schedule then occurrence identity', () {
    final secondSchedule = CaregiverSchedule(
      id: 'schedule-2',
      medicationId: medication.id,
      label: 'Second breakfast',
      hour: 9,
      minute: 0,
      enabled: true,
      version: 1,
    );
    final result = projectCaregiverDay(
      snapshot: CaregiverSnapshot(
        householdId: 'household-1',
        revision: 'revision-1',
        generatedAt: DateTime.utc(2026, 7, 29, 8),
        medications: [medication],
        schedules: [secondSchedule, _schedule()],
        events: const [],
      ),
      now: DateTime.utc(2026, 7, 29, 8),
    );

    expect(result.map((dose) => dose.occurrence.scheduleId), [
      'schedule-1',
      'schedule-2',
    ]);
  });

  test('terminal outcome dominates later help and snooze events', () {
    final schedule = _schedule();
    final dueAt = DateTime.utc(2026, 7, 29, 9);
    const occurrenceId = 'schedule-1:1:2026-07-29T09:00:00.000Z';
    final result = projectCaregiverDay(
      snapshot: snapshot(
        schedule: schedule,
        events: [
          _event(
            id: 'taken',
            occurrenceId: occurrenceId,
            scheduledFor: dueAt,
            action: CaregiverDoseAction.taken,
          ),
          _event(
            id: 'help',
            occurrenceId: occurrenceId,
            scheduledFor: dueAt,
            occurredAt: dueAt.add(const Duration(minutes: 1)),
            action: CaregiverDoseAction.helpRequested,
          ),
          _event(
            id: 'snooze',
            occurrenceId: occurrenceId,
            scheduledFor: dueAt,
            occurredAt: dueAt.add(const Duration(minutes: 2)),
            action: CaregiverDoseAction.snoozed,
          ),
        ],
      ),
      now: dueAt.add(const Duration(hours: 1)),
    ).single;

    expect(result.status, CaregiverDoseStatus.taken);
    expect(result.hasTerminalOutcome, isTrue);
  });

  test(
    'contradictory terminal history remains ineligible for terminal actions',
    () {
      final schedule = _schedule();
      final dueAt = DateTime.utc(2026, 7, 29, 9);
      const occurrenceId = 'schedule-1:1:2026-07-29T09:00:00.000Z';
      final result = projectCaregiverDay(
        snapshot: snapshot(
          schedule: schedule,
          events: [
            _event(
              id: 'taken',
              occurrenceId: occurrenceId,
              scheduledFor: dueAt,
              action: CaregiverDoseAction.taken,
            ),
            _event(
              id: 'skipped',
              occurrenceId: occurrenceId,
              scheduledFor: dueAt,
              occurredAt: dueAt.add(const Duration(minutes: 1)),
              action: CaregiverDoseAction.skipped,
            ),
          ],
        ),
        now: dueAt.add(const Duration(hours: 1)),
      ).single;

      expect(result.status, CaregiverDoseStatus.skipped);
      expect(result.hasTerminalOutcome, isTrue);
    },
  );

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

CaregiverSchedule _schedule({int version = 1}) => CaregiverSchedule(
  id: 'schedule-1',
  medicationId: 'med-1',
  label: 'Breakfast',
  hour: 9,
  minute: 0,
  enabled: true,
  version: version,
);

CaregiverDoseEvent _event({
  required String id,
  required String occurrenceId,
  required DateTime scheduledFor,
  required CaregiverDoseAction action,
  int revision = 1,
  DateTime? occurredAt,
  String scheduleId = 'schedule-1',
  String timezoneId = 'UTC',
  String localDate = '2026-07-29',
}) => CaregiverDoseEvent(
  id: id,
  occurrenceId: occurrenceId,
  scheduleId: scheduleId,
  scheduleRevision: revision,
  scheduledFor: scheduledFor,
  timezoneId: timezoneId,
  localDate: localDate,
  occurredAt: occurredAt ?? scheduledFor,
  action: action,
);
