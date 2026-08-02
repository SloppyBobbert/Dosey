import 'package:dosey_app/core/reminders/reminder_occurrence.dart';
import 'package:dosey_app/core/reminders/reminder_occurrence_read_state.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const projection = ReminderOccurrenceReadStateProjection();
  final occurrence = _occurrence(DateTime.utc(2026, 8, 1, 9));

  test('rejects a local as-of instant', () {
    expect(
      () => projection.project(
        occurrence: occurrence,
        actions: const [],
        asOfUtc: DateTime(2026, 8, 1, 8),
      ),
      throwsArgumentError,
    );
  });

  test('projects upcoming with an exact positive countdown', () {
    final state = projection.project(
      occurrence: occurrence,
      actions: const [],
      asOfUtc: DateTime.utc(2026, 8, 1, 8, 45),
    );

    expect(state.phase, ReminderOccurrencePhase.upcoming);
    expect(state.countdown, const Duration(minutes: 15));
    expect(state.missedElapsed, isNull);
    expect(state.terminal, isFalse);
  });

  test('projects ready exactly at the scheduled instant', () {
    final state = projection.project(
      occurrence: occurrence,
      actions: const [],
      asOfUtc: occurrence.scheduledAtUtc,
    );

    expect(state.phase, ReminderOccurrencePhase.ready);
    expect(state.countdown, isNull);
    expect(state.missedElapsed, isNull);
  });

  test('keeps a far-past occurrence ready without a missed action', () {
    final state = projection.project(
      occurrence: occurrence,
      actions: const [],
      asOfUtc: DateTime.utc(2026, 8, 3, 9),
    );

    expect(state.phase, ReminderOccurrencePhase.ready);
    expect(state.countdown, isNull);
    expect(state.missedElapsed, isNull);
  });

  test('ignores actions for another occurrence', () {
    final state = projection.project(
      occurrence: occurrence,
      actions: [_action(occurrenceId: 'another-occurrence', kind: 'missed')],
      asOfUtc: DateTime.utc(2026, 8, 1, 10),
    );

    expect(state.phase, ReminderOccurrencePhase.ready);
    expect(state.missedElapsed, isNull);
  });

  test('derives missed elapsed from the earliest missed action', () {
    final state = projection.project(
      occurrence: occurrence,
      actions: [
        _action(kind: 'missed', occurredAt: DateTime.utc(2026, 8, 1, 9, 30)),
        _action(kind: 'missed', occurredAt: DateTime.utc(2026, 8, 1, 9, 15)),
      ],
      asOfUtc: DateTime.utc(2026, 8, 1, 10),
    );

    expect(state.phase, ReminderOccurrencePhase.missed);
    expect(state.countdown, isNull);
    expect(state.missedElapsed, const Duration(minutes: 45));
  });

  test('clamps missed elapsed when the missed action is in the future', () {
    final state = projection.project(
      occurrence: occurrence,
      actions: [
        _action(kind: 'missed', occurredAt: DateTime.utc(2026, 8, 1, 11)),
      ],
      asOfUtc: DateTime.utc(2026, 8, 1, 10),
    );

    expect(state.phase, ReminderOccurrencePhase.missed);
    expect(state.missedElapsed, Duration.zero);
  });

  test('acknowledgement neither creates nor clears missed state', () {
    final acknowledgedOnly = projection.project(
      occurrence: occurrence,
      actions: [_action(kind: 'missed_acknowledged')],
      asOfUtc: DateTime.utc(2026, 8, 1, 10),
    );
    final acknowledgedMissed = projection.project(
      occurrence: occurrence,
      actions: [
        _action(kind: 'missed', occurredAt: DateTime.utc(2026, 8, 1, 9, 5)),
        _action(
          kind: 'missed_acknowledged',
          occurredAt: DateTime.utc(2026, 8, 1, 9, 10),
        ),
      ],
      asOfUtc: DateTime.utc(2026, 8, 1, 10),
    );

    expect(acknowledgedOnly.phase, ReminderOccurrencePhase.ready);
    expect(acknowledgedMissed.phase, ReminderOccurrencePhase.missed);
    expect(acknowledgedMissed.missedElapsed, const Duration(minutes: 55));
  });

  test('terminal action overrides missed state', () {
    final state = projection.project(
      occurrence: occurrence,
      actions: [
        _action(kind: 'missed', occurredAt: DateTime.utc(2026, 8, 1, 9, 5)),
        _action(kind: 'skipped', occurredAt: DateTime.utc(2026, 8, 1, 9, 10)),
      ],
      asOfUtc: DateTime.utc(2026, 8, 1, 10),
    );

    expect(state.phase, ReminderOccurrencePhase.skipped);
    expect(state.terminal, isTrue);
    expect(state.countdown, isNull);
    expect(state.missedElapsed, isNull);
  });

  test('uses the latest terminal action and takes wins timestamp ties', () {
    final latest = projection.project(
      occurrence: occurrence,
      actions: [
        _action(
          kind: 'taken_confirmed',
          occurredAt: DateTime.utc(2026, 8, 1, 9, 10),
        ),
        _action(kind: 'skipped', occurredAt: DateTime.utc(2026, 8, 1, 9, 15)),
      ],
      asOfUtc: DateTime.utc(2026, 8, 1, 10),
    );
    final tied = projection.project(
      occurrence: occurrence,
      actions: [
        _action(kind: 'skipped', occurredAt: DateTime.utc(2026, 8, 1, 9, 15)),
        _action(
          kind: 'taken_confirmed',
          occurredAt: DateTime.utc(2026, 8, 1, 9, 15),
        ),
      ],
      asOfUtc: DateTime.utc(2026, 8, 1, 10),
    );
    final reversedTie = projection.project(
      occurrence: occurrence,
      actions: [
        _action(
          kind: 'taken_confirmed',
          occurredAt: DateTime.utc(2026, 8, 1, 9, 15),
        ),
        _action(kind: 'skipped', occurredAt: DateTime.utc(2026, 8, 1, 9, 15)),
      ],
      asOfUtc: DateTime.utc(2026, 8, 1, 10),
    );

    expect(latest.phase, ReminderOccurrencePhase.skipped);
    expect(tied.phase, ReminderOccurrencePhase.taken);
    expect(reversedTie.phase, ReminderOccurrencePhase.taken);
  });

  test('terminal action overrides a newer missed action', () {
    final state = projection.project(
      occurrence: occurrence,
      actions: [
        _action(kind: 'skipped', occurredAt: DateTime.utc(2026, 8, 1, 9, 5)),
        _action(kind: 'missed', occurredAt: DateTime.utc(2026, 8, 1, 9, 15)),
      ],
      asOfUtc: DateTime.utc(2026, 8, 1, 10),
    );

    expect(state.phase, ReminderOccurrencePhase.skipped);
    expect(state.missedElapsed, isNull);
  });

  test('future taken confirmation overrides immediately under clock skew', () {
    final state = projection.project(
      occurrence: occurrence,
      actions: [
        _action(
          kind: 'taken_confirmed',
          occurredAt: DateTime.utc(2026, 8, 1, 11),
        ),
      ],
      asOfUtc: DateTime.utc(2026, 8, 1, 10),
    );

    expect(state.phase, ReminderOccurrencePhase.taken);
    expect(state.terminal, isTrue);
  });
}

ReminderOccurrence _occurrence(DateTime scheduledAtUtc) => ReminderOccurrence(
  scheduleId: 'schedule-1',
  scheduleRevision: 1,
  scheduledAtUtc: scheduledAtUtc,
  localDate: '2026-08-01',
  timezoneId: 'UTC',
  medicationId: 'medication-1',
  profileId: 'profile-1',
);

PhoneDoseActionEventRow _action({
  String? occurrenceId,
  required String kind,
  DateTime? occurredAt,
}) {
  final timestamp = occurredAt ?? DateTime.utc(2026, 8, 1, 9);
  return PhoneDoseActionEventRow(
    id: '$kind-${timestamp.microsecondsSinceEpoch}',
    deviceId: 'device-1',
    occurrenceId: occurrenceId ?? _occurrence(DateTime.utc(2026, 8, 1, 9)).id,
    scheduleId: 'schedule-1',
    scheduleRevision: 1,
    scheduledAt: DateTime.utc(2026, 8, 1, 9),
    localDate: '2026-08-01',
    timezoneId: 'UTC',
    medicationId: 'medication-1',
    kind: kind,
    occurredAt: timestamp,
    marksDoseTaken: kind == 'taken_confirmed',
    idempotencyKey: '$kind-${timestamp.microsecondsSinceEpoch}',
    createdAt: timestamp,
  );
}
