import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local prescription repository starts empty', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalPrescriptionRepository(database);

    expect(await repository.watchPrescriptions().first, isEmpty);
  });

  test(
    'local prescription repository persists pill type graphics choice',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalPrescriptionRepository(database);
      final createdAt = DateTime.utc(2026, 6, 9, 8);

      await repository.upsertPrescription(
        Prescription(
          id: 'vitamin-d',
          name: 'Vitamin D',
          pillType: PillType.capsule,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );

      final prescriptions = await repository.watchPrescriptions().first;
      expect(prescriptions, hasLength(1));
      expect(prescriptions.single.id, 'vitamin-d');
      expect(prescriptions.single.name, 'Vitamin D');
      expect(prescriptions.single.pillType, PillType.capsule);
      expect(prescriptions.single.createdAt, createdAt);
      expect(prescriptions.single.updatedAt, createdAt);
    },
  );

  test('local prescription repository persists refill dose settings', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalPrescriptionRepository(database);
    final createdAt = DateTime.utc(2026, 6, 9, 8);

    await repository.upsertPrescription(
      Prescription(
        id: 'vitamin-d',
        name: 'Vitamin D',
        pillType: PillType.capsule,
        remainingDoses: 14,
        refillThreshold: 5,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );

    final prescriptions = await repository.watchPrescriptions().first;
    expect(prescriptions.single.remainingDoses, 14);
    expect(prescriptions.single.refillThreshold, 5);
    expect(prescriptions.single.needsRefill, isFalse);
  });

  test('adding a refill increases remaining doses and saves history', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalPrescriptionRepository(database);
    final createdAt = DateTime.utc(2026, 6, 9, 8);
    final refilledAt = DateTime.utc(2026, 6, 10, 9);

    await repository.upsertPrescription(
      Prescription(
        id: 'vitamin-d',
        name: 'Vitamin D',
        pillType: PillType.capsule,
        remainingDoses: 2,
        refillThreshold: 5,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );

    await repository.addRefill(
      prescriptionId: 'vitamin-d',
      doseCount: 30,
      occurredAt: refilledAt,
      note: 'new bottle',
    );

    final prescriptions = await repository.watchPrescriptions().first;
    final refillHistory = await repository
        .watchRefillHistory('vitamin-d')
        .first;
    expect(prescriptions.single.remainingDoses, 32);
    expect(prescriptions.single.needsRefill, isFalse);
    expect(refillHistory.single.prescriptionId, 'vitamin-d');
    expect(refillHistory.single.doseDelta, 30);
    expect(refillHistory.single.remainingAfter, 32);
    expect(refillHistory.single.occurredAt, refilledAt);
    expect(refillHistory.single.note, 'new bottle');
  });

  test(
    'recording a taken dose decrements remaining doses only to zero',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalPrescriptionRepository(database);
      final now = DateTime.utc(2026, 6, 9, 8);

      await repository.upsertPrescription(
        Prescription(
          id: 'vitamin-d',
          name: 'Vitamin D',
          pillType: PillType.capsule,
          remainingDoses: 1,
          refillThreshold: 3,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await repository.recordTakenDose('vitamin-d', occurredAt: now);
      await repository.recordTakenDose(
        'vitamin-d',
        occurredAt: now.add(const Duration(minutes: 1)),
      );

      final prescriptions = await repository.watchPrescriptions().first;
      expect(prescriptions.single.remainingDoses, 0);
      expect(prescriptions.single.needsRefill, isTrue);
    },
  );

  test('local prescription repository deletes prescriptions', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalPrescriptionRepository(database);
    final now = DateTime.utc(2026, 6, 9, 8);

    await repository.upsertPrescription(
      Prescription(
        id: 'blood-pressure',
        name: 'Blood pressure med',
        pillType: PillType.tablet,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.deletePrescription('blood-pressure');

    expect(await repository.watchPrescriptions().first, isEmpty);
  });

  test('deleting a prescription removes linked schedules', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final prescriptions = LocalPrescriptionRepository(database);
    final reminders = LocalReminderRepository(database);
    final now = DateTime.utc(2026, 6, 9, 8);

    await prescriptions.upsertPrescription(
      Prescription(
        id: 'vitamin-d',
        name: 'Vitamin D',
        pillType: PillType.capsule,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await reminders.upsertSchedule(
      ReminderSchedule(
        id: 'vitamin-d-morning',
        label: 'Vitamin D',
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
        scheduleId: 'vitamin-d-morning',
        profileId: ReminderSchedule.defaultProfileId,
        status: CarouselSlotStatus.loaded,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await prescriptions.deletePrescription('vitamin-d');

    expect(await reminders.watchSchedules().first, isEmpty);
    expect(await database.select(database.carouselSlots).get(), isEmpty);
    expect(await prescriptions.watchRefillHistory('vitamin-d').first, isEmpty);
  });

  test('local prescription repository rejects blank names', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalPrescriptionRepository(database);
    final now = DateTime.utc(2026, 6, 9, 8);

    expect(
      () => repository.upsertPrescription(
        Prescription(
          id: 'blank',
          name: '   ',
          pillType: PillType.pill,
          createdAt: now,
          updatedAt: now,
        ),
      ),
      throwsArgumentError,
    );
  });
}
