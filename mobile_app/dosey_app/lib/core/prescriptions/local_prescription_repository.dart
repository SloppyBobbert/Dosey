import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/audit/local_admin_audit_repository.dart';
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

  /// Watches the user's locally entered prescriptions in name order.
  @override
  Stream<List<Prescription>> watchPrescriptions() {
    final query = _database.select(_database.prescriptions)
      ..orderBy([(prescription) => OrderingTerm.asc(prescription.name)]);

    return query.watch().map((rows) => rows.map(_fromRow).toList());
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
      await _database
          .into(_database.prescriptions)
          .insertOnConflictUpdate(
            PrescriptionsCompanion.insert(
              id: prescription.id,
              name: prescription.name.trim(),
              pillType: prescription.pillType.storageValue,
              remainingDoses: Value(prescription.remainingDoses),
              refillThreshold: Value(prescription.refillThreshold),
              createdAt: prescription.createdAt.toUtc(),
              updatedAt: prescription.updatedAt.toUtc(),
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
      final row = await _prescriptionById(prescriptionId);
      final occurredAtUtc = occurredAt.toUtc();
      final remainingAfter = row.remainingDoses + doseCount;
      final trimmedNote = note?.trim();

      await (_database.update(
        _database.prescriptions,
      )..where((prescription) => prescription.id.equals(prescriptionId))).write(
        PrescriptionsCompanion(
          remainingDoses: Value(remainingAfter),
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
      final row = await _prescriptionById(prescriptionId);
      if (row.remainingDoses == 0) {
        // Do not underflow inventory if the user confirms an old dose after the
        // local count already reached zero.
        return;
      }

      await (_database.update(
        _database.prescriptions,
      )..where((prescription) => prescription.id.equals(prescriptionId))).write(
        PrescriptionsCompanion(
          remainingDoses: Value(row.remainingDoses - 1),
          updatedAt: Value(occurredAt.toUtc()),
        ),
      );
    });
  }

  @override
  Future<void> deletePrescription(String id, {AdminAuditEvent? auditEvent}) {
    return _database.transaction(() async {
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
      await (_database.delete(
        _database.prescriptions,
      )..where((prescription) => prescription.id.equals(id))).go();
      if (auditEvent != null) {
        await LocalAdminAuditRepository.insertEventIntoDatabase(
          _database,
          auditEvent,
        );
      }
    });
  }

  static Prescription _fromRow(PrescriptionRow row) {
    return Prescription(
      id: row.id,
      name: row.name,
      pillType: PillType.fromStorageValue(row.pillType),
      remainingDoses: row.remainingDoses,
      refillThreshold: row.refillThreshold,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
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
  }
}
