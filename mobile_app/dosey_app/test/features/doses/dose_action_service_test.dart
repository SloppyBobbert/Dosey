import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/carousel/local_guided_carousel_load_repository.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/doses/dose_action_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'taken action decrements inventory once and duplicate is ignored',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final prescriptions = LocalPrescriptionRepository(database);
      final now = DateTime.utc(2026, 7, 24, 8, 30);
      await prescriptions.upsertPrescription(
        Prescription(
          id: 'fake-med',
          name: 'FAKE Demo Vitamin',
          pillType: PillType.tablet,
          remainingDoses: 2,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await LocalReminderRepository(database).upsertSchedule(
        ReminderSchedule(
          id: 'fake-schedule',
          label: 'FAKE Demo Dose',
          prescriptionId: 'fake-med',
          hour: 8,
          minute: 30,
          isEnabled: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final service = DoseActionService(
        database: database,
        carouselSlots: LocalCarouselSlotRepository(database),
        guidedCarouselLoads: LocalGuidedCarouselLoadRepository(database),
        prescriptions: prescriptions,
        doseLog: DriftDoseLogRepository(database),
      );
      final event = DoseLogEvent.doseTakenConfirmed(
        doseId: 'fake-schedule:2026-07-24',
        occurredAt: now,
      );

      expect(await service.record(event), DoseActionResult.recorded);
      expect(await service.record(event), DoseActionResult.ignored);

      final prescription = await (database.select(
        database.prescriptions,
      )..where((row) => row.id.equals('fake-med'))).getSingle();
      expect(prescription.remainingDoses, 1);
      expect(await database.select(database.doseLogEvents).get(), hasLength(1));
    },
  );
}
