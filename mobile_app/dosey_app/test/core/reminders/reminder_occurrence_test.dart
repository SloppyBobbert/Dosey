import 'package:dosey_app/core/reminders/reminder_occurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('identity uses schedule revision and scheduled UTC instant', () {
    final occurrence = ReminderOccurrence(
      scheduleId: 'schedule-1',
      scheduleRevision: 7,
      scheduledAt: DateTime.parse('2026-07-30T15:00:00-07:00'),
      localDate: '2026-07-30',
      timezoneId: 'America/Los_Angeles',
    );

    expect(occurrence.occurrenceId, 'schedule-1:7:2026-07-30T22:00:00.000Z');
    expect(occurrence.scheduledAt, DateTime.utc(2026, 7, 30, 22));
  });

  test('wall clock and timezone label changes do not alter identity', () {
    final first = ReminderOccurrence(
      scheduleId: 'schedule-1',
      scheduleRevision: 7,
      scheduledAt: DateTime.utc(2026, 7, 30, 22),
      localDate: '2026-07-30',
      timezoneId: 'America/Los_Angeles',
    );
    final afterTimezoneChange = ReminderOccurrence(
      scheduleId: 'schedule-1',
      scheduleRevision: 7,
      scheduledAt: DateTime.utc(2026, 7, 30, 22),
      localDate: '2026-07-31',
      timezoneId: 'Pacific/Auckland',
    );

    expect(afterTimezoneChange.occurrenceId, first.occurrenceId);
  });

  test('schedule edits produce a new identity at the same instant', () {
    final before = ReminderOccurrence(
      scheduleId: 'schedule-1',
      scheduleRevision: 7,
      scheduledAt: DateTime.utc(2026, 7, 30, 22),
      localDate: '2026-07-30',
      timezoneId: 'UTC',
    );
    final after = ReminderOccurrence(
      scheduleId: 'schedule-1',
      scheduleRevision: 8,
      scheduledAt: DateTime.utc(2026, 7, 30, 22),
      localDate: '2026-07-30',
      timezoneId: 'UTC',
    );

    expect(after.occurrenceId, isNot(before.occurrenceId));
  });
}
