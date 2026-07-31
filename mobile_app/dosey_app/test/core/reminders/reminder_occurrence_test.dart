import 'package:dosey_app/core/reminders/reminder_occurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the schedule revision and UTC instant as its opaque identity', () {
    final occurrence = ReminderOccurrence(
      scheduleId: 'morning',
      scheduleRevision: 7,
      scheduledAtUtc: DateTime.utc(2026, 7, 30, 15, 30),
      localDate: '2026-07-30',
      timezoneId: 'America/Los_Angeles',
      medicationId: 'prescription-1',
      profileId: 'profile-1',
    );

    expect(occurrence.id, 'morning:7:2026-07-30T15:30:00.000Z');
    expect(occurrence.scheduledAtUtc, DateTime.utc(2026, 7, 30, 15, 30));
    expect(occurrence.medicationId, 'prescription-1');
    expect(occurrence.profileId, 'profile-1');
  });

  test('rejects non-positive revisions and non-UTC instants', () {
    expect(
      () => ReminderOccurrence(
        scheduleId: 'morning',
        scheduleRevision: 0,
        scheduledAtUtc: DateTime.utc(2026),
        localDate: '2026-01-01',
        timezoneId: 'UTC',
        medicationId: 'prescription-1',
        profileId: 'profile-1',
      ),
      throwsArgumentError,
    );
    expect(
      () => ReminderOccurrence(
        scheduleId: 'morning',
        scheduleRevision: 1,
        scheduledAtUtc: DateTime(2026),
        localDate: '2026-01-01',
        timezoneId: 'UTC',
        medicationId: 'prescription-1',
        profileId: 'profile-1',
      ),
      throwsArgumentError,
    );
  });

  test('rejects invalid snapshot fields and local-date mismatches', () {
    final valid = (
      scheduleId: 'morning',
      scheduledAtUtc: DateTime.utc(2026, 7, 30, 15, 30),
      localDate: '2026-07-30',
      timezoneId: 'America/Los_Angeles',
      medicationId: 'prescription-1',
      profileId: 'profile-1',
    );
    for (final invalid in ['', ' ', '\t']) {
      expect(
        () => ReminderOccurrence(
          scheduleId: invalid,
          scheduleRevision: 1,
          scheduledAtUtc: valid.scheduledAtUtc,
          localDate: valid.localDate,
          timezoneId: valid.timezoneId,
          medicationId: valid.medicationId,
          profileId: valid.profileId,
        ),
        throwsArgumentError,
      );
    }
    for (final invalidDate in ['2026-7-30', '2026-02-30', '0000-01-01']) {
      expect(
        () => ReminderOccurrence(
          scheduleId: valid.scheduleId,
          scheduleRevision: 1,
          scheduledAtUtc: valid.scheduledAtUtc,
          localDate: invalidDate,
          timezoneId: valid.timezoneId,
          medicationId: valid.medicationId,
          profileId: valid.profileId,
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => ReminderOccurrence(
        scheduleId: valid.scheduleId,
        scheduleRevision: 1,
        scheduledAtUtc: valid.scheduledAtUtc,
        localDate: valid.localDate,
        timezoneId: 'Mars/Olympus_Mons',
        medicationId: valid.medicationId,
        profileId: valid.profileId,
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ReminderOccurrence(
        scheduleId: valid.scheduleId,
        scheduleRevision: 1,
        scheduledAtUtc: valid.scheduledAtUtc,
        localDate: '2026-07-29',
        timezoneId: valid.timezoneId,
        medicationId: valid.medicationId,
        profileId: valid.profileId,
      ),
      throwsArgumentError,
    );
  });

  test('preserves UTC microseconds in the opaque identity', () {
    final occurrence = ReminderOccurrence(
      scheduleId: 'morning',
      scheduleRevision: 1,
      scheduledAtUtc: DateTime.utc(2026, 7, 30, 15, 30, 0, 123, 456),
      localDate: '2026-07-30',
      timezoneId: 'America/Los_Angeles',
      medicationId: 'prescription-1',
      profileId: 'profile-1',
    );

    expect(occurrence.scheduledAtUtc.microsecond, 456);
    expect(occurrence.id, 'morning:1:2026-07-30T15:30:00.123456Z');
  });
}
