import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local reminder repository starts empty', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalReminderRepository(database);

    expect(await repository.watchSchedules().first, isEmpty);
  });

  test('local reminder repository persists schedules', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalReminderRepository(database);
    final createdAt = DateTime.utc(2026, 6, 9, 8);
    final schedule = ReminderSchedule(
      id: 'morning',
      label: 'Morning dose',
      hour: 8,
      minute: 30,
      isEnabled: true,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    await repository.upsertSchedule(schedule);

    final schedules = await repository.watchSchedules().first;
    expect(schedules, hasLength(1));
    expect(schedules.single.id, 'morning');
    expect(schedules.single.label, 'Morning dose');
    expect(schedules.single.hour, 8);
    expect(schedules.single.minute, 30);
    expect(schedules.single.isEnabled, isTrue);
    expect(schedules.single.createdAt, createdAt);
    expect(schedules.single.updatedAt, createdAt);
    expect(schedules.single.revision, 1);
  });

  test('schedule edits advance the persisted occurrence revision', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalReminderRepository(database);
    final createdAt = DateTime.utc(2026, 6, 9, 8);
    final schedule = ReminderSchedule(
      id: 'morning',
      label: 'Morning dose',
      hour: 8,
      minute: 30,
      isEnabled: true,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    await repository.upsertSchedule(schedule);
    await repository.upsertSchedule(
      schedule.copyWith(
        minute: 45,
        updatedAt: createdAt.add(const Duration(minutes: 1)),
      ),
    );

    final afterRestart = LocalReminderRepository(database);
    final persisted = (await afterRestart.watchSchedules().first).single;
    expect(persisted.revision, 2);
    expect(persisted.minute, 45);
  });

  test('cosmetic and no-op saves preserve occurrence revision', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalReminderRepository(database);
    final createdAt = DateTime.utc(2026, 6, 9, 8);
    final schedule = ReminderSchedule(
      id: 'morning',
      label: 'Morning dose',
      hour: 8,
      minute: 30,
      isEnabled: true,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    await repository.upsertSchedule(schedule);
    await repository.upsertSchedule(
      schedule.copyWith(
        label: 'Morning medicine',
        updatedAt: createdAt.add(const Duration(minutes: 1)),
      ),
    );
    await repository.upsertSchedule(
      schedule.copyWith(
        label: 'Morning medicine',
        updatedAt: createdAt.add(const Duration(minutes: 2)),
      ),
    );

    final persisted = (await repository.watchSchedules().first).single;
    expect(persisted.revision, 1);
    expect(persisted.label, 'Morning medicine');
  });

  test('local reminder repository links schedules to prescriptions', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalReminderRepository(database);
    final createdAt = DateTime.utc(2026, 6, 9, 8);

    await repository.upsertSchedule(
      ReminderSchedule(
        id: 'morning-vitamin',
        label: 'Vitamin D',
        prescriptionId: 'vitamin-d',
        hour: 8,
        minute: 30,
        isEnabled: true,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );

    final schedule = (await repository.watchSchedules().first).single;
    expect(schedule.prescriptionId, 'vitamin-d');
    expect(schedule.profileId, 'schedule-1');
    expect(schedule.label, 'Vitamin D');
  });

  test('local reminder repository scopes duplicates to one profile', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalReminderRepository(database);
    final createdAt = DateTime.utc(2026, 6, 9, 8);

    await repository.upsertSchedule(
      ReminderSchedule(
        id: 'normal-morning-vitamin',
        label: 'Vitamin D',
        prescriptionId: 'vitamin-d',
        profileId: 'schedule-1',
        hour: 8,
        minute: 30,
        isEnabled: true,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );
    await repository.upsertSchedule(
      ReminderSchedule(
        id: 'travel-morning-vitamin',
        label: 'Vitamin D',
        prescriptionId: 'vitamin-d',
        profileId: 'travel',
        hour: 8,
        minute: 30,
        isEnabled: true,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );

    final schedules = await repository.watchSchedules().first;
    expect(schedules, hasLength(2));
    expect(
      await repository.watchSchedules(profileId: 'schedule-1').first,
      hasLength(1),
    );
    expect(
      await repository.watchSchedules(profileId: 'travel').first,
      hasLength(1),
    );
  });

  test(
    'local reminder repository rejects duplicate prescription times',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalReminderRepository(database);
      final createdAt = DateTime.utc(2026, 6, 9, 8);

      await repository.upsertSchedule(
        ReminderSchedule(
          id: 'morning-vitamin',
          label: 'Vitamin D',
          prescriptionId: 'vitamin-d',
          hour: 8,
          minute: 30,
          isEnabled: true,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );

      expect(
        () => repository.upsertSchedule(
          ReminderSchedule(
            id: 'duplicate-morning-vitamin',
            label: 'Vitamin D',
            prescriptionId: 'vitamin-d',
            profileId: 'schedule-1',
            hour: 8,
            minute: 30,
            isEnabled: true,
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'A schedule already exists for this prescription at 08:30.',
          ),
        ),
      );
    },
  );

  test('local reminder repository deletes schedules', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalReminderRepository(database);
    final now = DateTime.utc(2026, 6, 9, 8);

    await repository.upsertSchedule(
      ReminderSchedule(
        id: 'evening',
        label: 'Evening dose',
        hour: 20,
        minute: 0,
        isEnabled: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.deleteSchedule('evening');

    expect(await repository.watchSchedules().first, isEmpty);
  });

  test('local reminder repository deletes linked carousel slots', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalReminderRepository(database);
    final now = DateTime.utc(2026, 6, 9, 8);

    await repository.upsertSchedule(
      ReminderSchedule(
        id: 'morning',
        label: 'Morning dose',
        prescriptionId: 'vitamin-d',
        hour: 8,
        minute: 30,
        isEnabled: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await LocalCarouselSlotRepository(database).assignSlot(
      CarouselSlot(
        id: 'slot-1',
        slotNumber: 1,
        prescriptionId: 'vitamin-d',
        scheduleId: 'morning',
        profileId: ReminderSchedule.defaultProfileId,
        status: CarouselSlotStatus.loaded,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await repository.deleteSchedule('morning');

    expect(await repository.watchSchedules().first, isEmpty);
    expect(await database.select(database.carouselSlots).get(), isEmpty);
  });

  test(
    'local reminder repository clears carousel slots when prescription changes',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalReminderRepository(database);
      final now = DateTime.utc(2026, 6, 9, 8);

      await repository.upsertSchedule(
        ReminderSchedule(
          id: 'morning',
          label: 'Vitamin D',
          prescriptionId: 'vitamin-d',
          hour: 8,
          minute: 30,
          isEnabled: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.upsertSchedule(
        ReminderSchedule(
          id: 'noon',
          label: 'Allergy pill',
          prescriptionId: 'allergy-pill',
          hour: 12,
          minute: 0,
          isEnabled: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final carouselSlots = LocalCarouselSlotRepository(database);
      await carouselSlots.assignSlot(
        CarouselSlot(
          id: 'slot-1',
          slotNumber: 1,
          prescriptionId: 'vitamin-d',
          scheduleId: 'morning',
          profileId: ReminderSchedule.defaultProfileId,
          status: CarouselSlotStatus.loaded,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await carouselSlots.assignSlot(
        CarouselSlot(
          id: 'slot-2',
          slotNumber: 2,
          prescriptionId: 'allergy-pill',
          scheduleId: 'noon',
          profileId: ReminderSchedule.defaultProfileId,
          status: CarouselSlotStatus.loaded,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await repository.upsertSchedule(
        ReminderSchedule(
          id: 'morning',
          label: 'Allergy pill',
          prescriptionId: 'allergy-pill',
          hour: 8,
          minute: 30,
          isEnabled: true,
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );

      final schedules = await repository.watchSchedules().first;
      expect(schedules, hasLength(2));
      final schedule = schedules.singleWhere(
        (schedule) => schedule.id == 'morning',
      );
      expect(schedule.prescriptionId, 'allergy-pill');

      final slots = await database.select(database.carouselSlots).get();
      expect(slots, hasLength(1));
      expect(slots.single.id, 'slot-2');
      expect(slots.single.scheduleId, 'noon');
      expect(slots.single.prescriptionId, 'allergy-pill');
    },
  );

  test('phone-only reminder edits do not mutate carousel state', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final hardwareRepository = LocalReminderRepository(database);
    final phoneRepository = LocalReminderRepository(
      database,
      hardwareEffectsEnabled: false,
    );
    final now = DateTime.utc(2026, 6, 9, 8);
    final schedule = ReminderSchedule(
      id: 'morning',
      label: 'Vitamin D',
      prescriptionId: 'vitamin-d',
      hour: 8,
      minute: 30,
      isEnabled: true,
      createdAt: now,
      updatedAt: now,
    );
    await hardwareRepository.upsertSchedule(schedule);
    await LocalCarouselSlotRepository(database).assignSlot(
      CarouselSlot(
        id: 'slot-1',
        slotNumber: 1,
        prescriptionId: 'vitamin-d',
        scheduleId: 'morning',
        profileId: ReminderSchedule.defaultProfileId,
        status: CarouselSlotStatus.loaded,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await phoneRepository.upsertSchedule(
      schedule.copyWith(
        prescriptionId: 'allergy-pill',
        updatedAt: now.add(const Duration(minutes: 1)),
      ),
    );

    expect(await database.select(database.carouselSlots).get(), hasLength(1));
    expect(await database.select(database.carouselLoadSessions).get(), isEmpty);
  });

  test('local reminder repository rejects invalid reminder times', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalReminderRepository(database);
    final now = DateTime.utc(2026, 6, 9, 8);

    expect(
      () => repository.upsertSchedule(
        ReminderSchedule(
          id: 'bad-hour',
          label: 'Bad hour',
          hour: 24,
          minute: 0,
          isEnabled: true,
          createdAt: now,
          updatedAt: now,
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => repository.upsertSchedule(
        ReminderSchedule(
          id: 'bad-minute',
          label: 'Bad minute',
          hour: 8,
          minute: 60,
          isEnabled: true,
          createdAt: now,
          updatedAt: now,
        ),
      ),
      throwsArgumentError,
    );
  });
}
