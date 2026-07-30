import 'package:dosey_app/core/logging/phone_dose_action_service.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/phone_only_missed_dose_reconciliation_service.dart';
import 'package:dosey_app/core/reminders/reminder_occurrence.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('records overdue misses once without touching carousel state', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final reminders = LocalReminderRepository(
      database,
      hardwareEffectsEnabled: false,
    );
    await reminders.upsertSchedule(
      ReminderSchedule(
        id: 'morning',
        label: 'Morning',
        prescriptionId: 'med-1',
        hour: 8,
        minute: 0,
        isEnabled: true,
        createdAt: DateTime.utc(2040),
        updatedAt: DateTime.utc(2040),
      ),
    );
    final service = PhoneOnlyMissedDoseReconciliationService(
      reminders: reminders,
      actions: PhoneDoseActionService(database),
      deviceId: () async => 'phone-0123456789abcdef',
      timezoneId: () async => 'UTC',
      now: () => DateTime.utc(2040, 1, 2, 10, 1),
      gracePeriod: const Duration(hours: 2),
    );

    await service.reconcile();
    await service.reconcile();

    final events = await database.select(database.phoneDoseActionEvents).get();
    expect(events, hasLength(2));
    expect(
      events.every(
        (event) => event.kind == PhoneDoseActionKind.missed.storageValue,
      ),
      isTrue,
    );
    expect(events.every((event) => !event.marksDoseTaken), isTrue);
    expect(await database.select(database.syncOutboxMutations).get(), isEmpty);
    expect(await database.select(database.carouselSlots).get(), isEmpty);
    expect(
      await database.select(database.medicationShortageAlerts).get(),
      isEmpty,
    );
  });

  test('clock rollback and restart do not duplicate an occurrence', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final reminders = LocalReminderRepository(
      database,
      hardwareEffectsEnabled: false,
    );
    await reminders.upsertSchedule(
      ReminderSchedule(
        id: 'morning',
        label: 'Morning',
        hour: 8,
        minute: 0,
        isEnabled: true,
        createdAt: DateTime.utc(2040),
        updatedAt: DateTime.utc(2040),
      ),
    );
    var now = DateTime.utc(2040, 1, 2, 11);
    PhoneOnlyMissedDoseReconciliationService build() =>
        PhoneOnlyMissedDoseReconciliationService(
          reminders: reminders,
          actions: PhoneDoseActionService(database),
          deviceId: () async => 'phone-0123456789abcdef',
          timezoneId: () async => 'UTC',
          now: () => now,
          gracePeriod: const Duration(hours: 2),
        );

    await build().reconcile();
    now = DateTime.utc(2040, 1, 2, 10, 30);
    await build().reconcile();

    expect(
      await database.select(database.phoneDoseActionEvents).get(),
      hasLength(2),
    );
  });

  test(
    'uses the configured local day and preserves a seeded terminal action',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final reminders = LocalReminderRepository(
        database,
        hardwareEffectsEnabled: false,
      );
      await reminders.upsertSchedule(
        ReminderSchedule(
          id: 'morning',
          label: 'Morning',
          hour: 8,
          minute: 0,
          isEnabled: true,
          createdAt: DateTime.utc(2040),
          updatedAt: DateTime.utc(2040),
        ),
      );
      final actions = PhoneDoseActionService(database);
      final service = PhoneOnlyMissedDoseReconciliationService(
        reminders: reminders,
        actions: actions,
        deviceId: () async => 'phone-0123456789abcdef',
        timezoneId: () async => 'America/Los_Angeles',
        now: () => DateTime.utc(2040, 1, 2, 18),
      );
      await actions.record(
        PhoneDoseActionRequest(
          occurrence: ReminderOccurrence(
            scheduleId: 'morning',
            scheduleRevision: 1,
            scheduledAt: DateTime.utc(2040, 1, 2, 16),
            localDate: '2040-01-02',
            timezoneId: 'America/Los_Angeles',
          ),
          medicationId: 'morning',
          kind: PhoneDoseActionKind.takenConfirmed,
          occurredAt: DateTime.utc(2040, 1, 2, 17),
          deviceId: 'phone-0123456789abcdef',
        ),
      );
      await actions.record(
        PhoneDoseActionRequest(
          occurrence: ReminderOccurrence(
            scheduleId: 'morning',
            scheduleRevision: 1,
            scheduledAt: DateTime.utc(2040, 1, 1, 16),
            localDate: '2040-01-01',
            timezoneId: 'America/Los_Angeles',
          ),
          medicationId: 'morning',
          kind: PhoneDoseActionKind.skipped,
          occurredAt: DateTime.utc(2040, 1, 2, 17),
          deviceId: 'phone-0123456789abcdef',
        ),
      );

      await service.reconcile();

      final events = await database
          .select(database.phoneDoseActionEvents)
          .get();
      expect(events, hasLength(2));
      expect(
        events.any(
          (event) => event.kind == PhoneDoseActionKind.missed.storageValue,
        ),
        isFalse,
      );
    },
  );
}
