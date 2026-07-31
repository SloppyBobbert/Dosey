import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_occurrence_projection.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'projects only enabled linked schedules in a half-open UTC range',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalReminderRepository(database);
      final now = DateTime.utc(2026, 7, 30);
      await repository.upsertSchedule(_schedule('later', 9, now));
      await repository.upsertSchedule(_schedule('earlier', 8, now));
      await repository.upsertSchedule(
        _schedule('disabled', 7, now, isEnabled: false),
      );
      await repository.upsertSchedule(
        _schedule('unlinked-null', 10, now, prescriptionId: null),
      );
      await repository.upsertSchedule(
        _schedule('unlinked-blank', 11, now, prescriptionId: ''),
      );

      final occurrences = await ReminderOccurrenceProjection(database).project(
        asOf: DateTime.utc(2026, 7, 30, 15),
        fromInclusive: DateTime.utc(2026, 7, 30, 15),
        toExclusive: DateTime.utc(2026, 7, 31, 15),
        timezoneId: 'America/Los_Angeles',
      );

      expect(occurrences.map((occurrence) => occurrence.scheduleId), [
        'earlier',
        'later',
      ]);
      expect(occurrences.map((occurrence) => occurrence.medicationId), [
        'prescription-1',
        'prescription-1',
      ]);
      expect(occurrences.map((occurrence) => occurrence.scheduleRevision), [
        1,
        1,
      ]);
      expect(
        occurrences.singleWhere((value) => value.scheduleId == 'earlier').id,
        'earlier:1:2026-07-30T15:00:00.000Z',
      );
    },
  );

  test(
    'returned snapshots stay unchanged while later projections use updates',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalReminderRepository(database);
      final now = DateTime.utc(2026, 7, 30);
      final schedule = _schedule('morning', 8, now);
      final projection = ReminderOccurrenceProjection(database);
      await repository.upsertSchedule(schedule);

      final first = (await projection.project(
        asOf: DateTime.utc(2026, 7, 30),
        fromInclusive: DateTime.utc(2026, 7, 30),
        toExclusive: DateTime.utc(2026, 7, 31),
        timezoneId: 'America/Los_Angeles',
      )).single;

      await repository.upsertSchedule(
        schedule.copyWith(
          hour: 9,
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );
      final later = (await projection.project(
        asOf: DateTime.utc(2026, 7, 30, 0, 1),
        fromInclusive: DateTime.utc(2026, 7, 30, 0, 1),
        toExclusive: DateTime.utc(2026, 7, 31),
        timezoneId: 'UTC',
      )).single;

      expect(first.scheduleRevision, 1);
      expect(first.scheduledAtUtc, DateTime.utc(2026, 7, 30, 15));
      expect(first.timezoneId, 'America/Los_Angeles');
      expect(later.scheduleRevision, 2);
      expect(later.scheduledAtUtc, DateTime.utc(2026, 7, 30, 9));
      expect(later.timezoneId, 'UTC');
    },
  );

  test(
    'uses as-of and profile filtering without reconstructing history',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalReminderRepository(database);
      final now = DateTime.utc(2026, 7, 30);
      await repository.upsertSchedule(_schedule('default', 8, now));
      await repository.upsertSchedule(
        _schedule('travel', 8, now, profileId: 'travel'),
      );
      final projection = ReminderOccurrenceProjection(database);

      final occurrences = await projection.project(
        asOf: DateTime.utc(2026, 7, 30, 14),
        fromInclusive: DateTime.utc(2026, 7, 30, 14),
        toExclusive: DateTime.utc(2026, 7, 30, 17),
        timezoneId: 'America/Los_Angeles',
        profileId: 'travel',
      );

      expect(occurrences.map((occurrence) => occurrence.scheduleId), [
        'travel',
      ]);
    },
  );

  test('orders equal instants by schedule ID', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalReminderRepository(database);
    final now = DateTime.utc(2026, 7, 30);
    await repository.upsertSchedule(_schedule('zeta', 8, now));
    await repository.upsertSchedule(
      _schedule('alpha', 8, now, prescriptionId: 'prescription-2'),
    );

    final occurrences = await ReminderOccurrenceProjection(database).project(
      asOf: DateTime.utc(2026, 7, 30, 15),
      fromInclusive: DateTime.utc(2026, 7, 30, 15),
      toExclusive: DateTime.utc(2026, 7, 30, 16),
      timezoneId: 'America/Los_Angeles',
    );

    expect(occurrences.map((occurrence) => occurrence.scheduleId), [
      'alpha',
      'zeta',
    ]);
  });

  test('requires explicit UTC and valid prospective ranges', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final projection = ReminderOccurrenceProjection(database);
    final utc = DateTime.utc(2026, 7, 30);

    expect(
      projection.project(
        asOf: DateTime(2026, 7, 30),
        fromInclusive: utc,
        toExclusive: utc.add(const Duration(days: 1)),
        timezoneId: 'UTC',
      ),
      throwsArgumentError,
    );
    expect(
      projection.project(
        asOf: utc.add(const Duration(hours: 1)),
        fromInclusive: utc,
        toExclusive: utc.add(const Duration(days: 1)),
        timezoneId: 'UTC',
      ),
      throwsArgumentError,
    );
    expect(
      projection.project(
        asOf: utc,
        fromInclusive: utc,
        toExclusive: utc,
        timezoneId: 'UTC',
      ),
      throwsArgumentError,
    );
    expect(
      projection.project(
        asOf: utc,
        fromInclusive: utc,
        toExclusive: utc.add(const Duration(days: 1)),
        timezoneId: 'Mars/Olympus_Mons',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

ReminderSchedule _schedule(
  String id,
  int hour,
  DateTime now, {
  String? prescriptionId = 'prescription-1',
  String profileId = ReminderSchedule.defaultProfileId,
  bool isEnabled = true,
}) {
  return ReminderSchedule(
    id: id,
    label: id,
    prescriptionId: prescriptionId,
    profileId: profileId,
    hour: hour,
    minute: 0,
    isEnabled: isEnabled,
    createdAt: now,
    updatedAt: now,
  );
}
