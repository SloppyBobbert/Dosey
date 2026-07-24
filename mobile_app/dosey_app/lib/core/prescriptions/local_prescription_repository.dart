import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/audit/local_admin_audit_repository.dart';
import 'package:dosey_app/core/carousel/local_guided_carousel_load_repository.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';

abstract interface class PrescriptionRepository {
  Stream<List<Prescription>> watchPrescriptions();

  Stream<List<PrescriptionRefill>> watchRefillHistory(String prescriptionId);

  Future<void> upsertPrescription(
    Prescription prescription, {
    AdminAuditEvent? auditEvent,
  });

  Future<void> addRefill({
    required String prescriptionId,
    required int doseCount,
    required DateTime occurredAt,
    String? note,
    AdminAuditEvent? auditEvent,
  });

  Future<void> recordTakenDose(
    String prescriptionId, {
    required DateTime occurredAt,
  });

  Future<void> deletePrescription(String id, {AdminAuditEvent? auditEvent});
}

class LocalPrescriptionRepository implements PrescriptionRepository {
  const LocalPrescriptionRepository(this._database);

  final DoseyDatabase _database;

  static const _deferredDeleteKeyPrefix = 'deferred_deleted_prescription:';

  /// Watches the user's locally entered prescriptions in name order.
  @override
  Stream<List<Prescription>> watchPrescriptions() {
    return _database
        .customSelect(
          '''
          SELECT p.*
          FROM prescriptions AS p
          LEFT JOIN app_settings AS s ON s.key = ? || p.id
          WHERE s.key IS NULL
          ORDER BY p.name ASC
          ''',
          variables: [Variable<String>(_deferredDeleteKeyPrefix)],
          readsFrom: {_database.prescriptions, _database.appSettings},
        )
        .watch()
        .map((rows) => rows.map(_fromCustomRow).toList(growable: false));
  }

  @override
  Stream<List<PrescriptionRefill>> watchRefillHistory(String prescriptionId) {
    final query = _database.select(_database.prescriptionRefills)
      ..where((refill) => refill.prescriptionId.equals(prescriptionId))
      ..orderBy([(refill) => OrderingTerm.desc(refill.occurredAt)]);

    return query.watch().map((rows) => rows.map(_refillFromRow).toList());
  }

  /// Saves the user-entered medication name and selected pill graphic type.
  @override
  Future<void> upsertPrescription(
    Prescription prescription, {
    AdminAuditEvent? auditEvent,
  }) {
    _validatePrescription(prescription);

    return _database.transaction(() async {
      await _rejectDeferredDeletedPrescription(prescription.id);
      final existing = await (_database.select(
        _database.prescriptions,
      )..where((row) => row.id.equals(prescription.id))).getSingleOrNull();

      await _database
          .into(_database.prescriptions)
          .insertOnConflictUpdate(
            _companionForUpsert(prescription, existing: existing),
          );
      if (existing != null &&
          (existing.defaultDoseCountPerDose !=
                  prescription.defaultDoseCountPerDose ||
              existing.doseInstructions !=
                  prescription.doseInstructions.trim())) {
        final scheduleRows = await (_database.select(
          _database.reminderSchedules,
        )..where((row) => row.prescriptionId.equals(prescription.id))).get();
        for (final profileId
            in scheduleRows.map((row) => row.profileId).toSet()) {
          await LocalGuidedCarouselLoadRepository.markActiveLoadStaleInDatabase(
            _database,
            profileId: profileId,
            reason: 'prescription_dose_composition_changed',
            occurredAt: prescription.updatedAt,
            details: {'prescriptionId': prescription.id},
          );
        }
      }
      if (auditEvent != null) {
        await LocalAdminAuditRepository.insertEventIntoDatabase(
          _database,
          auditEvent,
        );
      }
    });
  }

  @override
  Future<void> addRefill({
    required String prescriptionId,
    required int doseCount,
    required DateTime occurredAt,
    String? note,
    AdminAuditEvent? auditEvent,
  }) async {
    if (doseCount <= 0) {
      throw ArgumentError.value(
        doseCount,
        'doseCount',
        'Enter one or more doses to add.',
      );
    }

    return _database.transaction(() async {
      await _rejectDeferredDeletedPrescription(prescriptionId);
      final row = await _prescriptionById(prescriptionId);
      final occurredAtUtc = occurredAt.toUtc();
      final remainingAfter = row.remainingDoses + doseCount;
      final trimmedNote = note?.trim();

      await (_database.update(
        _database.prescriptions,
      )..where((prescription) => prescription.id.equals(prescriptionId))).write(
        PrescriptionsCompanion(
          remainingDoses: Value(remainingAfter),
          availableDoses: Value(row.availableDoses + doseCount),
          updatedAt: Value(occurredAtUtc),
        ),
      );
      await _database
          .into(_database.prescriptionRefills)
          .insert(
            PrescriptionRefillsCompanion.insert(
              id: _refillIdFor(
                prescriptionId: prescriptionId,
                doseCount: doseCount,
                occurredAt: occurredAtUtc,
              ),
              prescriptionId: prescriptionId,
              doseDelta: doseCount,
              remainingAfter: remainingAfter,
              occurredAt: occurredAtUtc,
              note: trimmedNote == null || trimmedNote.isEmpty
                  ? const Value.absent()
                  : Value(trimmedNote),
            ),
          );
      if (auditEvent != null) {
        await LocalAdminAuditRepository.insertEventIntoDatabase(
          _database,
          auditEvent,
        );
      }
    });
  }

  @override
  Future<void> recordTakenDose(
    String prescriptionId, {
    required DateTime occurredAt,
  }) async {
    return _database.transaction(() async {
      await _rejectDeferredDeletedPrescription(prescriptionId);
      final row = await _prescriptionById(prescriptionId);
      if (row.remainingDoses == 0) {
        // Do not underflow inventory if the user confirms an old dose after the
        // local count already reached zero.
        return;
      }

      if (row.loadedDoses == 0) {
        await (_database.update(_database.prescriptions)
              ..where((prescription) => prescription.id.equals(prescriptionId)))
            .write(
              PrescriptionsCompanion(
                remainingDoses: Value(row.remainingDoses - 1),
                availableDoses: Value(
                  row.availableDoses > 0 ? row.availableDoses - 1 : 0,
                ),
                updatedAt: Value(occurredAt.toUtc()),
              ),
            );
        return;
      }

      await (_database.update(
        _database.prescriptions,
      )..where((prescription) => prescription.id.equals(prescriptionId))).write(
        PrescriptionsCompanion(
          remainingDoses: Value(row.remainingDoses - 1),
          loadedDoses: Value(row.loadedDoses - 1),
          usedDoses: Value(row.usedDoses + 1),
          updatedAt: Value(occurredAt.toUtc()),
        ),
      );
    });
  }

  @override
  Future<void> deletePrescription(String id, {AdminAuditEvent? auditEvent}) {
    return _database.transaction(() async {
      final scheduleRows = await (_database.select(
        _database.reminderSchedules,
      )..where((schedule) => schedule.prescriptionId.equals(id))).get();
      final affectedProfileIds = scheduleRows
          .map((row) => row.profileId)
          .toSet();
      for (final profileId in affectedProfileIds) {
        await LocalGuidedCarouselLoadRepository.markActiveLoadStaleInDatabase(
          _database,
          profileId: profileId,
          reason: 'prescription_deleted',
          occurredAt: DateTime.now().toUtc(),
          details: {'prescriptionId': id},
        );
      }
      final preservesDeletedPrescriptionForUnload =
          await _hasUnloadDependentActiveLoad(id);
      // Remove dependent local data first so deleted prescriptions do not leave
      // orphaned schedules, carousel slots, or refill history.
      await (_database.delete(
        _database.carouselSlots,
      )..where((slot) => slot.prescriptionId.equals(id))).go();
      await (_database.delete(
        _database.reminderSchedules,
      )..where((schedule) => schedule.prescriptionId.equals(id))).go();
      await (_database.delete(
        _database.prescriptionRefills,
      )..where((refill) => refill.prescriptionId.equals(id))).go();
      if (!preservesDeletedPrescriptionForUnload) {
        await (_database.delete(
          _database.prescriptions,
        )..where((prescription) => prescription.id.equals(id))).go();
      } else {
        await _database.setAppSetting('$_deferredDeleteKeyPrefix$id', 'true');
      }
      if (auditEvent != null) {
        await LocalAdminAuditRepository.insertEventIntoDatabase(
          _database,
          auditEvent,
        );
      }
    });
  }

  Future<bool> _hasUnloadDependentActiveLoad(String prescriptionId) async {
    final states = await (_database.select(
      _database.carouselStates,
    )..where((row) => row.activeLoadSessionId.isNotNull())).get();
    final activeSessionIds = states
        .map((row) => row.activeLoadSessionId)
        .whereType<String>()
        .toSet();
    if (activeSessionIds.isEmpty) {
      return false;
    }
    final snapshots = await (_database.select(
      _database.carouselLoadSlotSnapshots,
    )..where((row) => row.sessionId.isIn(activeSessionIds))).get();
    return snapshots.any(
      (row) => row.prescriptionIdsJson.contains('"$prescriptionId"'),
    );
  }

  static Future<void> cleanupDeferredDeletedPrescriptionsInDatabase(
    DoseyDatabase database,
  ) async {
    final deferredSettings =
        await (database.select(database.appSettings)..where(
              (setting) => setting.key.like('$_deferredDeleteKeyPrefix%'),
            ))
            .get();
    if (deferredSettings.isEmpty) {
      return;
    }
    final activeSessionIds =
        (await (database.select(
              database.carouselStates,
            )..where((row) => row.activeLoadSessionId.isNotNull())).get())
            .map((row) => row.activeLoadSessionId)
            .whereType<String>()
            .toSet();
    final activeSnapshots = activeSessionIds.isEmpty
        ? <CarouselLoadSlotSnapshotRow>[]
        : await (database.select(
            database.carouselLoadSlotSnapshots,
          )..where((row) => row.sessionId.isIn(activeSessionIds))).get();

    for (final setting in deferredSettings) {
      final prescriptionId = setting.key.substring(
        _deferredDeleteKeyPrefix.length,
      );
      final stillReferenced = activeSnapshots.any(
        (row) => row.prescriptionIdsJson.contains('"$prescriptionId"'),
      );
      if (stillReferenced) {
        continue;
      }
      await (database.delete(
        database.prescriptions,
      )..where((prescription) => prescription.id.equals(prescriptionId))).go();
      await database.deleteAppSettings({setting.key});
    }
  }

  Future<void> _rejectDeferredDeletedPrescription(String prescriptionId) async {
    final isDeferredDeleted = await isDeferredDeletedPrescriptionInDatabase(
      _database,
      prescriptionId,
    );
    if (!isDeferredDeleted) {
      return;
    }
    throw StateError(
      'Prescription "$prescriptionId" is pending guided-load cleanup and cannot be edited.',
    );
  }

  static Future<bool> isDeferredDeletedPrescriptionInDatabase(
    DoseyDatabase database,
    String prescriptionId,
  ) async {
    final rows = await database.getAppSettings({
      '$_deferredDeleteKeyPrefix$prescriptionId',
    });
    return rows.isNotEmpty;
  }

  static Prescription _fromCustomRow(QueryRow row) {
    return Prescription(
      id: row.read<String>('id'),
      name: row.read<String>('name'),
      pillType: PillType.fromStorageValue(row.read<String>('pill_type')),
      remainingDoses: row.read<int>('remaining_doses'),
      guidedPillIcon: GuidedPillIcon.fromStorageValue(
        row.read<String>('guided_pill_icon'),
      ),
      availableDoses: row.read<int>('available_doses'),
      loadedDoses: row.read<int>('loaded_doses'),
      usedDoses: row.read<int>('used_doses'),
      reviewDoses: row.read<int>('review_doses'),
      defaultRefillQuantity: row.read<int>('default_refill_quantity'),
      defaultDoseCountPerDose: row.read<int>('default_dose_count_per_dose'),
      doseInstructions: row.read<String>('dose_instructions'),
      refillThreshold: row.read<int>('refill_threshold'),
      createdAt: row.read<DateTime>('created_at').toUtc(),
      updatedAt: row.read<DateTime>('updated_at').toUtc(),
    );
  }

  static PrescriptionsCompanion _companionForUpsert(
    Prescription prescription, {
    required PrescriptionRow? existing,
  }) {
    final preservesExistingGuidedFields =
        existing != null &&
        prescription.usedLegacyRemainingDosesInput &&
        prescription.guidedPillIcon == GuidedPillIcon.roundPill &&
        prescription.loadedDoses == 0 &&
        prescription.usedDoses == 0 &&
        prescription.reviewDoses == 0 &&
        prescription.defaultRefillQuantity == 30 &&
        prescription.defaultDoseCountPerDose == 1 &&
        prescription.doseInstructions.isEmpty;

    final guidedPillIcon = preservesExistingGuidedFields
        ? existing.guidedPillIcon
        : prescription.guidedPillIcon.storageValue;
    final loadedDoses = preservesExistingGuidedFields
        ? existing.loadedDoses
        : prescription.loadedDoses;
    final usedDoses = preservesExistingGuidedFields
        ? existing.usedDoses
        : prescription.usedDoses;
    final reviewDoses = preservesExistingGuidedFields
        ? existing.reviewDoses
        : prescription.reviewDoses;
    final defaultRefillQuantity = preservesExistingGuidedFields
        ? existing.defaultRefillQuantity
        : prescription.defaultRefillQuantity;
    final defaultDoseCountPerDose = preservesExistingGuidedFields
        ? existing.defaultDoseCountPerDose
        : prescription.defaultDoseCountPerDose;
    final doseInstructions = preservesExistingGuidedFields
        ? existing.doseInstructions
        : prescription.doseInstructions.trim();
    final availableDoses = preservesExistingGuidedFields
        ? (prescription.remainingDoses - loadedDoses - reviewDoses).clamp(
            0,
            prescription.remainingDoses,
          )
        : prescription.availableDoses;

    return PrescriptionsCompanion.insert(
      id: prescription.id,
      name: prescription.name.trim(),
      pillType: prescription.pillType.storageValue,
      remainingDoses: Value(prescription.remainingDoses),
      guidedPillIcon: Value(guidedPillIcon),
      availableDoses: Value(availableDoses),
      loadedDoses: Value(loadedDoses),
      usedDoses: Value(usedDoses),
      reviewDoses: Value(reviewDoses),
      defaultRefillQuantity: Value(defaultRefillQuantity),
      defaultDoseCountPerDose: Value(defaultDoseCountPerDose),
      doseInstructions: Value(doseInstructions),
      refillThreshold: Value(prescription.refillThreshold),
      createdAt: prescription.createdAt.toUtc(),
      updatedAt: prescription.updatedAt.toUtc(),
    );
  }

  static PrescriptionRefill _refillFromRow(PrescriptionRefillRow row) {
    return PrescriptionRefill(
      id: row.id,
      prescriptionId: row.prescriptionId,
      doseDelta: row.doseDelta,
      remainingAfter: row.remainingAfter,
      occurredAt: row.occurredAt.toUtc(),
      note: row.note,
    );
  }

  Future<PrescriptionRow> _prescriptionById(String prescriptionId) async {
    final row =
        await (_database.select(_database.prescriptions)
              ..where((prescription) => prescription.id.equals(prescriptionId)))
            .getSingleOrNull();
    if (row == null) {
      throw StateError('Prescription not found: $prescriptionId');
    }
    return row;
  }

  static String _refillIdFor({
    required String prescriptionId,
    required int doseCount,
    required DateTime occurredAt,
  }) {
    return 'refill:$prescriptionId:${occurredAt.toUtc().microsecondsSinceEpoch}:$doseCount';
  }

  static void _validatePrescription(Prescription prescription) {
    if (prescription.name.trim().isEmpty) {
      throw ArgumentError.value(
        prescription.name,
        'name',
        'Enter the medication name from the prescription label.',
      );
    }
    if (prescription.remainingDoses < 0) {
      throw ArgumentError.value(
        prescription.remainingDoses,
        'remainingDoses',
        'Enter zero or more remaining doses.',
      );
    }
    if (prescription.refillThreshold < 0) {
      throw ArgumentError.value(
        prescription.refillThreshold,
        'refillThreshold',
        'Enter zero or more doses for the refill warning.',
      );
    }
    if (prescription.loadedDoses < 0 ||
        prescription.usedDoses < 0 ||
        prescription.reviewDoses < 0) {
      throw ArgumentError('Inventory buckets must be zero or greater.');
    }
    if (prescription.defaultRefillQuantity < 0) {
      throw ArgumentError.value(
        prescription.defaultRefillQuantity,
        'defaultRefillQuantity',
        'Enter zero or more doses for refill guidance.',
      );
    }
    if (prescription.defaultDoseCountPerDose <= 0) {
      throw ArgumentError.value(
        prescription.defaultDoseCountPerDose,
        'defaultDoseCountPerDose',
        'Enter one or more units for display guidance.',
      );
    }
  }
}
