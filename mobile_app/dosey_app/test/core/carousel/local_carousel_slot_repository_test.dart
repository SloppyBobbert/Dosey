import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local carousel slot repository starts empty', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalCarouselSlotRepository(database);

    expect(await repository.watchSlots().first, isEmpty);
  });

  test('local carousel slot repository assigns and loads slots', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _seedPrescriptionSchedule(database);
    await _seedPrescriptionSchedule(
      database,
      prescriptionId: 'travel-vitamin',
      scheduleId: 'travel-vitamin-morning',
      profileId: 'travel',
      hour: 9,
    );
    final repository = LocalCarouselSlotRepository(database);
    final now = DateTime.utc(2026, 6, 25, 8);

    await repository.assignSlot(
      CarouselSlot(
        id: 'slot-1',
        slotNumber: 1,
        prescriptionId: 'vitamin-d',
        scheduleId: 'vitamin-d-morning',
        profileId: 'schedule-1',
        status: CarouselSlotStatus.assigned,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.markLoaded('slot-1');

    final slots = await repository.watchSlots().first;
    expect(slots, hasLength(1));
    expect(slots.single.slotNumber, 1);
    expect(slots.single.prescriptionId, 'vitamin-d');
    expect(slots.single.scheduleId, 'vitamin-d-morning');
    expect(slots.single.profileId, 'schedule-1');
    expect(slots.single.status, CarouselSlotStatus.loaded);
    expect(slots.single.createdAt, now);
    expect(slots.single.updatedAt.isAfter(now), isTrue);
  });

  test('local carousel slot repository marks loaded slots dispensed', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _seedPrescriptionSchedule(database);
    final repository = LocalCarouselSlotRepository(database);
    final now = DateTime.utc(2026, 6, 25, 8);

    await repository.assignSlot(
      CarouselSlot(
        id: 'slot-1',
        slotNumber: 1,
        prescriptionId: 'vitamin-d',
        scheduleId: 'vitamin-d-morning',
        profileId: 'schedule-1',
        status: CarouselSlotStatus.loaded,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.markDispensed('slot-1');

    final slots = await repository.watchSlots().first;
    expect(slots.single.status, CarouselSlotStatus.dispensed);
    expect(slots.single.updatedAt.isAfter(now), isTrue);
  });

  test('local carousel slot repository reports missing slot updates', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalCarouselSlotRepository(database);

    expect(
      () => repository.markLoaded('missing-slot'),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          'No carousel slot was updated for id "missing-slot".',
        ),
      ),
    );
  });

  test('local carousel slot repository rejects duplicate slots', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _seedPrescriptionSchedule(database);
    await _seedPrescriptionSchedule(
      database,
      prescriptionId: 'evening-vitamin',
      scheduleId: 'evening-vitamin-dose',
      hour: 20,
    );
    final repository = LocalCarouselSlotRepository(database);
    final now = DateTime.utc(2026, 6, 25, 8);

    await repository.assignSlot(
      CarouselSlot(
        id: 'slot-1',
        slotNumber: 1,
        prescriptionId: 'vitamin-d',
        scheduleId: 'vitamin-d-morning',
        profileId: 'schedule-1',
        status: CarouselSlotStatus.assigned,
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(
      () => repository.assignSlot(
        CarouselSlot(
          id: 'slot-1-duplicate',
          slotNumber: 1,
          prescriptionId: 'evening-vitamin',
          scheduleId: 'evening-vitamin-dose',
          profileId: 'schedule-1',
          status: CarouselSlotStatus.assigned,
          createdAt: now,
          updatedAt: now,
        ),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          'Slot 1 is already assigned for this schedule profile.',
        ),
      ),
    );
  });

  test('local carousel slot repository rejects duplicate schedules', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _seedPrescriptionSchedule(database);
    final repository = LocalCarouselSlotRepository(database);
    final now = DateTime.utc(2026, 6, 25, 8);

    await repository.assignSlot(
      CarouselSlot(
        id: 'slot-1',
        slotNumber: 1,
        prescriptionId: 'vitamin-d',
        scheduleId: 'vitamin-d-morning',
        profileId: 'schedule-1',
        status: CarouselSlotStatus.assigned,
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(
      () => repository.assignSlot(
        CarouselSlot(
          id: 'slot-2',
          slotNumber: 2,
          prescriptionId: 'vitamin-d',
          scheduleId: 'vitamin-d-morning',
          profileId: 'schedule-1',
          status: CarouselSlotStatus.assigned,
          createdAt: now,
          updatedAt: now,
        ),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          'This scheduled dose is already assigned to a carousel slot.',
        ),
      ),
    );
  });

  test(
    'local carousel slot repository marks review and clears slots',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(database);
      final repository = LocalCarouselSlotRepository(database);
      final now = DateTime.utc(2026, 6, 25, 8);

      await repository.assignSlot(
        CarouselSlot(
          id: 'slot-1',
          slotNumber: 1,
          prescriptionId: 'vitamin-d',
          scheduleId: 'vitamin-d-morning',
          profileId: 'schedule-1',
          status: CarouselSlotStatus.assigned,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.markNeedsReview('slot-1');

      expect(
        (await repository.watchSlots().first).single.status,
        CarouselSlotStatus.needsReview,
      );

      await repository.clearSlot('slot-1');

      expect(await repository.watchSlots().first, isEmpty);
    },
  );

  test('local carousel slot repository clears profile slots', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _seedPrescriptionSchedule(database);
    final repository = LocalCarouselSlotRepository(database);
    final now = DateTime.utc(2026, 6, 25, 8);

    await repository.assignSlot(
      CarouselSlot(
        id: 'slot-1',
        slotNumber: 1,
        prescriptionId: 'vitamin-d',
        scheduleId: 'vitamin-d-morning',
        profileId: 'schedule-1',
        status: CarouselSlotStatus.assigned,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.assignSlot(
      CarouselSlot(
        id: 'travel-slot-1',
        slotNumber: 1,
        prescriptionId: 'travel-vitamin',
        scheduleId: 'travel-vitamin-morning',
        profileId: 'travel',
        status: CarouselSlotStatus.assigned,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await repository.clearProfile('schedule-1');

    expect(await repository.watchSlots(profileId: 'schedule-1').first, isEmpty);
    final travelSlots = await repository.watchSlots(profileId: 'travel').first;
    expect(travelSlots, hasLength(1));
    expect(travelSlots.single.id, 'travel-slot-1');
  });

  test('local carousel slot repository rejects invalid slot numbers', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _seedPrescriptionSchedule(database);
    final repository = LocalCarouselSlotRepository(database);
    final now = DateTime.utc(2026, 6, 25, 8);

    expect(
      () => repository.assignSlot(
        CarouselSlot(
          id: 'slot-zero',
          slotNumber: 0,
          prescriptionId: 'vitamin-d',
          scheduleId: 'vitamin-d-morning',
          profileId: 'schedule-1',
          status: CarouselSlotStatus.assigned,
          createdAt: now,
          updatedAt: now,
        ),
      ),
      throwsArgumentError,
    );
  });
}

Future<void> _seedPrescriptionSchedule(
  DoseyDatabase database, {
  String prescriptionId = 'vitamin-d',
  String scheduleId = 'vitamin-d-morning',
  String profileId = ReminderSchedule.defaultProfileId,
  int hour = 8,
}) async {
  final now = DateTime.utc(2026, 6, 25, hour);
  await LocalPrescriptionRepository(database).upsertPrescription(
    Prescription(
      id: prescriptionId,
      name: prescriptionId,
      pillType: PillType.capsule,
      createdAt: now,
      updatedAt: now,
    ),
  );
  await LocalReminderRepository(database).upsertSchedule(
    ReminderSchedule(
      id: scheduleId,
      label: prescriptionId,
      prescriptionId: prescriptionId,
      profileId: profileId,
      hour: hour,
      minute: 0,
      isEnabled: true,
      createdAt: now,
      updatedAt: now,
    ),
  );
}
