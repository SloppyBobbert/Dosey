import 'package:dosey_app/core/carousel/carousel_load_session.dart';
import 'package:dosey_app/core/carousel/carousel_position.dart';
import 'package:dosey_app/core/carousel/guided_carousel_load_planner.dart';
import 'package:dosey_app/core/carousel/local_guided_carousel_load_repository.dart';
import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/audit/local_admin_audit_repository.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/notifications/flutter_local_notification_scheduler.dart';
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/schedules/local_schedule_profile_repository.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'full load confirmation persists one confirmed 14-slot session and moves inventory',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(
        database,
        prescriptionId: 'med-a',
        scheduleId: 'schedule-a',
        availableDoses: 3,
      );
      await _seedPrescriptionSchedule(
        database,
        prescriptionId: 'med-b',
        scheduleId: 'schedule-b',
        availableDoses: 2,
        hour: 9,
      );
      final repository = LocalGuidedCarouselLoadRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-1',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-1', now, [
              _medication('med-a', 'schedule-a'),
              _medication(
                'med-b',
                'schedule-b',
                scheduledAt: DateTime.utc(2026, 7, 23, 9),
              ),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );

      final session = await repository.readSession('session-1');
      expect(session, isNotNull);
      expect(session!.status, CarouselLoadSessionStatus.confirmed);
      expect(session.mode, GuidedCarouselLoadMode.fullReload);
      expect(session.currentPosition, CarouselPosition.start);
      expect(session.slots, hasLength(14));
      expect(session.slots.first.status, CarouselLoadSlotStatus.loaded);
      expect(session.slots.first.scheduleIds, ['schedule-a', 'schedule-b']);
      expect(session.slots.first.prescriptionIds, ['med-a', 'med-b']);

      final activeLoad = await repository.readActiveLoad('schedule-1');
      expect(activeLoad?.id, 'session-1');

      final prescriptions = await LocalPrescriptionRepository(
        database,
      ).watchPrescriptions().first;
      expect(
        prescriptions.firstWhere((p) => p.id == 'med-a'),
        isA<Prescription>()
            .having((p) => p.availableDoses, 'available', 2)
            .having((p) => p.loadedDoses, 'loaded', 1),
      );
      expect(
        prescriptions.firstWhere((p) => p.id == 'med-b'),
        isA<Prescription>()
            .having((p) => p.availableDoses, 'available', 1)
            .having((p) => p.loadedDoses, 'loaded', 1),
      );
    },
  );

  test('shortage and empty slots persist exactly as planned', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _seedPrescriptionSchedule(database);
    final notifier = _FakeUrgentShortageNotifier();
    final repository = LocalGuidedCarouselLoadRepository(
      database,
      urgentShortageNotifier: notifier,
    );
    final now = DateTime.utc(2026, 7, 23, 8);

    await repository.confirmFullLoad(
      sessionId: 'session-short',
      profileId: 'schedule-1',
      plan: _plan(
        now,
        loadedSlots: [
          _loadedSlot(1, 'bundle-1', now, [
            _medication('vitamin-d', 'vitamin-d-morning'),
          ]),
        ],
        shortageSlots: [
          CarouselLoadPlanSlotPreview.shortage(
            position: CarouselPosition(2),
            shortage: CarouselLoadPlanShortage(
              position: CarouselPosition(2),
              bundleKey: 'short-2',
              scheduledAt: DateTime.utc(2026, 7, 23, 9),
              scheduleIds: const ['vitamin-d-evening'],
            ),
          ),
        ],
      ),
      startedAt: now,
      confirmedAt: now,
    );

    final session = await repository.readSession('session-short');
    expect(session, isNotNull);
    expect(session!.slots[0].status, CarouselLoadSlotStatus.loaded);
    expect(session.slots[1].status, CarouselLoadSlotStatus.shortage);
    expect(session.slots[1].scheduleIds, ['vitamin-d-evening']);
    expect(session.slots[2].status, CarouselLoadSlotStatus.empty);
    expect(session.slots[13].status, CarouselLoadSlotStatus.empty);

    final alerts = await repository
        .watchActiveShortageAlerts('schedule-1')
        .first;
    expect(alerts, hasLength(13));
    expect(alerts.first.slotNumber, 2);
    expect(alerts.last.slotNumber, 14);
    expect(alerts.every((alert) => alert.status == 'active'), isTrue);
    expect(
      alerts.every((alert) => alert.intendedAudience == 'household'),
      isTrue,
    );
    expect(alerts.first.localDeliveryState, 'sent');
    expect(
      alerts.skip(1).every((alert) => alert.localDeliveryState == 'pending'),
      isTrue,
    );
    expect(
      alerts.every((alert) => alert.remoteDeliveryState == 'not_configured'),
      isTrue,
    );
    expect(alerts.first.localNotificationSentAt, isNotNull);
    expect(alerts.first.prescriptionNamesJson, contains('vitamin-d'));
    expect(notifier.sentAlertIds, [alerts.first.id]);

    await repository.recognizeShortageAlert(
      alerts.first.id,
      recognizedAt: now.add(const Duration(minutes: 1)),
    );
    final recognizedAlerts = await repository
        .watchActiveShortageAlerts('schedule-1')
        .first;
    expect(recognizedAlerts.every((alert) => alert.status == 'active'), isTrue);
    expect(
      recognizedAlerts.every((alert) => alert.recognizedAt != null),
      isTrue,
    );

    await repository.resolveShortageAlert(
      alerts.first.id,
      resolvedAt: now.add(const Duration(minutes: 2)),
      resolution: 'inventory_recovered',
    );
    final remainingActiveAlerts = await repository
        .watchActiveShortageAlerts('schedule-1')
        .first;
    expect(remainingActiveAlerts, isEmpty);
    final resolvedAlert = await (database.select(
      database.medicationShortageAlerts,
    )..where((row) => row.id.equals(alerts.first.id))).getSingle();
    expect(resolvedAlert.status, 'resolved');
    expect(resolvedAlert.recognizedAt, isNotNull);
    expect(resolvedAlert.resolvedAt, isNotNull);
    expect(resolvedAlert.resolution, 'inventory_recovered');
    final tailResolvedAlert = await (database.select(
      database.medicationShortageAlerts,
    )..where((row) => row.id.equals(alerts.last.id))).getSingle();
    expect(tailResolvedAlert.status, 'resolved');
    expect(tailResolvedAlert.recognizedAt, isNotNull);
    expect(tailResolvedAlert.resolvedAt, isNotNull);

    final auditEvents = await LocalAdminAuditRepository(
      database,
    ).watchRecentEvents(limit: 20).first;
    expect(
      auditEvents.any(
        (event) =>
            event.eventType == AdminAuditEventType.guidedLoadShortageCreated,
      ),
      isTrue,
    );
    expect(
      auditEvents.any(
        (event) =>
            event.eventType == AdminAuditEventType.guidedLoadShortageRecognized,
      ),
      isTrue,
    );
    expect(
      auditEvents.any(
        (event) =>
            event.eventType == AdminAuditEventType.guidedLoadShortageResolved,
      ),
      isTrue,
    );
  });

  test(
    'top-off rejects late loading once a shortage occurrence time has passed',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(database, availableDoses: 2);
      final repository = LocalGuidedCarouselLoadRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-shortage-block',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-1', now, [
              _medication('vitamin-d', 'vitamin-d-morning'),
            ]),
          ],
          shortageSlots: [
            CarouselLoadPlanSlotPreview.shortage(
              position: CarouselPosition(2),
              shortage: CarouselLoadPlanShortage(
                position: CarouselPosition(2),
                bundleKey: '2026-07-23T09:00:00.000Z|vitamin-d-evening',
                scheduledAt: DateTime.utc(2026, 7, 23, 9),
                scheduleIds: const ['vitamin-d-evening'],
              ),
            ),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );

      await database
          .into(database.reminderSchedules)
          .insertOnConflictUpdate(
            ReminderSchedulesCompanion.insert(
              id: 'vitamin-d-evening',
              label: 'vitamin-d-evening',
              prescriptionId: const Value('vitamin-d'),
              profileId: const Value('schedule-1'),
              hour: 9,
              minute: 0,
              isEnabled: true,
              createdAt: now,
              updatedAt: now,
            ),
          );

      final topOffPlan = GuidedCarouselLoadPlan(
        createdAt: now,
        mode: GuidedCarouselLoadMode.topOff,
        priorPosition: CarouselPosition.start,
        slots: [
          CarouselLoadPlanSlotPreview.retained(
            position: CarouselPosition(1),
            scheduleIds: const ['vitamin-d-morning'],
            prescriptionIds: const ['vitamin-d'],
            bundleKey: 'bundle-1',
          ),
          CarouselLoadPlanSlotPreview.loaded(
            position: CarouselPosition(2),
            bundle: CarouselDoseBundle(
              bundleKey: 'bundle-late',
              scheduledAt: DateTime.utc(2026, 7, 23, 9),
              scheduleIds: const ['vitamin-d-evening'],
              medications: [
                CarouselDoseBundleMedication(
                  prescriptionId: 'vitamin-d',
                  prescriptionName: 'vitamin-d',
                  scheduleId: 'vitamin-d-evening',
                  scheduledAt: DateTime.utc(2026, 7, 23, 9),
                  availableDoses: 1,
                  guidedPillIcon: GuidedPillIcon.roundPill,
                  doseCount: 1,
                  createdAt: now,
                  updatedAt: now,
                ),
              ],
            ),
          ),
          ...List<CarouselLoadPlanSlotPreview>.generate(
            12,
            (index) => CarouselLoadPlanSlotPreview.empty(
              position: CarouselPosition(index + 3),
            ),
          ),
        ],
        shortages: const [],
      );

      await expectLater(
        repository.confirmTopOff(
          sessionId: 'session-late-top-off',
          profileId: 'schedule-1',
          predecessorSessionId: 'session-shortage-block',
          plan: topOffPlan,
          startedAt: now,
          confirmedAt: DateTime.utc(2026, 7, 23, 10),
        ),
        throwsA(isA<StateError>()),
      );

      final alerts =
          await (database.select(database.medicationShortageAlerts)..where(
                (row) => row.loadSessionId.equals('session-shortage-block'),
              ))
              .get();
      expect(alerts.every((alert) => alert.status == 'active'), isTrue);

      final doseLogEvents = await database.select(database.doseLogEvents).get();
      expect(
        doseLogEvents.any(
          (event) =>
              event.kind == DoseLogEventKind.doseMissed.name &&
              event.doseId == 'vitamin-d-evening:2026-07-23',
        ),
        isFalse,
      );
    },
  );

  test(
    'rollback on forced failure leaves no partial session or inventory writes',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(database, availableDoses: 2);
      await database.customStatement('''
      CREATE TRIGGER fail_guided_load_inventory_update
      BEFORE UPDATE ON prescriptions
      WHEN NEW.id = 'vitamin-d'
      BEGIN
        SELECT RAISE(ABORT, 'forced guided load failure');
      END;
    ''');
      final repository = LocalGuidedCarouselLoadRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      expect(
        () => repository.confirmFullLoad(
          sessionId: 'session-fail',
          profileId: 'schedule-1',
          plan: _plan(
            now,
            loadedSlots: [
              _loadedSlot(1, 'bundle-1', now, [
                _medication('vitamin-d', 'vitamin-d-morning'),
              ]),
            ],
          ),
          startedAt: now,
          confirmedAt: now,
        ),
        throwsA(isA<Exception>()),
      );

      expect(await repository.readSession('session-fail'), isNull);
      expect(await repository.readActiveLoad('schedule-1'), isNull);
      final prescriptions = await LocalPrescriptionRepository(
        database,
      ).watchPrescriptions().first;
      expect(
        prescriptions.single,
        isA<Prescription>()
            .having((p) => p.availableDoses, 'available', 2)
            .having((p) => p.loadedDoses, 'loaded', 0),
      );
    },
  );

  test('second active confirmed session is rejected when appropriate', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _seedPrescriptionSchedule(database, availableDoses: 4);
    final repository = LocalGuidedCarouselLoadRepository(database);
    final now = DateTime.utc(2026, 7, 23, 8);

    await repository.confirmFullLoad(
      sessionId: 'session-1',
      profileId: 'schedule-1',
      plan: _plan(
        now,
        loadedSlots: [
          _loadedSlot(1, 'bundle-1', now, [
            _medication('vitamin-d', 'vitamin-d-morning'),
          ]),
        ],
      ),
      startedAt: now,
      confirmedAt: now,
    );

    await expectLater(
      repository.confirmFullLoad(
        sessionId: 'session-2',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(2, 'bundle-2', now, [
              _medication('vitamin-d', 'vitamin-d-morning'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'A guided carousel load must be physically unloaded before starting a new full reload for profile "schedule-1".',
        ),
      ),
    );
  });

  test(
    'full reload stays blocked until physical unload clears the active guided load state',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(database, availableDoses: 4);
      final repository = LocalGuidedCarouselLoadRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-stale-block',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-1', now, [
              _medication('vitamin-d', 'vitamin-d-morning'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );

      await LocalGuidedCarouselLoadRepository.markActiveLoadStaleInDatabase(
        database,
        profileId: 'schedule-1',
        reason: 'schedule_changed',
        occurredAt: now.add(const Duration(minutes: 1)),
        details: const {'field': 'hour'},
      );

      await expectLater(
        repository.confirmFullLoad(
          sessionId: 'session-still-blocked',
          profileId: 'schedule-1',
          plan: _plan(
            now,
            loadedSlots: [
              _loadedSlot(1, 'bundle-2', now, [
                _medication('vitamin-d', 'vitamin-d-morning'),
              ]),
            ],
          ),
          startedAt: now,
          confirmedAt: now.add(const Duration(minutes: 2)),
        ),
        throwsA(isA<StateError>()),
      );

      await repository.confirmPhysicalUnload(
        profileId: 'schedule-1',
        activeSessionId: 'session-stale-block',
        recoveredScheduleIds: const ['vitamin-d-morning'],
        occurredAt: now.add(const Duration(minutes: 3)),
      );

      await repository.confirmFullLoad(
        sessionId: 'session-after-unload',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-3', now, [
              _medication('vitamin-d', 'vitamin-d-morning'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now.add(const Duration(minutes: 4)),
      );

      final activeLoad = await repository.readActiveLoad('schedule-1');
      expect(activeLoad?.id, 'session-after-unload');
    },
  );

  test(
    'full load inventory uses one unit per scheduled occurrence even when doseCount is greater than one',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(
        database,
        prescriptionId: 'multi-med',
        scheduleId: 'multi-schedule',
        availableDoses: 4,
      );
      final repository = LocalGuidedCarouselLoadRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-occurrence-inventory',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'multi-bundle', now, [
              _medication('multi-med', 'multi-schedule', doseCount: 2),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );

      final prescriptions = await LocalPrescriptionRepository(
        database,
      ).watchPrescriptions().first;
      expect(
        prescriptions.single,
        isA<Prescription>()
            .having((p) => p.availableDoses, 'available', 3)
            .having((p) => p.loadedDoses, 'loaded', 1),
      );

      final session = await repository.readSession(
        'session-occurrence-inventory',
      );
      expect(session!.slots.first.scheduleIds, ['multi-schedule']);
      expect(session.slots.first.prescriptionIds, ['multi-med']);
    },
  );

  test(
    'top-off confirmation persists successor session metadata and preserves retained prefix while moving only new inventory',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(
        database,
        prescriptionId: 'kept-med-1',
        scheduleId: 'kept-schedule-1',
        availableDoses: 2,
      );
      await _seedPrescriptionSchedule(
        database,
        prescriptionId: 'kept-med-2',
        scheduleId: 'kept-schedule-2',
        availableDoses: 2,
        hour: 9,
      );
      await _seedPrescriptionSchedule(
        database,
        prescriptionId: 'new-med',
        scheduleId: 'new-schedule',
        availableDoses: 2,
        hour: 10,
      );
      final repository = LocalGuidedCarouselLoadRepository(database);
      final planner = GuidedCarouselLoadPlanner();
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-base',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'kept-bundle-1', now, [
              _medication('kept-med-1', 'kept-schedule-1'),
            ]),
            _loadedSlot(2, 'kept-bundle-2', DateTime.utc(2026, 7, 23, 9), [
              _medication(
                'kept-med-2',
                'kept-schedule-2',
                scheduledAt: DateTime.utc(2026, 7, 23, 9),
              ),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );

      await (database.update(
        database.carouselStates,
      )..where((row) => row.profileId.equals('schedule-1'))).write(
        CarouselStatesCompanion(
          currentPosition: Value(5),
          updatedAt: Value(now),
        ),
      );
      await database
          .into(database.medicationShortageAlerts)
          .insert(
            MedicationShortageAlertsCompanion.insert(
              id: 'shortage:session-base:2',
              profileId: 'schedule-1',
              loadSessionId: const Value('session-base'),
              slotNumber: 2,
              bundleKey: '2026-07-23T10:00:00.000Z|new-schedule',
              scheduledAt: DateTime.utc(2026, 7, 23, 10),
              prescriptionIdsJson: '["new-med"]',
              prescriptionNamesJson: '["new-med"]',
              status: 'active',
              localDeliveryState: 'sent',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await database
          .into(database.medicationShortageAlerts)
          .insert(
            MedicationShortageAlertsCompanion.insert(
              id: 'shortage:session-unload:3',
              profileId: 'schedule-1',
              loadSessionId: const Value('session-unload'),
              slotNumber: 3,
              bundleKey: 'bundle-b',
              scheduledAt: now.add(const Duration(hours: 1)),
              prescriptionIdsJson: '["med-b"]',
              prescriptionNamesJson: '["med-b"]',
              status: 'active',
              localDeliveryState: 'pending',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await database
          .into(database.medicationShortageAlerts)
          .insert(
            MedicationShortageAlertsCompanion.insert(
              id: 'shortage:session-base:3',
              profileId: 'schedule-1',
              loadSessionId: const Value('session-base'),
              slotNumber: 3,
              bundleKey: '2026-07-23T10:00:00.000Z|new-schedule',
              scheduledAt: DateTime.utc(2026, 7, 23, 10),
              prescriptionIdsJson: '["new-med"]',
              prescriptionNamesJson: '["new-med"]',
              status: 'active',
              localDeliveryState: 'pending',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final activeSession = (await repository.readActiveLoad('schedule-1'))!;
      final plan = planner.buildTopOffPlan(
        activeSession: activeSession,
        medications: [
          CarouselDoseBundleMedication(
            prescriptionId: 'new-med',
            prescriptionName: 'new-med',
            scheduleId: 'new-schedule',
            scheduledAt: DateTime.utc(2026, 7, 23, 10),
            availableDoses: 2,
            guidedPillIcon: GuidedPillIcon.roundPill,
            doseCount: 1,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        now: now,
      );

      await repository.confirmTopOff(
        sessionId: 'session-top-off',
        profileId: 'schedule-1',
        predecessorSessionId: 'session-base',
        plan: plan,
        startedAt: now,
        confirmedAt: now,
      );

      final session = await repository.readActiveLoad('schedule-1');
      expect(session, isNotNull);
      expect(session!.mode, GuidedCarouselLoadMode.topOff);
      expect(session.predecessorSessionId, 'session-base');
      expect(session.currentPosition.value, 5);
      expect(session.slots[0].status, CarouselLoadSlotStatus.retained);
      expect(session.slots[0].scheduleIds, ['kept-schedule-1']);
      expect(session.slots[1].status, CarouselLoadSlotStatus.retained);
      expect(session.slots[2].status, CarouselLoadSlotStatus.loaded);

      final baseSessionRow = await (database.select(
        database.carouselLoadSessions,
      )..where((row) => row.id.equals('session-base'))).getSingle();
      expect(baseSessionRow.status, 'superseded');

      final sessionRow = await (database.select(
        database.carouselLoadSessions,
      )..where((row) => row.id.equals('session-top-off'))).getSingle();
      expect(sessionRow.mode, 'top_off');
      expect(sessionRow.predecessorSessionId, 'session-base');

      final auditEvents = await LocalAdminAuditRepository(
        database,
      ).watchRecentEvents(limit: 10).first;
      final topOffAudit = auditEvents.firstWhere(
        (event) =>
            event.eventType == AdminAuditEventType.guidedLoadConfirmed &&
            event.targetId == 'session-top-off',
      );
      expect(topOffAudit.summary, 'Confirmed guided top-off for schedule-1.');
      expect(
        topOffAudit.detailsJson,
        contains('"predecessorSessionId":"session-base"'),
      );

      final prescriptions = await LocalPrescriptionRepository(
        database,
      ).watchPrescriptions().first;
      expect(
        prescriptions.firstWhere((p) => p.id == 'kept-med-1'),
        isA<Prescription>()
            .having((p) => p.availableDoses, 'available', 1)
            .having((p) => p.loadedDoses, 'loaded', 1),
      );
      expect(
        prescriptions.firstWhere((p) => p.id == 'new-med'),
        isA<Prescription>()
            .having((p) => p.availableDoses, 'available', 1)
            .having((p) => p.loadedDoses, 'loaded', 1),
      );

      final retiredAlerts = await (database.select(
        database.medicationShortageAlerts,
      )..where((row) => row.loadSessionId.equals('session-base'))).get();
      expect(retiredAlerts, isNotEmpty);
      expect(
        retiredAlerts.every((alert) => alert.status == 'resolved'),
        isTrue,
      );
    },
  );

  test(
    'physical unload clears active load and reconciles loaded inventory into available and review',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(
        database,
        prescriptionId: 'med-a',
        scheduleId: 'schedule-a',
        availableDoses: 2,
      );
      await _seedPrescriptionSchedule(
        database,
        prescriptionId: 'med-b',
        scheduleId: 'schedule-b',
        availableDoses: 2,
        hour: 9,
      );
      final repository = LocalGuidedCarouselLoadRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-unload',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-a', now, [
              _medication('med-a', 'schedule-a'),
            ]),
            _loadedSlot(2, 'bundle-b', DateTime.utc(2026, 7, 23, 9), [
              _medication(
                'med-b',
                'schedule-b',
                scheduledAt: DateTime.utc(2026, 7, 23, 9),
              ),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );
      await database
          .into(database.medicationShortageAlerts)
          .insert(
            MedicationShortageAlertsCompanion.insert(
              id: 'shortage:session-unload:2',
              profileId: 'schedule-1',
              loadSessionId: const Value('session-unload'),
              slotNumber: 2,
              bundleKey: 'bundle-b',
              scheduledAt: now.add(const Duration(hours: 1)),
              prescriptionIdsJson: '["med-b"]',
              prescriptionNamesJson: '["med-b"]',
              status: 'active',
              localDeliveryState: 'sent',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await database
          .into(database.medicationShortageAlerts)
          .insert(
            MedicationShortageAlertsCompanion.insert(
              id: 'shortage:session-unload:4',
              profileId: 'schedule-1',
              loadSessionId: const Value('session-unload'),
              slotNumber: 4,
              bundleKey: 'bundle-b',
              scheduledAt: now.add(const Duration(hours: 1)),
              prescriptionIdsJson: '["med-b"]',
              prescriptionNamesJson: '["med-b"]',
              status: 'past_due',
              localDeliveryState: 'sent',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await database
          .into(database.medicationShortageAlerts)
          .insert(
            MedicationShortageAlertsCompanion.insert(
              id: 'shortage:session-unload:3',
              profileId: 'schedule-1',
              loadSessionId: const Value('session-unload'),
              slotNumber: 3,
              bundleKey: 'bundle-b',
              scheduledAt: now.add(const Duration(hours: 1)),
              prescriptionIdsJson: '["med-b"]',
              prescriptionNamesJson: '["med-b"]',
              status: 'active',
              localDeliveryState: 'pending',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await repository.confirmPhysicalUnload(
        profileId: 'schedule-1',
        activeSessionId: 'session-unload',
        recoveredScheduleIds: const ['schedule-a'],
        occurredAt: now.add(const Duration(minutes: 5)),
      );

      expect(await repository.readActiveLoad('schedule-1'), isNull);
      final stateRow = await (database.select(
        database.carouselStates,
      )..where((row) => row.profileId.equals('schedule-1'))).getSingle();
      expect(stateRow.activeLoadSessionId, isNull);
      expect(stateRow.currentPosition, 0);

      final retiredAlerts = await (database.select(
        database.medicationShortageAlerts,
      )..where((row) => row.loadSessionId.equals('session-unload'))).get();
      expect(retiredAlerts, isNotEmpty);
      expect(retiredAlerts, hasLength(3));
      expect(
        retiredAlerts.every((alert) => alert.status == 'resolved'),
        isTrue,
      );

      final sessionRow = await (database.select(
        database.carouselLoadSessions,
      )..where((row) => row.id.equals('session-unload'))).getSingle();
      expect(sessionRow.status, 'cancelled');

      final auditEvents = await LocalAdminAuditRepository(
        database,
      ).watchRecentEvents(limit: 10).first;
      final unloadAudit = auditEvents.firstWhere(
        (event) =>
            event.eventType ==
                AdminAuditEventType.guidedLoadPhysicallyUnloaded &&
            event.targetId == 'session-unload',
      );
      expect(
        unloadAudit.summary,
        'Physically unloaded guided load for schedule-1.',
      );
      expect(
        unloadAudit.detailsJson,
        contains('"recoveredScheduleIds":["schedule-a"]'),
      );

      final prescriptions = await LocalPrescriptionRepository(
        database,
      ).watchPrescriptions().first;
      expect(
        prescriptions.firstWhere((p) => p.id == 'med-a'),
        isA<Prescription>()
            .having((p) => p.availableDoses, 'available', 2)
            .having((p) => p.loadedDoses, 'loaded', 0)
            .having((p) => p.reviewDoses, 'review', 0),
      );
      expect(
        prescriptions.firstWhere((p) => p.id == 'med-b'),
        isA<Prescription>()
            .having((p) => p.availableDoses, 'available', 1)
            .having((p) => p.loadedDoses, 'loaded', 0)
            .having((p) => p.reviewDoses, 'review', 1),
      );
    },
  );

  test(
    'top-off rollback leaves no partial successor session, inventory movement, or active-state corruption',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(
        database,
        prescriptionId: 'kept-med',
        scheduleId: 'kept-schedule',
        availableDoses: 2,
      );
      await _seedPrescriptionSchedule(
        database,
        prescriptionId: 'new-med',
        scheduleId: 'new-schedule',
        availableDoses: 2,
        hour: 9,
      );
      final repository = LocalGuidedCarouselLoadRepository(database);
      final planner = GuidedCarouselLoadPlanner();
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-base',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'kept-bundle', now, [
              _medication('kept-med', 'kept-schedule'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );

      await (database.update(
        database.carouselStates,
      )..where((row) => row.profileId.equals('schedule-1'))).write(
        CarouselStatesCompanion(
          currentPosition: Value(4),
          updatedAt: Value(now),
        ),
      );

      final activeSession = (await repository.readActiveLoad('schedule-1'))!;
      final plan = planner.buildTopOffPlan(
        activeSession: activeSession,
        medications: [
          CarouselDoseBundleMedication(
            prescriptionId: 'new-med',
            prescriptionName: 'new-med',
            scheduleId: 'new-schedule',
            scheduledAt: DateTime.utc(2026, 7, 23, 9),
            availableDoses: 2,
            guidedPillIcon: GuidedPillIcon.roundPill,
            doseCount: 1,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        now: now,
      );

      await database.customStatement('''
        CREATE TRIGGER fail_top_off_inventory_update
        BEFORE UPDATE ON prescriptions
        WHEN NEW.id = 'new-med'
        BEGIN
          SELECT RAISE(ABORT, 'forced top-off failure');
        END;
      ''');

      expect(
        () => repository.confirmTopOff(
          sessionId: 'session-top-off-fail',
          profileId: 'schedule-1',
          predecessorSessionId: 'session-base',
          plan: plan,
          startedAt: now,
          confirmedAt: now,
        ),
        throwsA(isA<Exception>()),
      );

      expect(await repository.readSession('session-top-off-fail'), isNull);
      final stillActive = await repository.readActiveLoad('schedule-1');
      expect(stillActive, isNotNull);
      expect(stillActive!.id, 'session-base');
      expect(stillActive.currentPosition.value, 4);

      final baseSessionRow = await (database.select(
        database.carouselLoadSessions,
      )..where((row) => row.id.equals('session-base'))).getSingle();
      expect(baseSessionRow.status, 'confirmed');

      final snapshotRows = await (database.select(
        database.carouselLoadSlotSnapshots,
      )..where((row) => row.sessionId.equals('session-top-off-fail'))).get();
      expect(snapshotRows, isEmpty);

      final prescriptions = await LocalPrescriptionRepository(
        database,
      ).watchPrescriptions().first;
      expect(
        prescriptions.firstWhere((p) => p.id == 'kept-med'),
        isA<Prescription>()
            .having((p) => p.availableDoses, 'available', 1)
            .having((p) => p.loadedDoses, 'loaded', 1),
      );
      expect(
        prescriptions.firstWhere((p) => p.id == 'new-med'),
        isA<Prescription>()
            .having((p) => p.availableDoses, 'available', 2)
            .having((p) => p.loadedDoses, 'loaded', 0),
      );
    },
  );

  test(
    'invalid top-off plans are rejected before any session or state mutation',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(
        database,
        prescriptionId: 'kept-med',
        scheduleId: 'kept-schedule',
        availableDoses: 2,
      );
      final repository = LocalGuidedCarouselLoadRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-base',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'kept-bundle', now, [
              _medication('kept-med', 'kept-schedule'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );

      final invalidPlan = GuidedCarouselLoadPlan(
        createdAt: now,
        mode: GuidedCarouselLoadMode.topOff,
        priorPosition: CarouselPosition(3),
        slots: List<CarouselLoadPlanSlotPreview>.generate(
          14,
          (index) => CarouselLoadPlanSlotPreview.empty(
            position: CarouselPosition(index + 1),
          ),
        ),
        shortages: const [],
        invalidReason: GuidedCarouselLoadInvalidReason.interiorEmptyGap,
      );

      await expectLater(
        repository.confirmTopOff(
          sessionId: 'session-invalid-top-off',
          profileId: 'schedule-1',
          predecessorSessionId: 'session-base',
          plan: invalidPlan,
          startedAt: now,
          confirmedAt: now,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(await repository.readSession('session-invalid-top-off'), isNull);
      final activeLoad = await repository.readActiveLoad('schedule-1');
      expect(activeLoad?.id, 'session-base');

      final baseSessionRow = await (database.select(
        database.carouselLoadSessions,
      )..where((row) => row.id.equals('session-base'))).getSingle();
      expect(baseSessionRow.status, 'confirmed');
    },
  );

  test(
    'physical unload conserves inventory for medication entries with doseCount > 1',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(
        database,
        prescriptionId: 'multi-med',
        scheduleId: 'multi-schedule',
        availableDoses: 4,
      );
      final repository = LocalGuidedCarouselLoadRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-multi',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'multi-bundle', now, [
              _medication('multi-med', 'multi-schedule', doseCount: 2),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );

      var prescriptions = await LocalPrescriptionRepository(
        database,
      ).watchPrescriptions().first;
      expect(
        prescriptions.single,
        isA<Prescription>()
            .having((p) => p.availableDoses, 'available', 3)
            .having((p) => p.loadedDoses, 'loaded', 1),
      );

      await repository.confirmPhysicalUnload(
        profileId: 'schedule-1',
        activeSessionId: 'session-multi',
        recoveredScheduleIds: const ['multi-schedule'],
        occurredAt: now.add(const Duration(minutes: 1)),
      );

      prescriptions = await LocalPrescriptionRepository(
        database,
      ).watchPrescriptions().first;
      expect(
        prescriptions.single,
        isA<Prescription>()
            .having((p) => p.availableDoses, 'available', 4)
            .having((p) => p.loadedDoses, 'loaded', 0)
            .having((p) => p.reviewDoses, 'review', 0),
      );
    },
  );

  test(
    'physical unload reconciles pre-dispense needs-review inventory without stranding loaded doses',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(
        database,
        prescriptionId: 'vitamin-d',
        scheduleId: 'vitamin-d-morning',
        availableDoses: 1,
      );
      final repository = LocalGuidedCarouselLoadRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-quarantine-unload',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-1', now, [
              _medication('vitamin-d', 'vitamin-d-morning'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );

      await repository.quarantineSlotForReview(
        profileId: 'schedule-1',
        activeSessionId: 'session-quarantine-unload',
        slotNumber: 1,
        occurredAt: now.add(const Duration(minutes: 1)),
        reason: 'timeout',
      );

      var prescriptions = await LocalPrescriptionRepository(
        database,
      ).watchPrescriptions().first;
      expect(
        prescriptions.single,
        isA<Prescription>()
            .having((p) => p.availableDoses, 'available', 0)
            .having((p) => p.loadedDoses, 'loaded', 0)
            .having((p) => p.reviewDoses, 'review', 1),
      );

      await repository.confirmPhysicalUnload(
        profileId: 'schedule-1',
        activeSessionId: 'session-quarantine-unload',
        recoveredScheduleIds: const [],
        recoveredSlotNumbers: const [],
        occurredAt: now.add(const Duration(minutes: 2)),
      );

      prescriptions = await LocalPrescriptionRepository(
        database,
      ).watchPrescriptions().first;
      expect(
        prescriptions.single,
        isA<Prescription>()
            .having((p) => p.availableDoses, 'available', 0)
            .having((p) => p.loadedDoses, 'loaded', 0)
            .having((p) => p.reviewDoses, 'review', 1),
      );
    },
  );

  test(
    'physical unload recovers only the selected guided slot when the same schedule appears in multiple slots and audits the slot numbers',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(
        database,
        prescriptionId: 'vitamin-d',
        scheduleId: 'vitamin-d-morning',
        availableDoses: 2,
      );
      final repository = LocalGuidedCarouselLoadRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-repeat-unload',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-1', now, [
              _medication('vitamin-d', 'vitamin-d-morning', scheduledAt: now),
            ]),
            _loadedSlot(2, 'bundle-2', now.add(const Duration(days: 1)), [
              _medication(
                'vitamin-d',
                'vitamin-d-morning',
                scheduledAt: now.add(const Duration(days: 1)),
              ),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );

      await repository.confirmPhysicalUnload(
        profileId: 'schedule-1',
        activeSessionId: 'session-repeat-unload',
        recoveredScheduleIds: const ['vitamin-d-morning'],
        recoveredSlotNumbers: const [1],
        occurredAt: now.add(const Duration(minutes: 1)),
      );

      final prescriptions = await LocalPrescriptionRepository(
        database,
      ).watchPrescriptions().first;
      expect(
        prescriptions.single,
        isA<Prescription>()
            .having((p) => p.availableDoses, 'available', 1)
            .having((p) => p.loadedDoses, 'loaded', 0)
            .having((p) => p.reviewDoses, 'review', 1),
      );

      final auditEvents = await LocalAdminAuditRepository(
        database,
      ).watchRecentEvents(limit: 10).first;
      final unloadAudit = auditEvents.firstWhere(
        (event) =>
            event.eventType ==
                AdminAuditEventType.guidedLoadPhysicallyUnloaded &&
            event.targetId == 'session-repeat-unload',
      );
      expect(unloadAudit.detailsJson, contains('"recoveredSlotNumbers":[1]'));
      expect(
        unloadAudit.detailsJson,
        contains('"recoveredScheduleIds":["vitamin-d-morning"]'),
      );
    },
  );

  test(
    'read/watch active load returns the active confirmed session with 14 hydrated snapshots and position metadata',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(database);
      final repository = LocalGuidedCarouselLoadRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      final values = <CarouselLoadSession?>[];
      final subscription = repository
          .watchActiveLoad('schedule-1')
          .listen(values.add);
      addTearDown(subscription.cancel);

      await Future<void>.delayed(Duration.zero);
      await (database.update(
        database.carouselStates,
      )..where((row) => row.profileId.equals('schedule-1'))).write(
        CarouselStatesCompanion(
          currentPosition: Value(7),
          updatedAt: Value(now),
        ),
      );
      await repository.confirmFullLoad(
        sessionId: 'session-watch',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-watch', now, [
              _medication('vitamin-d', 'vitamin-d-morning'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );
      await Future<void>.delayed(Duration.zero);

      final activeLoad = await repository.readActiveLoad('schedule-1');
      expect(activeLoad, isNotNull);
      expect(activeLoad!.id, 'session-watch');
      expect(activeLoad.currentPosition, CarouselPosition.start);
      expect(activeLoad.slots, hasLength(14));

      expect(values.first, isNull);
      expect(values.last?.id, 'session-watch');
      expect(values.last?.currentPosition.value, 0);
    },
  );

  test(
    'watch active load hydrates updated current position from carousel state',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(database);
      final repository = LocalGuidedCarouselLoadRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-watch-position',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-watch', now, [
              _medication('vitamin-d', 'vitamin-d-morning'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );

      final values = <CarouselLoadSession?>[];
      final subscription = repository
          .watchActiveLoad('schedule-1')
          .listen(values.add);
      addTearDown(subscription.cancel);

      await Future<void>.delayed(Duration.zero);
      await (database.update(
        database.carouselStates,
      )..where((row) => row.profileId.equals('schedule-1'))).write(
        CarouselStatesCompanion(
          currentPosition: Value(9),
          updatedAt: Value(now.add(const Duration(minutes: 1))),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(values.last, isNotNull);
      expect(values.last!.currentPosition.value, 9);
    },
  );

  test(
    'schedule time changes stale the active load and write an audit event',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(database);
      final repository = LocalGuidedCarouselLoadRepository(database);
      final reminderRepository = LocalReminderRepository(database);
      final auditRepository = LocalAdminAuditRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-stale-time',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-stale', now, [
              _medication('vitamin-d', 'vitamin-d-morning'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );

      await reminderRepository.upsertSchedule(
        ReminderSchedule(
          id: 'vitamin-d-morning',
          label: 'vitamin-d',
          prescriptionId: 'vitamin-d',
          profileId: 'schedule-1',
          hour: 9,
          minute: 0,
          isEnabled: true,
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );

      final activeLoad = await repository.readActiveLoad('schedule-1');
      expect(activeLoad, isNotNull);
      expect(activeLoad!.status, CarouselLoadSessionStatus.stale);

      final events = await auditRepository.watchRecentEvents(limit: 20).first;
      final staleEvent = events.firstWhere(
        (event) => event.eventType == AdminAuditEventType.guidedLoadMarkedStale,
      );
      expect(staleEvent.summary, 'Marked guided load stale for schedule-1.');
      expect(staleEvent.detailsJson, contains('"reason":"schedule_changed"'));
      expect(
        staleEvent.detailsJson,
        contains('"scheduleId":"vitamin-d-morning"'),
      );
    },
  );

  test(
    'watch active load emits when the active session becomes stale',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(database);
      final repository = LocalGuidedCarouselLoadRepository(database);
      final reminderRepository = LocalReminderRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-watch-stale',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-watch-stale', now, [
              _medication('vitamin-d', 'vitamin-d-morning'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );

      final states = <CarouselLoadSession?>[];
      final subscription = repository
          .watchActiveLoad('schedule-1')
          .listen(states.add);
      addTearDown(subscription.cancel);
      await Future<void>.delayed(Duration.zero);

      await reminderRepository.upsertSchedule(
        ReminderSchedule(
          id: 'vitamin-d-morning',
          label: 'vitamin-d',
          prescriptionId: 'vitamin-d',
          profileId: 'schedule-1',
          hour: 9,
          minute: 0,
          isEnabled: true,
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(states.last, isNotNull);
      expect(states.last!.status, CarouselLoadSessionStatus.stale);
    },
  );

  test('schedule enable/disable changes stale the active load', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _seedPrescriptionSchedule(database);
    final repository = LocalGuidedCarouselLoadRepository(database);
    final reminderRepository = LocalReminderRepository(database);
    final now = DateTime.utc(2026, 7, 23, 8);

    await repository.confirmFullLoad(
      sessionId: 'session-toggle-stale',
      profileId: 'schedule-1',
      plan: _plan(
        now,
        loadedSlots: [
          _loadedSlot(1, 'bundle-toggle', now, [
            _medication('vitamin-d', 'vitamin-d-morning'),
          ]),
        ],
      ),
      startedAt: now,
      confirmedAt: now,
    );

    await reminderRepository.upsertSchedule(
      ReminderSchedule(
        id: 'vitamin-d-morning',
        label: 'vitamin-d',
        prescriptionId: 'vitamin-d',
        profileId: 'schedule-1',
        hour: 8,
        minute: 0,
        isEnabled: false,
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 1)),
      ),
    );

    final activeLoad = await repository.readActiveLoad('schedule-1');
    expect(activeLoad, isNotNull);
    expect(activeLoad!.status, CarouselLoadSessionStatus.stale);
  });

  test(
    'disabled schedule edits that remain disabled do not stale the active load',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(database);
      final repository = LocalGuidedCarouselLoadRepository(database);
      final reminderRepository = LocalReminderRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await reminderRepository.upsertSchedule(
        ReminderSchedule(
          id: 'vitamin-d-morning',
          label: 'vitamin-d',
          prescriptionId: 'vitamin-d',
          profileId: 'schedule-1',
          hour: 8,
          minute: 0,
          isEnabled: false,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.confirmFullLoad(
        sessionId: 'session-disabled-no-stale',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-disabled', now, [
              _medication('vitamin-d', 'vitamin-d-morning'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );

      await reminderRepository.upsertSchedule(
        ReminderSchedule(
          id: 'vitamin-d-morning',
          label: 'vitamin-d',
          prescriptionId: 'vitamin-d',
          profileId: 'schedule-1',
          hour: 10,
          minute: 0,
          isEnabled: false,
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );

      final activeLoad = await repository.readActiveLoad('schedule-1');
      expect(activeLoad, isNotNull);
      expect(activeLoad!.status, CarouselLoadSessionStatus.confirmed);
    },
  );

  test('prescription reassignment stales the active load', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _seedPrescriptionSchedule(
      database,
      prescriptionId: 'med-a',
      scheduleId: 'schedule-a',
    );
    await _seedPrescriptionSchedule(
      database,
      prescriptionId: 'med-b',
      scheduleId: 'schedule-b',
      hour: 9,
    );
    final repository = LocalGuidedCarouselLoadRepository(database);
    final reminderRepository = LocalReminderRepository(database);
    final now = DateTime.utc(2026, 7, 23, 8);

    await repository.confirmFullLoad(
      sessionId: 'session-reassign-stale',
      profileId: 'schedule-1',
      plan: _plan(
        now,
        loadedSlots: [
          _loadedSlot(1, 'bundle-a', now, [_medication('med-a', 'schedule-a')]),
        ],
      ),
      startedAt: now,
      confirmedAt: now,
    );

    await reminderRepository.upsertSchedule(
      ReminderSchedule(
        id: 'schedule-a',
        label: 'med-b',
        prescriptionId: 'med-b',
        profileId: 'schedule-1',
        hour: 8,
        minute: 0,
        isEnabled: true,
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 1)),
      ),
    );

    final activeLoad = await repository.readActiveLoad('schedule-1');
    expect(activeLoad, isNotNull);
    expect(activeLoad!.status, CarouselLoadSessionStatus.stale);
  });

  test(
    'dose-composition-only prescription changes stale the active load',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(database);
      final repository = LocalGuidedCarouselLoadRepository(database);
      final prescriptionRepository = LocalPrescriptionRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-composition-stale',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-comp', now, [
              _medication('vitamin-d', 'vitamin-d-morning'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );

      await prescriptionRepository.upsertPrescription(
        Prescription(
          id: 'vitamin-d',
          name: 'vitamin-d',
          pillType: PillType.capsule,
          availableDoses: 0,
          loadedDoses: 1,
          defaultDoseCountPerDose: 2,
          doseInstructions: 'Take with water',
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );

      final activeLoad = await repository.readActiveLoad('schedule-1');
      expect(activeLoad, isNotNull);
      expect(activeLoad!.status, CarouselLoadSessionStatus.stale);
    },
  );

  test(
    'inventory-only and display-only prescription edits do not stale the active load',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(database, availableDoses: 3);
      final repository = LocalGuidedCarouselLoadRepository(database);
      final prescriptionRepository = LocalPrescriptionRepository(database);
      final auditRepository = LocalAdminAuditRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-no-stale',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-keep', now, [
              _medication('vitamin-d', 'vitamin-d-morning'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );

      await prescriptionRepository.upsertPrescription(
        Prescription(
          id: 'vitamin-d',
          name: 'Vitamin D renamed',
          pillType: PillType.capsule,
          guidedPillIcon: GuidedPillIcon.capsule,
          availableDoses: 5,
          loadedDoses: 1,
          defaultRefillQuantity: 99,
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );

      final activeLoad = await repository.readActiveLoad('schedule-1');
      expect(activeLoad, isNotNull);
      expect(activeLoad!.status, CarouselLoadSessionStatus.confirmed);

      final events = await auditRepository.watchRecentEvents(limit: 20).first;
      expect(
        events.any(
          (event) =>
              event.eventType == AdminAuditEventType.guidedLoadMarkedStale,
        ),
        isFalse,
      );
    },
  );

  test(
    'active profile changes and prescription deletion stale dependent active loads',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final profileRepository = LocalScheduleProfileRepository(database);
      await profileRepository.upsertProfile(
        ScheduleProfile(
          id: 'schedule-2',
          name: 'Schedule 2',
          isActive: false,
          createdAt: DateTime.utc(2026, 7, 23, 7),
          updatedAt: DateTime.utc(2026, 7, 23, 7),
        ),
      );
      await _seedPrescriptionSchedule(
        database,
        prescriptionId: 'med-a',
        scheduleId: 'schedule-a',
        availableDoses: 2,
      );
      final repository = LocalGuidedCarouselLoadRepository(database);
      final prescriptionRepository = LocalPrescriptionRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-profile-stale',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-a', now, [
              _medication('med-a', 'schedule-a'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );

      await profileRepository.setActiveProfile('schedule-2');
      var activeLoad = await repository.readActiveLoad('schedule-1');
      expect(activeLoad, isNotNull);
      expect(activeLoad!.status, CarouselLoadSessionStatus.stale);

      await repository.confirmPhysicalUnload(
        profileId: 'schedule-1',
        activeSessionId: 'session-profile-stale',
        recoveredScheduleIds: const ['schedule-a'],
        occurredAt: now.add(const Duration(minutes: 1)),
      );
      await repository.confirmFullLoad(
        sessionId: 'session-delete-stale',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-b', now, [
              _medication('med-a', 'schedule-a'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );

      await prescriptionRepository.deletePrescription('med-a');
      activeLoad = await repository.readActiveLoad('schedule-1');
      expect(activeLoad, isNotNull);
      expect(activeLoad!.status, CarouselLoadSessionStatus.stale);
    },
  );

  test(
    'setting an already active profile does not stale the active load',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(database);
      final repository = LocalGuidedCarouselLoadRepository(database);
      final profileRepository = LocalScheduleProfileRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-same-profile',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-same-profile', now, [
              _medication('vitamin-d', 'vitamin-d-morning'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );

      await profileRepository.setActiveProfile('schedule-1');

      final activeLoad = await repository.readActiveLoad('schedule-1');
      expect(activeLoad, isNotNull);
      expect(activeLoad!.status, CarouselLoadSessionStatus.confirmed);
    },
  );

  test('prescription deletion leaves stale unload safe', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _seedPrescriptionSchedule(
      database,
      prescriptionId: 'delete-med',
      scheduleId: 'delete-schedule',
      availableDoses: 2,
    );
    final repository = LocalGuidedCarouselLoadRepository(database);
    final prescriptionRepository = LocalPrescriptionRepository(database);
    final now = DateTime.utc(2026, 7, 23, 8);

    await repository.confirmFullLoad(
      sessionId: 'session-delete-safe',
      profileId: 'schedule-1',
      plan: _plan(
        now,
        loadedSlots: [
          _loadedSlot(1, 'bundle-delete', now, [
            _medication('delete-med', 'delete-schedule'),
          ]),
        ],
      ),
      startedAt: now,
      confirmedAt: now,
    );

    await prescriptionRepository.deletePrescription('delete-med');
    await repository.confirmPhysicalUnload(
      profileId: 'schedule-1',
      activeSessionId: 'session-delete-safe',
      recoveredScheduleIds: const ['delete-schedule'],
      occurredAt: now.add(const Duration(minutes: 1)),
    );

    expect(await repository.readActiveLoad('schedule-1'), isNull);
    final prescriptions = await LocalPrescriptionRepository(
      database,
    ).watchPrescriptions().first;
    expect(
      prescriptions.any((prescription) => prescription.id == 'delete-med'),
      isFalse,
    );
  });

  test(
    'deleting a prescription after schedule reassignment still defers safely from stale active-load snapshots and removes it after unload',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(
        database,
        prescriptionId: 'stale-med',
        scheduleId: 'stale-schedule',
        availableDoses: 2,
      );
      await _seedPrescriptionSchedule(
        database,
        prescriptionId: 'replacement-med',
        scheduleId: 'replacement-schedule',
        availableDoses: 2,
        hour: 9,
      );
      final repository = LocalGuidedCarouselLoadRepository(database);
      final reminderRepository = LocalReminderRepository(database);
      final prescriptionRepository = LocalPrescriptionRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-stale-delete',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-stale-delete', now, [
              _medication('stale-med', 'stale-schedule'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );

      await reminderRepository.upsertSchedule(
        ReminderSchedule(
          id: 'stale-schedule',
          label: 'replacement-med',
          prescriptionId: 'replacement-med',
          profileId: 'schedule-1',
          hour: 8,
          minute: 0,
          isEnabled: true,
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );

      await prescriptionRepository.deletePrescription('stale-med');
      var prescriptions = await LocalPrescriptionRepository(
        database,
      ).watchPrescriptions().first;
      expect(
        prescriptions.any((prescription) => prescription.id == 'stale-med'),
        isFalse,
      );
      await expectLater(
        () => prescriptionRepository.addRefill(
          prescriptionId: 'stale-med',
          doseCount: 1,
          occurredAt: now.add(const Duration(minutes: 1)),
        ),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        () => prescriptionRepository.recordTakenDose(
          'stale-med',
          occurredAt: now.add(const Duration(minutes: 1)),
        ),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        () => prescriptionRepository.upsertPrescription(
          Prescription(
            id: 'stale-med',
            name: 'stale-med updated',
            pillType: PillType.capsule,
            availableDoses: 0,
            loadedDoses: 1,
            createdAt: now,
            updatedAt: now.add(const Duration(minutes: 1)),
          ),
        ),
        throwsA(isA<StateError>()),
      );

      await repository.confirmPhysicalUnload(
        profileId: 'schedule-1',
        activeSessionId: 'session-stale-delete',
        recoveredScheduleIds: const ['stale-schedule'],
        occurredAt: now.add(const Duration(minutes: 2)),
      );

      prescriptions = await LocalPrescriptionRepository(
        database,
      ).watchPrescriptions().first;
      expect(
        prescriptions.any((prescription) => prescription.id == 'stale-med'),
        isFalse,
      );
      final rawPrescriptionRow =
          await (database.select(database.prescriptions)
                ..where((prescription) => prescription.id.equals('stale-med')))
              .getSingleOrNull();
      expect(rawPrescriptionRow, isNull);
      final deferredDeleteMarker = await database.getAppSettings({
        'deferred_deleted_prescription:stale-med',
      });
      expect(deferredDeleteMarker, isEmpty);
    },
  );

  test(
    'deleting a schedule before deleting its prescription still defers from stale active-load snapshots and removes it after unload',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(
        database,
        prescriptionId: 'schedule-deleted-med',
        scheduleId: 'schedule-deleted-slot',
        availableDoses: 2,
      );
      final repository = LocalGuidedCarouselLoadRepository(database);
      final reminderRepository = LocalReminderRepository(database);
      final prescriptionRepository = LocalPrescriptionRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-schedule-delete-path',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-schedule-delete', now, [
              _medication('schedule-deleted-med', 'schedule-deleted-slot'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );

      await reminderRepository.deleteSchedule('schedule-deleted-slot');
      await prescriptionRepository.deletePrescription('schedule-deleted-med');

      var prescriptions = await LocalPrescriptionRepository(
        database,
      ).watchPrescriptions().first;
      expect(
        prescriptions.any(
          (prescription) => prescription.id == 'schedule-deleted-med',
        ),
        isFalse,
      );

      await repository.confirmPhysicalUnload(
        profileId: 'schedule-1',
        activeSessionId: 'session-schedule-delete-path',
        recoveredScheduleIds: const ['schedule-deleted-slot'],
        occurredAt: now.add(const Duration(minutes: 2)),
      );

      prescriptions = await LocalPrescriptionRepository(
        database,
      ).watchPrescriptions().first;
      expect(
        prescriptions.any(
          (prescription) => prescription.id == 'schedule-deleted-med',
        ),
        isFalse,
      );
      final rawPrescriptionRow =
          await (database.select(database.prescriptions)..where(
                (prescription) =>
                    prescription.id.equals('schedule-deleted-med'),
              ))
              .getSingleOrNull();
      expect(rawPrescriptionRow, isNull);
      final deferredDeleteMarker = await database.getAppSettings({
        'deferred_deleted_prescription:schedule-deleted-med',
      });
      expect(deferredDeleteMarker, isEmpty);
    },
  );

  test(
    'top-off rejects stale active sessions and requires review/reload',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(database);
      final repository = LocalGuidedCarouselLoadRepository(database);
      final reminderRepository = LocalReminderRepository(database);
      final planner = GuidedCarouselLoadPlanner();
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-stale-top-off',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-stale-top-off', now, [
              _medication('vitamin-d', 'vitamin-d-morning'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );

      await reminderRepository.upsertSchedule(
        ReminderSchedule(
          id: 'vitamin-d-morning',
          label: 'vitamin-d',
          prescriptionId: 'vitamin-d',
          profileId: 'schedule-1',
          hour: 9,
          minute: 0,
          isEnabled: true,
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );

      final staleSession = (await repository.readActiveLoad('schedule-1'))!;
      final plan = planner.buildTopOffPlan(
        activeSession: staleSession,
        medications: const [],
        now: now,
      );

      await expectLater(
        repository.confirmTopOff(
          sessionId: 'session-should-fail',
          profileId: 'schedule-1',
          predecessorSessionId: 'session-stale-top-off',
          plan: plan,
          startedAt: now,
          confirmedAt: now,
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('dispense movement is blocked for stale and shortage states', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _seedPrescriptionSchedule(database);
    final repository = LocalGuidedCarouselLoadRepository(database);
    final now = DateTime.utc(2026, 7, 23, 8);

    await repository.confirmFullLoad(
      sessionId: 'session-dispense-block',
      profileId: 'schedule-1',
      plan: _plan(
        now,
        loadedSlots: [
          _loadedSlot(1, 'bundle-1', now, [
            _medication('vitamin-d', 'vitamin-d-morning'),
          ]),
        ],
        shortageSlots: [
          CarouselLoadPlanSlotPreview.shortage(
            position: CarouselPosition(2),
            shortage: CarouselLoadPlanShortage(
              position: CarouselPosition(2),
              bundleKey: '2026-07-23T09:00:00.000Z|vitamin-d-evening',
              scheduledAt: DateTime.utc(2026, 7, 23, 9),
              scheduleIds: const ['vitamin-d-evening'],
            ),
          ),
        ],
      ),
      startedAt: now,
      confirmedAt: now,
    );

    await LocalGuidedCarouselLoadRepository.markActiveLoadStaleInDatabase(
      database,
      profileId: 'schedule-1',
      reason: 'manual_test',
      occurredAt: now.add(const Duration(minutes: 1)),
      details: const <String, Object?>{},
    );

    await expectLater(
      repository.recordDispenseMovementSucceeded(
        profileId: 'schedule-1',
        activeSessionId: 'session-dispense-block',
        slotNumber: 1,
        occurredAt: now.add(const Duration(minutes: 2)),
      ),
      throwsA(isA<StateError>()),
    );

    await repository.confirmPhysicalUnload(
      profileId: 'schedule-1',
      activeSessionId: 'session-dispense-block',
      recoveredScheduleIds: const ['vitamin-d-morning'],
      occurredAt: now.add(const Duration(minutes: 3)),
    );
    await repository.confirmFullLoad(
      sessionId: 'session-shortage-block-dispense',
      profileId: 'schedule-1',
      plan: _plan(
        now,
        loadedSlots: [
          _loadedSlot(1, 'bundle-1', now, [
            _medication('vitamin-d', 'vitamin-d-morning'),
          ]),
        ],
        shortageSlots: [
          CarouselLoadPlanSlotPreview.shortage(
            position: CarouselPosition(2),
            shortage: CarouselLoadPlanShortage(
              position: CarouselPosition(2),
              bundleKey: '2026-07-23T09:00:00.000Z|vitamin-d-evening',
              scheduledAt: DateTime.utc(2026, 7, 23, 9),
              scheduleIds: const ['vitamin-d-evening'],
            ),
          ),
        ],
      ),
      startedAt: now,
      confirmedAt: now,
    );

    await expectLater(
      repository.recordDispenseMovementSucceeded(
        profileId: 'schedule-1',
        activeSessionId: 'session-shortage-block-dispense',
        slotNumber: 2,
        occurredAt: now.add(const Duration(minutes: 4)),
      ),
      throwsA(isA<StateError>()),
    );

    await expectLater(
      repository.recordDispenseMovementSucceeded(
        profileId: 'schedule-1',
        activeSessionId: 'session-shortage-block-dispense',
        slotNumber: 3,
        occurredAt: now.add(const Duration(minutes: 5)),
      ),
      throwsA(isA<StateError>()),
    );

    await repository.confirmPhysicalUnload(
      profileId: 'schedule-1',
      activeSessionId: 'session-shortage-block-dispense',
      recoveredScheduleIds: const ['vitamin-d-morning'],
      occurredAt: now.add(const Duration(minutes: 6)),
    );
    await repository.confirmFullLoad(
      sessionId: 'session-review-block',
      profileId: 'schedule-1',
      plan: _plan(
        now,
        loadedSlots: [
          _loadedSlot(1, 'bundle-1', now, [
            _medication('vitamin-d', 'vitamin-d-morning'),
          ]),
        ],
      ),
      startedAt: now,
      confirmedAt: now,
    );
    await repository.recordDispenseMovementSucceeded(
      profileId: 'schedule-1',
      activeSessionId: 'session-review-block',
      slotNumber: 1,
      occurredAt: now.add(const Duration(minutes: 7)),
    );
    await repository.confirmDispensedSlotNeedsReview(
      profileId: 'schedule-1',
      activeSessionId: 'session-review-block',
      slotNumber: 1,
      occurredAt: now.add(const Duration(minutes: 8)),
      reason: 'visibly_absent',
    );

    await expectLater(
      repository.recordDispenseMovementSucceeded(
        profileId: 'schedule-1',
        activeSessionId: 'session-review-block',
        slotNumber: 1,
        occurredAt: now.add(const Duration(minutes: 9)),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('dispense movement updates position without taken mutation', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _seedPrescriptionSchedule(database, availableDoses: 2);
    final repository = LocalGuidedCarouselLoadRepository(database);
    final now = DateTime.utc(2026, 7, 23, 8);

    await repository.confirmFullLoad(
      sessionId: 'session-dispense-move',
      profileId: 'schedule-1',
      plan: _plan(
        now,
        loadedSlots: [
          _loadedSlot(1, 'bundle-1', now, [
            _medication('vitamin-d', 'vitamin-d-morning'),
          ]),
        ],
      ),
      startedAt: now,
      confirmedAt: now,
    );

    await repository.recordDispenseMovementSucceeded(
      profileId: 'schedule-1',
      activeSessionId: 'session-dispense-move',
      slotNumber: 1,
      occurredAt: now.add(const Duration(minutes: 1)),
    );

    final activeLoad = await repository.readActiveLoad('schedule-1');
    expect(activeLoad, isNotNull);
    expect(activeLoad!.currentPosition.value, 1);
    expect(activeLoad.slots.first.status, CarouselLoadSlotStatus.dispensed);

    final session = await repository.readSession('session-dispense-move');
    expect(session, isNotNull);
    expect(session!.currentPosition.value, 1);

    final prescriptions = await LocalPrescriptionRepository(
      database,
    ).watchPrescriptions().first;
    expect(
      prescriptions.single,
      isA<Prescription>()
          .having((p) => p.loadedDoses, 'loaded', 1)
          .having((p) => p.usedDoses, 'used', 0),
    );
  });

  test(
    'confirmed taken moves loaded inventory to used without double-application',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(database, availableDoses: 2);
      final repository = LocalGuidedCarouselLoadRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-taken',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-1', now, [
              _medication('vitamin-d', 'vitamin-d-morning'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );
      await repository.recordDispenseMovementSucceeded(
        profileId: 'schedule-1',
        activeSessionId: 'session-taken',
        slotNumber: 1,
        occurredAt: now.add(const Duration(minutes: 1)),
      );

      await repository.confirmDispensedSlotTaken(
        profileId: 'schedule-1',
        activeSessionId: 'session-taken',
        slotNumber: 1,
        occurredAt: now.add(const Duration(minutes: 2)),
      );
      await repository.confirmDispensedSlotTaken(
        profileId: 'schedule-1',
        activeSessionId: 'session-taken',
        slotNumber: 1,
        occurredAt: now.add(const Duration(minutes: 3)),
      );

      final prescriptions = await LocalPrescriptionRepository(
        database,
      ).watchPrescriptions().first;
      expect(
        prescriptions.single,
        isA<Prescription>()
            .having((p) => p.loadedDoses, 'loaded', 0)
            .having((p) => p.usedDoses, 'used', 1),
      );
    },
  );

  test(
    'review transition moves loaded inventory to review without double-application',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(database, availableDoses: 2);
      final repository = LocalGuidedCarouselLoadRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-review',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-1', now, [
              _medication('vitamin-d', 'vitamin-d-morning'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );
      await repository.recordDispenseMovementSucceeded(
        profileId: 'schedule-1',
        activeSessionId: 'session-review',
        slotNumber: 1,
        occurredAt: now.add(const Duration(minutes: 1)),
      );

      await repository.confirmDispensedSlotNeedsReview(
        profileId: 'schedule-1',
        activeSessionId: 'session-review',
        slotNumber: 1,
        occurredAt: now.add(const Duration(minutes: 2)),
        reason: 'visibly_absent',
      );
      await repository.confirmDispensedSlotNeedsReview(
        profileId: 'schedule-1',
        activeSessionId: 'session-review',
        slotNumber: 1,
        occurredAt: now.add(const Duration(minutes: 3)),
        reason: 'visibly_absent',
      );

      final activeLoad = await repository.readActiveLoad('schedule-1');
      expect(
        activeLoad!.slots.first.status,
        CarouselLoadSlotStatus.needsReview,
      );
      final prescriptions = await LocalPrescriptionRepository(
        database,
      ).watchPrescriptions().first;
      expect(
        prescriptions.single,
        isA<Prescription>()
            .having((p) => p.loadedDoses, 'loaded', 0)
            .having((p) => p.reviewDoses, 'review', 1),
      );
    },
  );

  test(
    'physical unload reconciles an unresolved dispensed slot without stranding loaded inventory',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(database, availableDoses: 2);
      final repository = LocalGuidedCarouselLoadRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-dispensed-unload',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-1', now, [
              _medication('vitamin-d', 'vitamin-d-morning'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );
      await repository.recordDispenseMovementSucceeded(
        profileId: 'schedule-1',
        activeSessionId: 'session-dispensed-unload',
        slotNumber: 1,
        occurredAt: now.add(const Duration(minutes: 1)),
      );

      await repository.confirmPhysicalUnload(
        profileId: 'schedule-1',
        activeSessionId: 'session-dispensed-unload',
        recoveredScheduleIds: const [],
        occurredAt: now.add(const Duration(minutes: 2)),
      );

      final prescriptions = await LocalPrescriptionRepository(
        database,
      ).watchPrescriptions().first;
      expect(
        prescriptions.single,
        isA<Prescription>()
            .having((p) => p.loadedDoses, 'loaded', 0)
            .having((p) => p.reviewDoses, 'review', 1),
      );
    },
  );

  test(
    'physical unload does not re-apply inventory after a dispensed slot was already confirmed taken',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(database, availableDoses: 2);
      final repository = LocalGuidedCarouselLoadRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-dispensed-taken-unload',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-1', now, [
              _medication('vitamin-d', 'vitamin-d-morning'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );
      await repository.recordDispenseMovementSucceeded(
        profileId: 'schedule-1',
        activeSessionId: 'session-dispensed-taken-unload',
        slotNumber: 1,
        occurredAt: now.add(const Duration(minutes: 1)),
      );
      await repository.confirmDispensedSlotTaken(
        profileId: 'schedule-1',
        activeSessionId: 'session-dispensed-taken-unload',
        slotNumber: 1,
        occurredAt: now.add(const Duration(minutes: 2)),
      );

      await repository.confirmPhysicalUnload(
        profileId: 'schedule-1',
        activeSessionId: 'session-dispensed-taken-unload',
        recoveredScheduleIds: const [],
        occurredAt: now.add(const Duration(minutes: 3)),
      );

      final prescriptions = await LocalPrescriptionRepository(
        database,
      ).watchPrescriptions().first;
      expect(
        prescriptions.single,
        isA<Prescription>()
            .having((p) => p.loadedDoses, 'loaded', 0)
            .having((p) => p.usedDoses, 'used', 1)
            .having((p) => p.reviewDoses, 'review', 0),
      );
    },
  );

  test(
    'confirmed taken rejects a non-active session id without mutating inventory',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(database, availableDoses: 2);
      final repository = LocalGuidedCarouselLoadRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-active',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-1', now, [
              _medication('vitamin-d', 'vitamin-d-morning'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );
      await repository.recordDispenseMovementSucceeded(
        profileId: 'schedule-1',
        activeSessionId: 'session-active',
        slotNumber: 1,
        occurredAt: now.add(const Duration(minutes: 1)),
      );

      await expectLater(
        repository.confirmDispensedSlotTaken(
          profileId: 'schedule-1',
          activeSessionId: 'session-other',
          slotNumber: 1,
          occurredAt: now.add(const Duration(minutes: 2)),
        ),
        throwsA(isA<StateError>()),
      );

      final prescriptions = await LocalPrescriptionRepository(
        database,
      ).watchPrescriptions().first;
      expect(
        prescriptions.single,
        isA<Prescription>()
            .having((p) => p.loadedDoses, 'loaded', 1)
            .having((p) => p.usedDoses, 'used', 0),
      );
    },
  );

  test(
    'review confirmation rejects a non-active session id without mutating inventory',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescriptionSchedule(database, availableDoses: 2);
      final repository = LocalGuidedCarouselLoadRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-active',
        profileId: 'schedule-1',
        plan: _plan(
          now,
          loadedSlots: [
            _loadedSlot(1, 'bundle-1', now, [
              _medication('vitamin-d', 'vitamin-d-morning'),
            ]),
          ],
        ),
        startedAt: now,
        confirmedAt: now,
      );
      await repository.recordDispenseMovementSucceeded(
        profileId: 'schedule-1',
        activeSessionId: 'session-active',
        slotNumber: 1,
        occurredAt: now.add(const Duration(minutes: 1)),
      );

      await expectLater(
        repository.confirmDispensedSlotNeedsReview(
          profileId: 'schedule-1',
          activeSessionId: 'session-other',
          slotNumber: 1,
          occurredAt: now.add(const Duration(minutes: 2)),
          reason: 'visibly_absent',
        ),
        throwsA(isA<StateError>()),
      );

      final prescriptions = await LocalPrescriptionRepository(
        database,
      ).watchPrescriptions().first;
      expect(
        prescriptions.single,
        isA<Prescription>()
            .having((p) => p.loadedDoses, 'loaded', 1)
            .having((p) => p.reviewDoses, 'review', 0),
      );
    },
  );
}

GuidedCarouselLoadPlan _plan(
  DateTime createdAt, {
  List<CarouselLoadPlanSlotPreview> loadedSlots =
      const <CarouselLoadPlanSlotPreview>[],
  List<CarouselLoadPlanSlotPreview> shortageSlots =
      const <CarouselLoadPlanSlotPreview>[],
}) {
  final slotsByNumber = <int, CarouselLoadPlanSlotPreview>{
    for (final slot in loadedSlots) slot.slotNumber: slot,
    for (final slot in shortageSlots) slot.slotNumber: slot,
  };
  final slots = List<CarouselLoadPlanSlotPreview>.generate(
    14,
    (index) =>
        slotsByNumber[index + 1] ??
        CarouselLoadPlanSlotPreview.empty(
          position: CarouselPosition(index + 1),
        ),
  );
  return GuidedCarouselLoadPlan(
    createdAt: createdAt,
    mode: GuidedCarouselLoadMode.fullReload,
    priorPosition: CarouselPosition.start,
    slots: slots,
    shortages: shortageSlots
        .map((slot) => slot.shortage!)
        .toList(growable: false),
  );
}

CarouselLoadPlanSlotPreview _loadedSlot(
  int slotNumber,
  String bundleKey,
  DateTime scheduledAt,
  List<CarouselDoseBundleMedication> medications,
) {
  return CarouselLoadPlanSlotPreview.loaded(
    position: CarouselPosition(slotNumber),
    bundle: CarouselDoseBundle(
      bundleKey: bundleKey,
      scheduledAt: scheduledAt,
      scheduleIds: medications.map((m) => m.scheduleId).toList(growable: false),
      medications: medications,
    ),
  );
}

CarouselDoseBundleMedication _medication(
  String prescriptionId,
  String scheduleId, {
  DateTime? scheduledAt,
  int doseCount = 1,
}) {
  final now = DateTime.utc(2026, 7, 23, 8);
  return CarouselDoseBundleMedication(
    prescriptionId: prescriptionId,
    prescriptionName: prescriptionId,
    scheduleId: scheduleId,
    scheduledAt: scheduledAt ?? now,
    availableDoses: 1,
    guidedPillIcon: GuidedPillIcon.roundPill,
    doseCount: doseCount,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _seedPrescriptionSchedule(
  DoseyDatabase database, {
  String prescriptionId = 'vitamin-d',
  String scheduleId = 'vitamin-d-morning',
  String profileId = ReminderSchedule.defaultProfileId,
  int hour = 8,
  int availableDoses = 1,
}) async {
  final now = DateTime.utc(2026, 7, 23, hour);
  await LocalPrescriptionRepository(database).upsertPrescription(
    Prescription(
      id: prescriptionId,
      name: prescriptionId,
      pillType: PillType.capsule,
      availableDoses: availableDoses,
      loadedDoses: 0,
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

class _FakeUrgentShortageNotifier implements UrgentShortageNotifier {
  final List<String> sentAlertIds = <String>[];

  @override
  Future<void> showUrgentShortageNotification({
    required String alertId,
    required String medicationLabel,
    required DateTime scheduledAt,
    required int slotNumber,
  }) async {
    sentAlertIds.add(alertId);
  }
}
