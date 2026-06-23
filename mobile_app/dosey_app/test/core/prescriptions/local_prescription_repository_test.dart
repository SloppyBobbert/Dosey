import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
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
