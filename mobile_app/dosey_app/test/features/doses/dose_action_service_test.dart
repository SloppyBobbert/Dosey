import 'package:dosey_app/core/carousel/carousel_load_session.dart';
import 'package:dosey_app/core/carousel/carousel_position.dart';
import 'package:dosey_app/core/carousel/guided_carousel_load_plan.dart';
import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/carousel/local_guided_carousel_load_repository.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/doses/dose_action_service.dart';
import 'package:drift/drift.dart';
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

  test('guided taken action is rejected before movement', () async {
    final fixture = await _guidedDoseFixture();
    addTearDown(fixture.database.close);

    await expectLater(
      fixture.service.record(
        DoseLogEvent.doseTakenConfirmed(doseId: _doseId, occurredAt: _now),
      ),
      throwsStateError,
    );

    final load = await fixture.guidedLoads.readActiveLoad(_profileId);
    expect(load!.slots.first.status, CarouselLoadSlotStatus.loaded);
    final prescription = await _prescription(fixture.database);
    expect(prescription.loadedDoses, 1);
    expect(prescription.usedDoses, 0);
    expect(prescription.remainingDoses, 2);
    expect(
      await fixture.database.select(fixture.database.doseLogEvents).get(),
      isEmpty,
    );
  });

  test('guided pre-movement skip quarantines loaded inventory', () async {
    final fixture = await _guidedDoseFixture();
    addTearDown(fixture.database.close);

    expect(
      await fixture.service.record(
        DoseLogEvent.doseSkipped(doseId: _doseId, occurredAt: _now),
      ),
      DoseActionResult.recorded,
    );

    final load = await fixture.guidedLoads.readActiveLoad(_profileId);
    expect(load!.slots.first.status, CarouselLoadSlotStatus.needsReview);
    final prescription = await _prescription(fixture.database);
    expect(prescription.loadedDoses, 0);
    expect(prescription.usedDoses, 0);
    expect(prescription.remainingDoses, 2);
  });

  test('guided pre-movement missed quarantines loaded inventory', () async {
    final fixture = await _guidedDoseFixture();
    addTearDown(fixture.database.close);

    expect(
      await fixture.service.record(
        DoseLogEvent.doseMissed(doseId: _doseId, occurredAt: _now),
      ),
      DoseActionResult.recorded,
    );

    final load = await fixture.guidedLoads.readActiveLoad(_profileId);
    expect(load!.slots.first.status, CarouselLoadSlotStatus.needsReview);
    final prescription = await _prescription(fixture.database);
    expect(prescription.loadedDoses, 0);
    expect(prescription.usedDoses, 0);
    expect(prescription.remainingDoses, 2);
  });

  test(
    'guided taken action is rejected after movement without visibility',
    () async {
      final fixture = await _guidedDoseFixture();
      addTearDown(fixture.database.close);
      await _recordMovement(fixture);

      await expectLater(
        fixture.service.record(
          DoseLogEvent.doseTakenConfirmed(doseId: _doseId, occurredAt: _now),
        ),
        throwsStateError,
      );

      final prescription = await _prescription(fixture.database);
      expect(prescription.loadedDoses, 1);
      expect(prescription.usedDoses, 0);
      expect(prescription.remainingDoses, 2);
      expect(
        await fixture.database.select(fixture.database.doseLogEvents).get(),
        isEmpty,
      );
    },
  );

  test('guided visibility is rejected before movement', () async {
    final fixture = await _guidedDoseFixture();
    addTearDown(fixture.database.close);

    await expectLater(
      fixture.service.record(
        DoseLogEvent.doseVisibleConfirmed(doseId: _doseId, occurredAt: _now),
      ),
      throwsStateError,
    );
    expect(
      await fixture.database.select(fixture.database.doseLogEvents).get(),
      isEmpty,
    );
  });

  test(
    'guided visibility after movement authorizes the same dose once',
    () async {
      final fixture = await _guidedDoseFixture();
      addTearDown(fixture.database.close);
      await _recordMovement(fixture);

      expect(
        await fixture.service.record(
          DoseLogEvent.doseVisibleConfirmed(doseId: _doseId, occurredAt: _now),
        ),
        DoseActionResult.recorded,
      );

      expect(
        await fixture.service.record(
          DoseLogEvent.doseTakenConfirmed(doseId: _doseId, occurredAt: _now),
        ),
        DoseActionResult.recorded,
      );
      expect(
        await fixture.service.record(
          DoseLogEvent.doseTakenConfirmed(doseId: _doseId, occurredAt: _now),
        ),
        DoseActionResult.ignored,
      );

      final load = await fixture.guidedLoads.readActiveLoad(_profileId);
      expect(load!.slots.first.status, CarouselLoadSlotStatus.dispensed);
      final prescription = await _prescription(fixture.database);
      expect(prescription.loadedDoses, 0);
      expect(prescription.usedDoses, 1);
      expect(prescription.remainingDoses, 1);
    },
  );

  test('visibility for another dose does not authorize guided taken', () async {
    final fixture = await _guidedDoseFixture();
    addTearDown(fixture.database.close);
    await _recordMovement(fixture);
    await fixture.service.record(
      DoseLogEvent.doseVisibleConfirmed(
        doseId: 'other-schedule:2026-07-24',
        occurredAt: _now,
      ),
    );

    await expectLater(
      fixture.service.record(
        DoseLogEvent.doseTakenConfirmed(doseId: _doseId, occurredAt: _now),
      ),
      throwsStateError,
    );
  });

  test('robot face guided attestation is atomic and idempotent', () async {
    final fixture = await _guidedDoseFixture();
    addTearDown(fixture.database.close);

    await expectLater(
      fixture.service.recordRobotFaceVisibleAndTaken(
        doseId: _doseId,
        occurredAt: _now,
      ),
      throwsStateError,
    );
    expect(
      await fixture.database.select(fixture.database.doseLogEvents).get(),
      isEmpty,
    );

    await _recordMovement(fixture);
    expect(
      await fixture.service.recordRobotFaceVisibleAndTaken(
        doseId: _doseId,
        occurredAt: _now,
      ),
      DoseActionResult.recorded,
    );
    final events = await fixture.database
        .select(fixture.database.doseLogEvents)
        .get();
    expect(
      events.map((event) => event.kind),
      orderedEquals(<String>[
        DoseLogEventKind.doseVisibleConfirmed.name,
        DoseLogEventKind.doseTakenConfirmed.name,
      ]),
    );
    expect(
      await fixture.service.recordRobotFaceVisibleAndTaken(
        doseId: _doseId,
        occurredAt: _now,
      ),
      DoseActionResult.ignored,
    );
    final prescription = await _prescription(fixture.database);
    expect(prescription.usedDoses, 1);
  });

  test('robot face guided attestation reuses persisted visibility', () async {
    final fixture = await _guidedDoseFixture();
    addTearDown(fixture.database.close);
    await _recordMovement(fixture);
    await fixture.service.record(
      DoseLogEvent.doseVisibleConfirmed(doseId: _doseId, occurredAt: _now),
    );

    await fixture.service.recordRobotFaceVisibleAndTaken(
      doseId: _doseId,
      occurredAt: _now,
    );
    expect(
      (await fixture.database.select(fixture.database.doseLogEvents).get()).map(
        (event) => event.kind,
      ),
      orderedEquals(<String>[
        DoseLogEventKind.doseVisibleConfirmed.name,
        DoseLogEventKind.doseTakenConfirmed.name,
      ]),
    );
  });

  test(
    'robot face guided attestation rolls back when taken logging fails',
    () async {
      final fixture = await _guidedDoseFixture();
      addTearDown(fixture.database.close);
      await _recordMovement(fixture);
      await fixture.database.customStatement('''
      CREATE TRIGGER fail_robot_face_taken_log
      BEFORE INSERT ON dose_log_events
      WHEN NEW.kind = 'doseTakenConfirmed'
      BEGIN
        SELECT RAISE(ABORT, 'forced taken log failure');
      END;
    ''');
      addTearDown(
        () => fixture.database.customStatement(
          'DROP TRIGGER IF EXISTS fail_robot_face_taken_log;',
        ),
      );

      final loadBefore = await fixture.guidedLoads.readActiveLoad(_profileId);
      final snapshotBefore =
          await (fixture.database.select(
                fixture.database.carouselLoadSlotSnapshots,
              )..where(
                (row) =>
                    row.sessionId.equals(_sessionId) & row.slotNumber.equals(1),
              ))
              .getSingle();
      final prescriptionBefore = await _prescription(fixture.database);

      await expectLater(
        fixture.service.recordRobotFaceVisibleAndTaken(
          doseId: _doseId,
          occurredAt: _now,
        ),
        throwsA(
          isA<Object>().having(
            (error) => error.toString(),
            'message',
            contains('forced taken log failure'),
          ),
        ),
      );

      expect(
        await fixture.database.select(fixture.database.doseLogEvents).get(),
        isEmpty,
      );
      final loadAfter = await fixture.guidedLoads.readActiveLoad(_profileId);
      final snapshotAfter =
          await (fixture.database.select(
                fixture.database.carouselLoadSlotSnapshots,
              )..where(
                (row) =>
                    row.sessionId.equals(_sessionId) & row.slotNumber.equals(1),
              ))
              .getSingle();
      expect(loadAfter!.slots.first.status, loadBefore!.slots.first.status);
      expect(loadAfter.currentPosition, loadBefore.currentPosition);
      expect(loadAfter.slots.first.updatedAt, loadBefore.slots.first.updatedAt);
      expect(snapshotAfter.resolvedAt, snapshotBefore.resolvedAt);
      final prescriptionAfter = await _prescription(fixture.database);
      expect(prescriptionAfter.loadedDoses, prescriptionBefore.loadedDoses);
      expect(prescriptionAfter.usedDoses, prescriptionBefore.usedDoses);
      expect(
        prescriptionAfter.remainingDoses,
        prescriptionBefore.remainingDoses,
      );
    },
  );

  test('robot face non-guided attestation records only taken', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final prescriptions = LocalPrescriptionRepository(database);
    await prescriptions.upsertPrescription(
      Prescription(
        id: 'manual-med',
        name: 'Manual',
        pillType: PillType.tablet,
        remainingDoses: 2,
        createdAt: _now,
        updatedAt: _now,
      ),
    );
    await LocalReminderRepository(database).upsertSchedule(
      ReminderSchedule(
        id: 'manual-schedule',
        label: 'Manual',
        prescriptionId: 'manual-med',
        hour: 8,
        minute: 30,
        isEnabled: true,
        createdAt: _now,
        updatedAt: _now,
      ),
    );
    final service = DoseActionService(
      database: database,
      carouselSlots: LocalCarouselSlotRepository(database),
      guidedCarouselLoads: LocalGuidedCarouselLoadRepository(database),
      prescriptions: prescriptions,
      doseLog: DriftDoseLogRepository(database),
    );

    await service.recordRobotFaceVisibleAndTaken(
      doseId: 'manual-schedule:2026-07-24',
      occurredAt: _now,
    );
    expect(
      (await database.select(database.doseLogEvents).get()).map(
        (event) => event.kind,
      ),
      orderedEquals(<String>[DoseLogEventKind.doseTakenConfirmed.name]),
    );
    final prescription = await (database.select(
      database.prescriptions,
    )..where((row) => row.id.equals('manual-med'))).getSingle();
    expect(prescription.remainingDoses, 1);
  });

  test('guided post-movement skip marks dispensed slot for review', () async {
    final fixture = await _guidedDoseFixture();
    addTearDown(fixture.database.close);
    await _recordMovement(fixture);

    await fixture.service.record(
      DoseLogEvent.doseSkipped(doseId: _doseId, occurredAt: _now),
    );
    final load = await fixture.guidedLoads.readActiveLoad(_profileId);
    expect(load!.slots.first.status, CarouselLoadSlotStatus.needsReview);
  });

  test('guided post-movement missed marks dispensed slot for review', () async {
    final fixture = await _guidedDoseFixture();
    addTearDown(fixture.database.close);
    await _recordMovement(fixture);

    await fixture.service.record(
      DoseLogEvent.doseMissed(doseId: _doseId, occurredAt: _now),
    );
    final load = await fixture.guidedLoads.readActiveLoad(_profileId);
    expect(load!.slots.first.status, CarouselLoadSlotStatus.needsReview);
  });
}

const _profileId = 'schedule-1';
const _scheduleId = 'guided-schedule';
const _doseId = '$_scheduleId:2026-07-24';
const _sessionId = 'guided-session';
final _now = DateTime.utc(2026, 7, 24, 8, 30);

Future<void> _recordMovement(_GuidedDoseFixture fixture) {
  return fixture.guidedLoads.recordDispenseMovementSucceeded(
    profileId: _profileId,
    activeSessionId: _sessionId,
    slotNumber: 1,
    occurredAt: _now,
  );
}

Future<_GuidedDoseFixture> _guidedDoseFixture() async {
  final database = DoseyDatabase.inMemory();
  final prescriptions = LocalPrescriptionRepository(database);
  final guidedLoads = LocalGuidedCarouselLoadRepository(database);
  await prescriptions.upsertPrescription(
    Prescription(
      id: 'fake-med',
      name: 'FAKE Demo Vitamin',
      pillType: PillType.tablet,
      remainingDoses: 2,
      createdAt: _now,
      updatedAt: _now,
    ),
  );
  await LocalReminderRepository(database).upsertSchedule(
    ReminderSchedule(
      id: _scheduleId,
      label: 'FAKE Demo Dose',
      prescriptionId: 'fake-med',
      profileId: _profileId,
      hour: 8,
      minute: 30,
      isEnabled: true,
      createdAt: _now,
      updatedAt: _now,
    ),
  );
  await guidedLoads.confirmFullLoad(
    sessionId: _sessionId,
    profileId: _profileId,
    plan: GuidedCarouselLoadPlan(
      createdAt: _now,
      mode: GuidedCarouselLoadMode.fullReload,
      priorPosition: CarouselPosition.start,
      slots: [
        CarouselLoadPlanSlotPreview.loaded(
          position: CarouselPosition(1),
          bundle: CarouselDoseBundle(
            bundleKey: 'bundle-1',
            scheduledAt: _now,
            scheduleIds: const [_scheduleId],
            medications: [
              CarouselDoseBundleMedication(
                prescriptionId: 'fake-med',
                prescriptionName: 'FAKE Demo Vitamin',
                scheduleId: _scheduleId,
                scheduledAt: _now,
                availableDoses: 1,
                guidedPillIcon: GuidedPillIcon.roundPill,
                doseCount: 1,
                createdAt: _now,
                updatedAt: _now,
              ),
            ],
          ),
        ),
        ...List<CarouselLoadPlanSlotPreview>.generate(
          13,
          (index) => CarouselLoadPlanSlotPreview.empty(
            position: CarouselPosition(index + 2),
          ),
        ),
      ],
      shortages: const [],
    ),
    startedAt: _now,
    confirmedAt: _now,
  );
  return _GuidedDoseFixture(
    database: database,
    guidedLoads: guidedLoads,
    service: DoseActionService(
      database: database,
      carouselSlots: LocalCarouselSlotRepository(database),
      guidedCarouselLoads: guidedLoads,
      prescriptions: prescriptions,
      doseLog: DriftDoseLogRepository(database),
    ),
  );
}

Future<dynamic> _prescription(DoseyDatabase database) {
  return (database.select(
    database.prescriptions,
  )..where((row) => row.id.equals('fake-med'))).getSingle();
}

class _GuidedDoseFixture {
  const _GuidedDoseFixture({
    required this.database,
    required this.guidedLoads,
    required this.service,
  });

  final DoseyDatabase database;
  final LocalGuidedCarouselLoadRepository guidedLoads;
  final DoseActionService service;
}
