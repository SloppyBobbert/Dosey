import 'package:dosey_app/core/backup/local_backup_store.dart';
import 'package:dosey_app/core/demo/demo_data_repository.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final seedTime = DateTime.utc(2040, 1, 2, 8);

  test('reset seeds a complete deterministic fake dose baseline', () async {
    final database = DoseyDatabase.inMemory(isDemo: true);
    addTearDown(database.close);
    final repository = DemoDataRepository(
      database,
      seedTime: seedTime,
      deviceRole: AppDeviceRole.androidRobot,
    );

    await repository.resetAndSeed();

    final settings = await database.select(database.appSettings).get();
    final profiles = await database.select(database.scheduleProfiles).get();
    final prescriptions = await database.select(database.prescriptions).get();
    final schedules = await database.select(database.reminderSchedules).get();
    final sessions = await database.select(database.carouselLoadSessions).get();
    final slots = await database
        .select(database.carouselLoadSlotSnapshots)
        .get();
    final states = await database.select(database.carouselStates).get();

    expect({
      for (final setting in settings) setting.key: setting.value,
    }, containsPair('device_role', AppDeviceRole.androidRobot.storageValue));
    expect({
      for (final setting in settings) setting.key: setting.value,
    }, containsPair('onboarding_completed', 'true'));
    expect(profiles.single.id, DemoDataRepository.profileId);
    expect(profiles.single.name, contains('FAKE'));
    expect(prescriptions.single.id, DemoDataRepository.prescriptionId);
    expect(prescriptions.single.name, contains('FAKE'));
    expect(prescriptions.single.availableDoses, 13);
    expect(prescriptions.single.loadedDoses, 1);
    expect(schedules.single.id, DemoDataRepository.scheduleId);
    expect(schedules.single.profileId, DemoDataRepository.profileId);
    expect(sessions.single.id, DemoDataRepository.loadSessionId);
    expect(sessions.single.status, 'confirmed');
    expect(slots.single.id, DemoDataRepository.loadSlotId);
    expect(slots.single.status, 'loaded');
    expect(
      slots.single.scheduleIdsJson,
      '["${DemoDataRepository.scheduleId}"]',
    );
    expect(states.single.profileId, DemoDataRepository.profileId);
    expect(states.single.activeLoadSessionId, DemoDataRepository.loadSessionId);
    expect(states.single.currentPosition, 0);
  });

  test(
    'reset removes prior demo activity and reproduces the same snapshot',
    () async {
      final database = DoseyDatabase.inMemory(isDemo: true);
      addTearDown(database.close);
      final repository = DemoDataRepository(
        database,
        seedTime: seedTime,
        deviceRole: AppDeviceRole.androidRobot,
      );

      await repository.resetAndSeed();
      final expected = (await LocalBackupStore(database).readSnapshot()).data;
      await database
          .into(database.doseLogEvents)
          .insert(
            DoseLogEventsCompanion.insert(
              id: 'demo:temporary-event',
              kind: 'dose_skipped',
              doseId: 'demo:temporary-dose',
              occurredAt: seedTime.add(const Duration(minutes: 1)),
              marksDoseTaken: false,
            ),
          );

      await repository.resetAndSeed();

      final actual = (await LocalBackupStore(database).readSnapshot()).data;
      expect(actual, equals(expected));
    },
  );

  test('demo reset cannot modify a production database', () async {
    final production = DoseyDatabase.inMemory();
    final demo = DoseyDatabase.inMemory(isDemo: true);
    addTearDown(production.close);
    addTearDown(demo.close);
    await production
        .into(production.prescriptions)
        .insert(
          PrescriptionsCompanion.insert(
            id: 'real-prescription',
            name: 'Existing production data',
            pillType: 'pill',
            availableDoses: const Value(7),
            createdAt: seedTime,
            updatedAt: seedTime,
          ),
        );
    final before = (await LocalBackupStore(production).readSnapshot()).data;

    await DemoDataRepository(
      demo,
      seedTime: seedTime,
      deviceRole: AppDeviceRole.androidRobot,
    ).resetAndSeed();

    final after = (await LocalBackupStore(production).readSnapshot()).data;
    expect(after, equals(before));
    expect(
      () => DemoDataRepository(
        production,
        seedTime: seedTime,
        deviceRole: AppDeviceRole.androidRobot,
      ),
      throwsArgumentError,
    );
  });
}
