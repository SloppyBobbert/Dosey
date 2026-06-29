import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';

abstract interface class PrescriptionRepository {
  Stream<List<Prescription>> watchPrescriptions();

  Future<void> upsertPrescription(Prescription prescription);

  Future<void> deletePrescription(String id);
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

  /// Saves the user-entered medication name and selected pill graphic type.
  @override
  Future<void> upsertPrescription(Prescription prescription) {
    _validatePrescription(prescription);

    return _database
        .into(_database.prescriptions)
        .insertOnConflictUpdate(
          PrescriptionsCompanion.insert(
            id: prescription.id,
            name: prescription.name.trim(),
            pillType: prescription.pillType.storageValue,
            createdAt: prescription.createdAt.toUtc(),
            updatedAt: prescription.updatedAt.toUtc(),
          ),
        );
  }

  @override
  Future<void> deletePrescription(String id) {
    return _database.transaction(() async {
      await (_database.delete(
        _database.carouselSlots,
      )..where((slot) => slot.prescriptionId.equals(id))).go();
      await (_database.delete(
        _database.reminderSchedules,
      )..where((schedule) => schedule.prescriptionId.equals(id))).go();
      await (_database.delete(
        _database.prescriptions,
      )..where((prescription) => prescription.id.equals(id))).go();
    });
  }

  static Prescription _fromRow(PrescriptionRow row) {
    return Prescription(
      id: row.id,
      name: row.name,
      pillType: PillType.fromStorageValue(row.pillType),
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }

  static void _validatePrescription(Prescription prescription) {
    if (prescription.name.trim().isEmpty) {
      throw ArgumentError.value(
        prescription.name,
        'name',
        'Enter the medication name from the prescription label.',
      );
    }
  }
}
