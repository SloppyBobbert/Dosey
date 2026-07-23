import 'dart:convert';

import 'package:dosey_app/core/admin/admin_audit_event_factory.dart';
import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/audit/local_admin_audit_repository.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/notifications/flutter_local_notification_scheduler.dart';
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:drift/drift.dart';
import 'package:dosey_app/core/carousel/carousel_load_session.dart';
import 'package:dosey_app/core/carousel/carousel_position.dart';
import 'package:dosey_app/core/carousel/guided_carousel_load_plan.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';

class LocalGuidedCarouselLoadRepository {
  const LocalGuidedCarouselLoadRepository(
    this._database, {
    this.urgentShortageNotifier,
  });

  final DoseyDatabase _database;
  final UrgentShortageNotifier? urgentShortageNotifier;

  static const _auditFactory = AdminAuditEventFactory();
  static const _systemActor = AdminAuditActorIdentity(
    actorType: AdminAuditActorType.system,
    actorLabel: 'Dosey System',
    actorProviderLabel: 'system',
  );
  static const _sourceDeviceRole = 'androidRobot';

  Future<void> confirmFullLoad({
    required String sessionId,
    required String profileId,
    required GuidedCarouselLoadPlan plan,
    required DateTime startedAt,
    required DateTime confirmedAt,
  }) async {
    _validatePlan(plan, expectedMode: GuidedCarouselLoadMode.fullReload);

    final pendingNotifications = await _database.transaction(() async {
      await _rejectSecondActiveConfirmedSession(
        sessionId: sessionId,
        profileId: profileId,
      );
      final confirmedAtUtc = confirmedAt.toUtc();
      await _insertSession(
        sessionId: sessionId,
        profileId: profileId,
        plan: plan,
        startedAt: startedAt,
        confirmedAtUtc: confirmedAtUtc,
        predecessorSessionId: null,
        positionBefore: plan.priorPosition?.value ?? 0,
        positionAfter: 0,
      );
      await _insertSnapshots(
        sessionId: sessionId,
        plan: plan,
        occurredAt: confirmedAtUtc,
      );
      await _applyInventoryForNewLoadedSlots(plan.slots, confirmedAtUtc);
      await _upsertCarouselState(
        profileId: profileId,
        activeLoadSessionId: sessionId,
        currentPosition: CarouselPosition.start,
        updatedAt: confirmedAtUtc,
      );
      final pendingNotifications = await _persistShortageAlerts(
        profileId: profileId,
        sessionId: sessionId,
        plan: plan,
        occurredAt: confirmedAtUtc,
      );
      await LocalAdminAuditRepository.insertEventIntoDatabase(
        _database,
        _auditFactory.guidedLoadConfirmed(
          actor: _systemActor,
          sourceDeviceRole: _sourceDeviceRole,
          targetId: sessionId,
          summary:
              'Confirmed guided ${plan.mode == GuidedCarouselLoadMode.topOff ? 'top-off' : 'full load'} for $profileId.',
          details: {'profileId': profileId, 'mode': plan.mode.name},
          occurredAt: confirmedAtUtc,
        ),
      );
      return pendingNotifications;
    });
    await _deliverUrgentShortageNotifications(
      pendingNotifications,
      occurredAt: confirmedAt.toUtc(),
    );
  }

  Future<void> confirmTopOff({
    required String sessionId,
    required String profileId,
    required String predecessorSessionId,
    required GuidedCarouselLoadPlan plan,
    required DateTime startedAt,
    required DateTime confirmedAt,
  }) async {
    _validatePlan(plan, expectedMode: GuidedCarouselLoadMode.topOff);

    final pendingNotifications = await _database.transaction(() async {
      await _rejectLateShortageContinuation(
        profileId: profileId,
        sessionId: predecessorSessionId,
        attemptedAt: confirmedAt.toUtc(),
      );
      final activeSession = await _requireActiveSession(profileId);
      if (activeSession.status == CarouselLoadSessionStatus.stale) {
        throw StateError(
          'Active guided load session "$predecessorSessionId" is stale and must be reviewed or reloaded before top-off.',
        );
      }
      if (activeSession.id != predecessorSessionId) {
        throw StateError(
          'Top-off requires active predecessor session "$predecessorSessionId".',
        );
      }

      final confirmedAtUtc = confirmedAt.toUtc();
      await (_database.update(
        _database.carouselLoadSessions,
      )..where((row) => row.id.equals(predecessorSessionId))).write(
        CarouselLoadSessionsCompanion(
          status: const Value('superseded'),
          supersededAt: Value(confirmedAtUtc),
          supersededReason: const Value('top_off_replaced'),
          updatedAt: Value(confirmedAtUtc),
        ),
      );

      await _insertSession(
        sessionId: sessionId,
        profileId: profileId,
        plan: plan,
        startedAt: startedAt,
        confirmedAtUtc: confirmedAtUtc,
        predecessorSessionId: predecessorSessionId,
        positionBefore:
            plan.priorPosition?.value ?? activeSession.currentPosition.value,
        positionAfter:
            plan.priorPosition?.value ?? activeSession.currentPosition.value,
      );
      await _insertSnapshots(
        sessionId: sessionId,
        plan: plan,
        occurredAt: confirmedAtUtc,
      );
      await _applyInventoryForNewLoadedSlots(
        plan.slots.where(
          (slot) => slot.status == GuidedCarouselLoadPlanSlotStatus.loaded,
        ),
        confirmedAtUtc,
      );
      await _upsertCarouselState(
        profileId: profileId,
        activeLoadSessionId: sessionId,
        currentPosition: activeSession.currentPosition,
        updatedAt: confirmedAtUtc,
      );
      await _retireShortageAlertsForSession(
        predecessorSessionId,
        resolvedAt: confirmedAtUtc,
        resolution: 'top_off_replaced',
      );
      final pendingNotifications = await _persistShortageAlerts(
        profileId: profileId,
        sessionId: sessionId,
        plan: plan,
        occurredAt: confirmedAtUtc,
      );
      await LocalAdminAuditRepository.insertEventIntoDatabase(
        _database,
        _auditFactory.guidedLoadConfirmed(
          actor: _systemActor,
          sourceDeviceRole: _sourceDeviceRole,
          targetId: sessionId,
          summary: 'Confirmed guided top-off for $profileId.',
          details: {
            'profileId': profileId,
            'mode': plan.mode.name,
            'predecessorSessionId': predecessorSessionId,
          },
          occurredAt: confirmedAtUtc,
        ),
      );
      return pendingNotifications;
    });
    await _deliverUrgentShortageNotifications(
      pendingNotifications,
      occurredAt: confirmedAt.toUtc(),
    );
  }

  Future<void> confirmPhysicalUnload({
    required String profileId,
    required String activeSessionId,
    required List<String> recoveredScheduleIds,
    List<int> recoveredSlotNumbers = const <int>[],
    required DateTime occurredAt,
  }) async {
    return _database.transaction(() async {
      final activeSession = await _requireActiveSession(profileId);
      if (activeSession.id != activeSessionId) {
        throw StateError(
          'Active load session "$activeSessionId" was not found for profile "$profileId".',
        );
      }
      final occurredAtUtc = occurredAt.toUtc();
      final recovered = recoveredScheduleIds.toSet();
      final recoveredSlots = recoveredSlotNumbers.toSet();
      final useSlotScopedRecovery = recoveredSlots.isNotEmpty;
      final deltasByPrescription = <String, _UnloadInventoryDelta>{};

      final snapshotRows = await (_database.select(
        _database.carouselLoadSlotSnapshots,
      )..where((row) => row.sessionId.equals(activeSessionId))).get();

      for (final snapshot in snapshotRows) {
        final isDispensedResolved =
            snapshot.status == 'dispensed' && snapshot.resolvedAt != null;
        final isNeedsReviewInventoryAlreadyMoved =
            snapshot.status == 'needs_review' && snapshot.movedAt != null;
        if (isDispensedResolved ||
            isNeedsReviewInventoryAlreadyMoved ||
            (snapshot.status != 'loaded' &&
                snapshot.status != 'retained' &&
                snapshot.status != 'dispensed' &&
                snapshot.status != 'needs_review')) {
          continue;
        }
        final scheduleIds =
            (jsonDecode(snapshot.scheduleIdsJson) as List<dynamic>)
                .cast<String>();
        final prescriptionIds =
            (jsonDecode(snapshot.prescriptionIdsJson) as List<dynamic>)
                .cast<String>();
        for (var index = 0; index < scheduleIds.length; index += 1) {
          final scheduleId = scheduleIds[index];
          final prescriptionId = prescriptionIds[index];
          final delta = deltasByPrescription.putIfAbsent(
            prescriptionId,
            () => _UnloadInventoryDelta(),
          );
          delta.loadedDecrease += 1;
          final isRecovered = useSlotScopedRecovery
              ? recoveredSlots.contains(snapshot.slotNumber)
              : recovered.contains(scheduleId);
          if (isRecovered) {
            delta.availableIncrease += 1;
          } else {
            delta.reviewIncrease += 1;
          }
        }
      }

      for (final entry in deltasByPrescription.entries) {
        final row =
            await (_database.select(_database.prescriptions)
                  ..where((prescription) => prescription.id.equals(entry.key)))
                .getSingle();
        await (_database.update(
          _database.prescriptions,
        )..where((prescription) => prescription.id.equals(entry.key))).write(
          PrescriptionsCompanion(
            availableDoses: Value(
              row.availableDoses + entry.value.availableIncrease,
            ),
            loadedDoses: Value(row.loadedDoses - entry.value.loadedDecrease),
            reviewDoses: Value(row.reviewDoses + entry.value.reviewIncrease),
            updatedAt: Value(occurredAtUtc),
          ),
        );
      }

      await (_database.update(
        _database.carouselLoadSessions,
      )..where((row) => row.id.equals(activeSessionId))).write(
        CarouselLoadSessionsCompanion(
          status: const Value('cancelled'),
          updatedAt: Value(occurredAtUtc),
        ),
      );
      await _upsertCarouselState(
        profileId: profileId,
        activeLoadSessionId: null,
        currentPosition: CarouselPosition.start,
        updatedAt: occurredAtUtc,
      );
      await _retireShortageAlertsForSession(
        activeSessionId,
        resolvedAt: occurredAtUtc,
        resolution: 'physical_unload',
      );
      await LocalAdminAuditRepository.insertEventIntoDatabase(
        _database,
        _auditFactory.guidedLoadPhysicallyUnloaded(
          actor: _systemActor,
          sourceDeviceRole: _sourceDeviceRole,
          targetId: activeSessionId,
          summary: 'Physically unloaded guided load for $profileId.',
          details: {
            'profileId': profileId,
            'recoveredScheduleIds': recoveredScheduleIds,
            'recoveredSlotNumbers': recoveredSlotNumbers,
          },
          occurredAt: occurredAtUtc,
        ),
      );
      await LocalPrescriptionRepository.cleanupDeferredDeletedPrescriptionsInDatabase(
        _database,
      );
    });
  }

  Future<void> recordDispenseMovementSucceeded({
    required String profileId,
    required String activeSessionId,
    required int slotNumber,
    required DateTime occurredAt,
  }) async {
    return _database.transaction(() async {
      final activeSession = await _requireActiveSession(profileId);
      if (activeSession.status == CarouselLoadSessionStatus.stale) {
        throw StateError(
          'Active guided load session is stale and cannot dispense.',
        );
      }
      if (activeSession.id != activeSessionId) {
        throw StateError(
          'Active load session "$activeSessionId" was not found for profile "$profileId".',
        );
      }
      final snapshot = await _snapshotRow(activeSessionId, slotNumber);
      if (snapshot.status != 'loaded' && snapshot.status != 'retained') {
        throw StateError('Slot $slotNumber is not ready to dispense.');
      }
      final occurredAtUtc = occurredAt.toUtc();
      await (_database.update(
        _database.carouselLoadSlotSnapshots,
      )..where((row) => row.id.equals(snapshot.id))).write(
        CarouselLoadSlotSnapshotsCompanion(
          status: const Value('dispensed'),
          movedAt: Value(occurredAtUtc),
        ),
      );
      await (_database.update(
        _database.carouselLoadSessions,
      )..where((row) => row.id.equals(activeSessionId))).write(
        CarouselLoadSessionsCompanion(
          positionAfter: Value(slotNumber),
          updatedAt: Value(occurredAtUtc),
        ),
      );
      await _upsertCarouselState(
        profileId: profileId,
        activeLoadSessionId: activeSessionId,
        currentPosition: CarouselPosition(slotNumber),
        updatedAt: occurredAtUtc,
      );
    });
  }

  Future<void> confirmDispensedSlotTaken({
    required String profileId,
    required String activeSessionId,
    required int slotNumber,
    required DateTime occurredAt,
  }) async {
    return _database.transaction(() async {
      final activeSession = await _requireActiveSession(profileId);
      if (activeSession.id != activeSessionId) {
        throw StateError(
          'Active load session "$activeSessionId" was not found for profile "$profileId".',
        );
      }
      final snapshot = await _snapshotRow(activeSessionId, slotNumber);
      if (snapshot.status != 'dispensed' || snapshot.resolvedAt != null) {
        return;
      }
      final prescriptionIds =
          (jsonDecode(snapshot.prescriptionIdsJson) as List<dynamic>)
              .cast<String>();
      await _moveLoadedInventory(
        prescriptionIds: prescriptionIds,
        occurredAt: occurredAt.toUtc(),
        toUsed: true,
      );
      await _decrementRemainingInventory(
        prescriptionIds: prescriptionIds,
        occurredAt: occurredAt.toUtc(),
      );
      await (_database.update(
        _database.carouselLoadSlotSnapshots,
      )..where((row) => row.id.equals(snapshot.id))).write(
        CarouselLoadSlotSnapshotsCompanion(
          resolvedAt: Value(occurredAt.toUtc()),
        ),
      );
    });
  }

  Future<void> confirmDispensedSlotNeedsReview({
    required String profileId,
    required String activeSessionId,
    required int slotNumber,
    required DateTime occurredAt,
    required String reason,
  }) async {
    return _database.transaction(() async {
      final activeSession = await _requireActiveSession(profileId);
      if (activeSession.id != activeSessionId) {
        throw StateError(
          'Active load session "$activeSessionId" was not found for profile "$profileId".',
        );
      }
      final snapshot = await _snapshotRow(activeSessionId, slotNumber);
      if (snapshot.status != 'dispensed' || snapshot.resolvedAt != null) {
        return;
      }
      final prescriptionIds =
          (jsonDecode(snapshot.prescriptionIdsJson) as List<dynamic>)
              .cast<String>();
      await _moveLoadedInventory(
        prescriptionIds: prescriptionIds,
        occurredAt: occurredAt.toUtc(),
        toUsed: false,
      );
      await (_database.update(
        _database.carouselLoadSlotSnapshots,
      )..where((row) => row.id.equals(snapshot.id))).write(
        CarouselLoadSlotSnapshotsCompanion(
          status: const Value('needs_review'),
          resolvedAt: Value(occurredAt.toUtc()),
          reviewReason: Value(reason),
        ),
      );
    });
  }

  Future<void> quarantineSlotForReview({
    required String profileId,
    required String activeSessionId,
    required int slotNumber,
    required DateTime occurredAt,
    required String reason,
  }) async {
    return _database.transaction(() async {
      final activeSession = await _requireActiveSession(profileId);
      if (activeSession.id != activeSessionId) {
        throw StateError(
          'Active load session "$activeSessionId" was not found for profile "$profileId".',
        );
      }
      final snapshot = await _snapshotRow(activeSessionId, slotNumber);
      if (snapshot.resolvedAt != null ||
          (snapshot.status != 'loaded' &&
              snapshot.status != 'retained' &&
              snapshot.status != 'dispensed')) {
        return;
      }
      await (_database.update(
        _database.carouselLoadSlotSnapshots,
      )..where((row) => row.id.equals(snapshot.id))).write(
        CarouselLoadSlotSnapshotsCompanion(
          status: const Value('needs_review'),
          resolvedAt: Value(occurredAt.toUtc()),
          reviewReason: Value(reason),
        ),
      );
    });
  }

  static Future<void> markActiveLoadStaleInDatabase(
    DoseyDatabase database, {
    required String profileId,
    required String reason,
    required DateTime occurredAt,
    required Map<String, Object?> details,
  }) async {
    final state = await (database.select(
      database.carouselStates,
    )..where((row) => row.profileId.equals(profileId))).getSingleOrNull();
    final sessionId = state?.activeLoadSessionId;
    if (sessionId == null) {
      return;
    }
    final session = await (database.select(
      database.carouselLoadSessions,
    )..where((row) => row.id.equals(sessionId))).getSingleOrNull();
    if (session == null ||
        session.status != CarouselLoadSessionStatus.confirmed.name) {
      return;
    }
    final occurredAtUtc = occurredAt.toUtc();
    await (database.update(
      database.carouselLoadSessions,
    )..where((row) => row.id.equals(sessionId))).write(
      CarouselLoadSessionsCompanion(
        status: const Value('stale'),
        staleAt: Value(occurredAtUtc),
        staleReason: Value(reason),
        updatedAt: Value(occurredAtUtc),
      ),
    );
    await LocalAdminAuditRepository.insertEventIntoDatabase(
      database,
      _auditFactory.guidedLoadMarkedStale(
        actor: _systemActor,
        sourceDeviceRole: _sourceDeviceRole,
        targetId: sessionId,
        summary: 'Marked guided load stale for $profileId.',
        details: {'profileId': profileId, 'reason': reason, ...details},
        occurredAt: occurredAtUtc,
      ),
    );
  }

  Future<CarouselLoadSession?> readActiveLoad(String profileId) async {
    final state = await (_database.select(
      _database.carouselStates,
    )..where((row) => row.profileId.equals(profileId))).getSingleOrNull();
    final sessionId = state?.activeLoadSessionId;
    if (sessionId == null) {
      return null;
    }
    final session = await readSession(sessionId);
    if (session == null) {
      return null;
    }
    return CarouselLoadSession(
      id: session.id,
      mode: session.mode,
      status: session.status,
      predecessorSessionId: session.predecessorSessionId,
      startedAt: session.startedAt,
      updatedAt: session.updatedAt,
      currentPosition: CarouselPosition(state!.currentPosition),
      slots: session.slots,
    );
  }

  Stream<CarouselLoadSession?> watchActiveLoad(String profileId) {
    return _database
        .customSelect(
          '''
          SELECT
            state.profile_id AS profile_id,
            state.active_load_session_id AS active_load_session_id,
            state.current_position AS current_position,
            session.id AS session_id,
            session.mode AS mode,
            session.status AS status,
            session.predecessor_session_id AS predecessor_session_id,
            session.started_at AS started_at,
            session.updated_at AS updated_at
          FROM carousel_states AS state
          LEFT JOIN carousel_load_sessions AS session
            ON session.id = state.active_load_session_id
          WHERE state.profile_id = ?
          ''',
          variables: [Variable<String>(profileId)],
          readsFrom: {_database.carouselStates, _database.carouselLoadSessions},
        )
        .watchSingleOrNull()
        .asyncMap((row) async {
          final sessionId = row?.read<String?>('active_load_session_id');
          if (sessionId == null) {
            return null;
          }
          return readActiveLoad(profileId);
        });
  }

  Stream<List<MedicationShortageAlertRow>> watchActiveShortageAlerts(
    String profileId,
  ) {
    final query = _database.select(_database.medicationShortageAlerts)
      ..where(
        (row) =>
            row.profileId.equals(profileId) &
            row.status.isIn(const <String>['active', 'past_due']),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.slotNumber)]);
    return query.watch();
  }

  Stream<List<MedicationShortageAlertRow>> watchAllActiveShortageAlerts() {
    final query = _database.select(_database.medicationShortageAlerts)
      ..where((row) => row.status.isIn(const <String>['active', 'past_due']))
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);
    return query.watch();
  }

  Future<void> recognizeShortageAlert(
    String alertId, {
    required DateTime recognizedAt,
  }) async {
    final recognizedAtUtc = recognizedAt.toUtc();
    await _database.transaction(() async {
      final alert = await (_database.select(
        _database.medicationShortageAlerts,
      )..where((row) => row.id.equals(alertId))).getSingle();
      final groupIds = await _alertGroupIds(alert);
      await (_database.update(
        _database.medicationShortageAlerts,
      )..where((row) => row.id.isIn(groupIds))).write(
        MedicationShortageAlertsCompanion(
          recognizedAt: Value(recognizedAtUtc),
          updatedAt: Value(recognizedAtUtc),
        ),
      );
      await LocalAdminAuditRepository.insertEventIntoDatabase(
        _database,
        _auditFactory.guidedLoadShortageRecognized(
          actor: _systemActor,
          sourceDeviceRole: _sourceDeviceRole,
          targetId: alertId,
          summary: 'Recognized guided shortage $alertId.',
          occurredAt: recognizedAtUtc,
        ),
      );
    });
  }

  Future<void> resolveShortageAlert(
    String alertId, {
    required DateTime resolvedAt,
    required String resolution,
  }) async {
    final resolvedAtUtc = resolvedAt.toUtc();
    final alert = await (_database.select(
      _database.medicationShortageAlerts,
    )..where((row) => row.id.equals(alertId))).getSingle();
    final groupIds = await _alertGroupIds(alert);
    await (_database.update(
      _database.medicationShortageAlerts,
    )..where((row) => row.id.isIn(groupIds))).write(
      MedicationShortageAlertsCompanion(
        status: const Value('resolved'),
        resolvedAt: Value(resolvedAtUtc),
        resolution: Value(resolution),
        updatedAt: Value(resolvedAtUtc),
      ),
    );
    await LocalAdminAuditRepository.insertEventIntoDatabase(
      _database,
      _auditFactory.guidedLoadShortageResolved(
        actor: _systemActor,
        sourceDeviceRole: _sourceDeviceRole,
        targetId: alertId,
        summary: 'Resolved guided shortage $alertId.',
        details: {'resolution': resolution},
        occurredAt: resolvedAtUtc,
      ),
    );
  }

  Future<CarouselLoadSession?> readSession(String sessionId) async {
    final sessionRow = await (_database.select(
      _database.carouselLoadSessions,
    )..where((session) => session.id.equals(sessionId))).getSingleOrNull();
    if (sessionRow == null) {
      return null;
    }

    final snapshotRows =
        await (_database.select(_database.carouselLoadSlotSnapshots)
              ..where((snapshot) => snapshot.sessionId.equals(sessionId))
              ..orderBy([(snapshot) => OrderingTerm.asc(snapshot.slotNumber)]))
            .get();

    return CarouselLoadSession(
      id: sessionRow.id,
      mode: _domainMode(sessionRow.mode),
      status: CarouselLoadSessionStatus.values.byName(sessionRow.status),
      predecessorSessionId: sessionRow.predecessorSessionId,
      startedAt: sessionRow.startedAt?.toUtc() ?? sessionRow.createdAt.toUtc(),
      updatedAt: sessionRow.updatedAt.toUtc(),
      currentPosition: CarouselPosition(sessionRow.positionAfter),
      slots: snapshotRows.map(_snapshotFromRow).toList(growable: false),
    );
  }

  Future<CarouselLoadSession> _requireActiveSession(String profileId) async {
    final activeSession = await readActiveLoad(profileId);
    if (activeSession == null) {
      throw StateError(
        'No active guided carousel load session exists for profile "$profileId".',
      );
    }
    return activeSession;
  }

  Future<void> _insertSession({
    required String sessionId,
    required String profileId,
    required GuidedCarouselLoadPlan plan,
    required DateTime startedAt,
    required DateTime confirmedAtUtc,
    required String? predecessorSessionId,
    required int positionBefore,
    required int positionAfter,
  }) async {
    await _database
        .into(_database.carouselLoadSessions)
        .insert(
          CarouselLoadSessionsCompanion.insert(
            id: sessionId,
            profileId: profileId,
            mode: _storageMode(plan.mode),
            status: CarouselLoadSessionStatus.confirmed.name,
            predecessorSessionId: Value(predecessorSessionId),
            planCreatedAt: Value(plan.createdAt.toUtc()),
            startedAt: Value(startedAt.toUtc()),
            confirmedAt: Value(confirmedAtUtc),
            positionBefore: positionBefore,
            positionAfter: positionAfter,
            createdAt: plan.createdAt.toUtc(),
            updatedAt: confirmedAtUtc,
          ),
        );
  }

  Future<void> _insertSnapshots({
    required String sessionId,
    required GuidedCarouselLoadPlan plan,
    required DateTime occurredAt,
  }) async {
    for (final slot in plan.slots) {
      await _database
          .into(_database.carouselLoadSlotSnapshots)
          .insert(
            CarouselLoadSlotSnapshotsCompanion.insert(
              id: '$sessionId:${slot.slotNumber}',
              sessionId: sessionId,
              slotNumber: slot.slotNumber,
              status: _snapshotStatus(slot).name,
              scheduledAt: Value(
                (slot.bundle?.scheduledAt ?? slot.shortage?.scheduledAt)
                    ?.toUtc(),
              ),
              bundleKey: Value(slot.bundleKey),
              scheduleIdsJson: jsonEncode(_scheduleIds(slot)),
              prescriptionIdsJson: jsonEncode(_prescriptionIds(slot)),
              prescriptionNamesJson: jsonEncode(_prescriptionNames(slot)),
              pillIconsJson: jsonEncode(<String>[]),
              doseInstructionsJson: jsonEncode(<String>[]),
              createdAt: occurredAt,
            ),
          );
    }
  }

  Future<CarouselLoadSlotSnapshotRow> _snapshotRow(
    String sessionId,
    int slotNumber,
  ) {
    return (_database.select(_database.carouselLoadSlotSnapshots)
          ..where(
            (row) =>
                row.sessionId.equals(sessionId) &
                row.slotNumber.equals(slotNumber),
          )
          ..limit(1))
        .getSingle();
  }

  Future<List<_PendingUrgentShortageNotification>> _persistShortageAlerts({
    required String profileId,
    required String sessionId,
    required GuidedCarouselLoadPlan plan,
    required DateTime occurredAt,
  }) async {
    final pendingNotifications = <_PendingUrgentShortageNotification>[];
    for (final shortage in plan.shortages) {
      final scheduleIds = shortage.scheduleIds;
      final schedules = await (_database.select(
        _database.reminderSchedules,
      )..where((row) => row.id.isIn(scheduleIds))).get();
      final prescriptionIds = schedules
          .map((schedule) => schedule.prescriptionId)
          .whereType<String>()
          .toList(growable: false);
      final prescriptions = prescriptionIds.isEmpty
          ? <PrescriptionRow>[]
          : await (_database.select(
              _database.prescriptions,
            )..where((row) => row.id.isIn(prescriptionIds))).get();
      final prescriptionNames = prescriptions
          .map((row) => row.name)
          .toList(growable: false);
      final effectivePrescriptionNames = prescriptionNames.isEmpty
          ? scheduleIds.toList(growable: false)
          : prescriptionNames;
      final medicationLabel = effectivePrescriptionNames.join(', ');
      for (
        var slotNumber = shortage.slotNumber;
        slotNumber <= 14;
        slotNumber += 1
      ) {
        final alertId = 'shortage:$sessionId:$slotNumber';
        if (slotNumber == shortage.slotNumber &&
            urgentShortageNotifier != null) {
          pendingNotifications.add(
            _PendingUrgentShortageNotification(
              alertId: alertId,
              medicationLabel: medicationLabel,
              scheduledAt: shortage.scheduledAt,
              slotNumber: slotNumber,
            ),
          );
        }

        await _database
            .into(_database.medicationShortageAlerts)
            .insert(
              MedicationShortageAlertsCompanion.insert(
                id: alertId,
                profileId: profileId,
                loadSessionId: Value(sessionId),
                slotNumber: slotNumber,
                bundleKey: shortage.bundleKey,
                scheduledAt: shortage.scheduledAt.toUtc(),
                prescriptionIdsJson: jsonEncode(prescriptionIds),
                prescriptionNamesJson: jsonEncode(effectivePrescriptionNames),
                status: 'active',
                intendedAudience: const Value('household'),
                localDeliveryState: 'pending',
                localNotificationSentAt: const Value.absent(),
                remoteDeliveryState: const Value('not_configured'),
                createdAt: occurredAt,
                updatedAt: occurredAt,
              ),
            );
        await LocalAdminAuditRepository.insertEventIntoDatabase(
          _database,
          _auditFactory.guidedLoadShortageCreated(
            actor: _systemActor,
            sourceDeviceRole: _sourceDeviceRole,
            targetId: alertId,
            summary:
                'Created urgent guided shortage alert for slot $slotNumber.',
            details: {
              'profileId': profileId,
              'slotNumber': slotNumber,
              'scheduledAt': shortage.scheduledAt.toIso8601String(),
              'prescriptionIds': prescriptionIds,
              'prescriptionNames': effectivePrescriptionNames,
              'intendedAudience': 'household',
              'localDeliveryState': 'pending',
              'remoteDeliveryState': 'not_configured',
            },
            occurredAt: occurredAt,
          ),
        );
      }
    }
    return pendingNotifications;
  }

  Future<void> _deliverUrgentShortageNotifications(
    List<_PendingUrgentShortageNotification> notifications, {
    required DateTime occurredAt,
  }) async {
    for (final notification in notifications) {
      var localDeliveryState = 'sent';
      DateTime? localNotificationSentAt = occurredAt;
      try {
        await urgentShortageNotifier!.showUrgentShortageNotification(
          alertId: notification.alertId,
          medicationLabel: notification.medicationLabel,
          scheduledAt: notification.scheduledAt,
          slotNumber: notification.slotNumber,
        );
      } catch (_) {
        localDeliveryState = 'failed';
        localNotificationSentAt = null;
      }
      await (_database.update(
        _database.medicationShortageAlerts,
      )..where((row) => row.id.equals(notification.alertId))).write(
        MedicationShortageAlertsCompanion(
          localDeliveryState: Value(localDeliveryState),
          localNotificationSentAt: Value(localNotificationSentAt),
          updatedAt: Value(occurredAt),
        ),
      );
    }
  }

  Future<void> _rejectLateShortageContinuation({
    required String profileId,
    required String sessionId,
    required DateTime attemptedAt,
  }) async {
    final blockingAlerts =
        await (_database.select(_database.medicationShortageAlerts)..where(
              (row) =>
                  row.loadSessionId.equals(sessionId) &
                  row.status.isIn(const <String>['active', 'past_due']) &
                  row.scheduledAt.isSmallerOrEqualValue(attemptedAt) &
                  row.bundleKey.contains('|'),
            ))
            .get();
    if (blockingAlerts.isEmpty) {
      return;
    }
    final blockingIds = blockingAlerts
        .map((alert) => alert.id)
        .toList(growable: false);
    await (_database.update(
      _database.medicationShortageAlerts,
    )..where((row) => row.id.isIn(blockingIds))).write(
      MedicationShortageAlertsCompanion(
        status: const Value('past_due'),
        updatedAt: Value(attemptedAt),
      ),
    );
    for (final alert in blockingAlerts) {
      if (alert.status != 'past_due') {
        await (_database.update(
          _database.medicationShortageAlerts,
        )..where((row) => row.id.equals(alert.id))).write(
          MedicationShortageAlertsCompanion(updatedAt: Value(attemptedAt)),
        );
        await LocalAdminAuditRepository.insertEventIntoDatabase(
          _database,
          _auditFactory.guidedLoadShortagePastDue(
            actor: _systemActor,
            sourceDeviceRole: _sourceDeviceRole,
            targetId: alert.id,
            summary: 'Marked shortage alert ${alert.id} past due.',
            occurredAt: attemptedAt,
          ),
        );
      }
      for (final doseId in _doseIdsForAlert(alert)) {
        final existing =
            await (_database.select(_database.doseLogEvents)
                  ..where(
                    (row) =>
                        row.doseId.equals(doseId) &
                        row.kind.equals(DoseLogEventKind.doseMissed.name),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (existing != null) {
          continue;
        }
        await _database
            .into(_database.doseLogEvents)
            .insert(
              DoseLogEventsCompanion.insert(
                id: 'doseMissed:$doseId:${attemptedAt.microsecondsSinceEpoch}',
                kind: DoseLogEventKind.doseMissed.name,
                doseId: doseId,
                occurredAt: attemptedAt,
                marksDoseTaken: false,
              ),
            );
      }
    }
    throw StateError(
      'Shortage occurrence time has passed and guided loading must be reviewed instead of continued.',
    );
  }

  Future<void> _moveLoadedInventory({
    required List<String> prescriptionIds,
    required DateTime occurredAt,
    required bool toUsed,
  }) async {
    final counts = <String, int>{};
    for (final prescriptionId in prescriptionIds) {
      counts.update(prescriptionId, (value) => value + 1, ifAbsent: () => 1);
    }
    for (final entry in counts.entries) {
      final row =
          await (_database.select(_database.prescriptions)
                ..where((prescription) => prescription.id.equals(entry.key)))
              .getSingle();
      await (_database.update(
        _database.prescriptions,
      )..where((prescription) => prescription.id.equals(entry.key))).write(
        PrescriptionsCompanion(
          loadedDoses: Value(row.loadedDoses - entry.value),
          usedDoses: toUsed
              ? Value(row.usedDoses + entry.value)
              : const Value.absent(),
          reviewDoses: toUsed
              ? const Value.absent()
              : Value(row.reviewDoses + entry.value),
          updatedAt: Value(occurredAt),
        ),
      );
    }
  }

  Future<void> _decrementRemainingInventory({
    required List<String> prescriptionIds,
    required DateTime occurredAt,
  }) async {
    final counts = <String, int>{};
    for (final prescriptionId in prescriptionIds) {
      counts.update(prescriptionId, (value) => value + 1, ifAbsent: () => 1);
    }
    for (final entry in counts.entries) {
      final row =
          await (_database.select(_database.prescriptions)
                ..where((prescription) => prescription.id.equals(entry.key)))
              .getSingle();
      await (_database.update(
        _database.prescriptions,
      )..where((prescription) => prescription.id.equals(entry.key))).write(
        PrescriptionsCompanion(
          remainingDoses: Value(row.remainingDoses - entry.value),
          updatedAt: Value(occurredAt),
        ),
      );
    }
  }

  Future<List<String>> _alertGroupIds(MedicationShortageAlertRow alert) async {
    final group =
        await (_database.select(_database.medicationShortageAlerts)..where(
              (row) =>
                  row.loadSessionId.equals(alert.loadSessionId!) &
                  row.bundleKey.equals(alert.bundleKey) &
                  row.status.isIn(const <String>[
                    'active',
                    'resolved',
                    'past_due',
                  ]),
            ))
            .get();
    return group.map((row) => row.id).toList(growable: false);
  }

  Future<void> _retireShortageAlertsForSession(
    String sessionId, {
    required DateTime resolvedAt,
    required String resolution,
  }) async {
    final alerts =
        await (_database.select(_database.medicationShortageAlerts)..where(
              (row) =>
                  row.loadSessionId.equals(sessionId) &
                  row.status.isIn(const <String>['active', 'past_due']),
            ))
            .get();
    if (alerts.isEmpty) {
      return;
    }
    await (_database.update(_database.medicationShortageAlerts)..where(
          (row) =>
              row.loadSessionId.equals(sessionId) &
              row.status.isIn(const <String>['active', 'past_due']),
        ))
        .write(
          MedicationShortageAlertsCompanion(
            status: const Value('resolved'),
            resolvedAt: Value(resolvedAt),
            resolution: Value(resolution),
            updatedAt: Value(resolvedAt),
          ),
        );
  }

  List<String> _doseIdsForAlert(MedicationShortageAlertRow alert) {
    final separatorIndex = alert.bundleKey.indexOf('|');
    if (separatorIndex <= 0 || separatorIndex >= alert.bundleKey.length - 1) {
      return <String>['shortage:${alert.id}'];
    }
    final scheduledDate = alert.bundleKey
        .substring(0, separatorIndex)
        .split('T')
        .first;
    final scheduleIds = alert.bundleKey
        .substring(separatorIndex + 1)
        .split(',');
    return scheduleIds
        .where((scheduleId) => scheduleId.trim().isNotEmpty)
        .map((scheduleId) => '$scheduleId:$scheduledDate')
        .toList(growable: false);
  }

  Future<void> _applyInventoryForNewLoadedSlots(
    Iterable<CarouselLoadPlanSlotPreview> slots,
    DateTime occurredAt,
  ) async {
    final inventoryDeltas = <String, _InventoryDelta>{};
    for (final slot in slots) {
      final bundle = slot.bundle;
      if (bundle == null) {
        continue;
      }
      for (final medication in bundle.medications) {
        final delta = inventoryDeltas.putIfAbsent(
          medication.prescriptionId,
          () => _InventoryDelta(),
        );
        delta.availableDecrease += 1;
        delta.loadedIncrease += 1;
      }
    }
    for (final entry in inventoryDeltas.entries) {
      final row =
          await (_database.select(_database.prescriptions)
                ..where((prescription) => prescription.id.equals(entry.key)))
              .getSingle();
      await (_database.update(
        _database.prescriptions,
      )..where((prescription) => prescription.id.equals(entry.key))).write(
        PrescriptionsCompanion(
          availableDoses: Value(
            row.availableDoses - entry.value.availableDecrease,
          ),
          loadedDoses: Value(row.loadedDoses + entry.value.loadedIncrease),
          updatedAt: Value(occurredAt),
        ),
      );
    }
  }

  Future<void> _upsertCarouselState({
    required String profileId,
    required String? activeLoadSessionId,
    required CarouselPosition currentPosition,
    required DateTime updatedAt,
  }) {
    return _database
        .into(_database.carouselStates)
        .insertOnConflictUpdate(
          CarouselStatesCompanion(
            profileId: Value(profileId),
            activeLoadSessionId: Value(activeLoadSessionId),
            currentPosition: Value(currentPosition.value),
            updatedAt: Value(updatedAt),
          ),
        );
  }

  Future<void> _rejectSecondActiveConfirmedSession({
    required String sessionId,
    required String profileId,
  }) async {
    final state =
        await (_database.select(_database.carouselStates)
              ..where((row) => row.profileId.equals(profileId))
              ..limit(1))
            .getSingleOrNull();
    final existingSessionId = state?.activeLoadSessionId;
    if (existingSessionId == null || existingSessionId == sessionId) {
      return;
    }
    throw StateError(
      'A guided carousel load must be physically unloaded before starting a new full reload for profile "$profileId".',
    );
  }

  static void _validatePlan(
    GuidedCarouselLoadPlan plan, {
    required GuidedCarouselLoadMode expectedMode,
  }) {
    if (expectedMode == GuidedCarouselLoadMode.topOff && !plan.isValid) {
      throw ArgumentError('Top-off plan must be valid before confirmation.');
    }
    if (plan.mode != expectedMode) {
      throw ArgumentError('Expected ${expectedMode.name} plan.');
    }
    if (plan.slots.length != 14) {
      throw ArgumentError.value(
        plan.slots.length,
        'plan.slots',
        'Expected 14 slots.',
      );
    }
  }

  static CarouselLoadSlotStatus _snapshotStatus(
    CarouselLoadPlanSlotPreview slot,
  ) {
    return switch (slot.status) {
      GuidedCarouselLoadPlanSlotStatus.loaded => CarouselLoadSlotStatus.loaded,
      GuidedCarouselLoadPlanSlotStatus.retained =>
        CarouselLoadSlotStatus.retained,
      GuidedCarouselLoadPlanSlotStatus.shortage =>
        CarouselLoadSlotStatus.shortage,
      GuidedCarouselLoadPlanSlotStatus.empty => CarouselLoadSlotStatus.empty,
    };
  }

  static List<String> _prescriptionIds(CarouselLoadPlanSlotPreview slot) {
    if (slot.bundle != null) {
      return slot.bundle!.medications
          .map((medication) => medication.prescriptionId)
          .toList(growable: false);
    }
    return slot.prescriptionIds;
  }

  static List<String> _scheduleIds(CarouselLoadPlanSlotPreview slot) {
    if (slot.bundle != null) {
      return slot.bundle!.medications
          .map((medication) => medication.scheduleId)
          .toList(growable: false);
    }
    return slot.scheduleIds;
  }

  static List<String> _prescriptionNames(CarouselLoadPlanSlotPreview slot) {
    return slot.bundle?.medications
            .map((medication) => medication.prescriptionName)
            .toList(growable: false) ??
        const <String>[];
  }

  static String _storageMode(GuidedCarouselLoadMode mode) {
    return switch (mode) {
      GuidedCarouselLoadMode.fullReload => 'full_load',
      GuidedCarouselLoadMode.topOff => 'top_off',
    };
  }

  static GuidedCarouselLoadMode _domainMode(String mode) {
    return mode == 'top_off'
        ? GuidedCarouselLoadMode.topOff
        : GuidedCarouselLoadMode.fullReload;
  }

  static CarouselLoadSlotSnapshot _snapshotFromRow(
    CarouselLoadSlotSnapshotRow row,
  ) {
    final statusName = switch (row.status) {
      'needs_review' => 'needsReview',
      _ => row.status,
    };
    return CarouselLoadSlotSnapshot(
      position: CarouselPosition(row.slotNumber),
      status: CarouselLoadSlotStatus.values.byName(statusName),
      bundleKey: row.bundleKey,
      scheduleIds:
          (jsonDecode(row.scheduleIdsJson) as List<dynamic>? ??
                  const <dynamic>[])
              .cast<String>(),
      prescriptionIds:
          (jsonDecode(row.prescriptionIdsJson) as List<dynamic>? ??
                  const <dynamic>[])
              .cast<String>(),
      scheduledAt: row.scheduledAt?.toUtc(),
      updatedAt: row.createdAt.toUtc(),
    );
  }
}

class _InventoryDelta {
  int availableDecrease = 0;
  int loadedIncrease = 0;
}

class _PendingUrgentShortageNotification {
  const _PendingUrgentShortageNotification({
    required this.alertId,
    required this.medicationLabel,
    required this.scheduledAt,
    required this.slotNumber,
  });

  final String alertId;
  final String medicationLabel;
  final DateTime scheduledAt;
  final int slotNumber;
}

class _UnloadInventoryDelta {
  int availableIncrease = 0;
  int loadedDecrease = 0;
  int reviewIncrease = 0;
}
