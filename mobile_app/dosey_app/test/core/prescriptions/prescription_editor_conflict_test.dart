import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final refill in [false, true]) {
    test(
      'stale editor rejects ${refill ? 'refill' : 'Taken'} inventory',
      () async {
        final db = DoseyDatabase.inMemory();
        addTearDown(db.close);
        final repository = LocalPrescriptionRepository(db);
        final now = DateTime.utc(2026, 9, 15);
        final original = Prescription(
          id: 'fictional',
          name: 'Fictional',
          pillType: PillType.pill,
          availableDoses: 10,
          createdAt: now,
          updatedAt: now,
        );
        await repository.upsertPrescription(original);
        final snapshot = (await repository.watchPrescriptions().first).single;
        if (refill) {
          await repository.addRefill(
            prescriptionId: original.id,
            doseCount: 2,
            occurredAt: now,
          );
        } else {
          await repository.recordTakenDose(original.id, occurredAt: now);
        }
        await expectLater(
          repository.upsertPrescription(
            snapshot.copyWith(name: 'Changed'),
            expectedState: snapshot,
          ),
          throwsStateError,
        );
        final saved = (await repository.watchPrescriptions().first).single;
        expect(saved.name, 'Fictional');
        expect(saved.remainingDoses, refill ? 12 : 9);
        await repository.upsertPrescription(
          saved.copyWith(name: 'Reviewed'),
          expectedState: saved,
        );
        expect(
          (await repository.watchPrescriptions().first).single.name,
          'Reviewed',
        );
        await repository.deletePrescription(saved.id);
        await expectLater(
          repository.upsertPrescription(saved, expectedState: saved),
          throwsStateError,
        );
        expect(await repository.watchPrescriptions().first, isEmpty);
      },
    );
  }
}
