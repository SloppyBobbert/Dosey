import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local settings persist selected device role', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final settings = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    expect(
      await settings.watchDeviceRole().first,
      AppDeviceRole.androidPersonal,
    );

    await settings.setDeviceRole(AppDeviceRole.androidRobot);

    expect(await settings.watchDeviceRole().first, AppDeviceRole.androidRobot);
  });

  test(
    'local dose log persists controller dispense without marking dose taken',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = DriftDoseLogRepository(database);
      final event = DoseLogEvent.controllerDispenseSucceeded(
        doseId: 'morning-dose',
        occurredAt: DateTime.utc(2026, 6, 9, 12),
      );

      await repository.addEvent(event);

      final events = await repository.watchEvents().first;
      expect(events, hasLength(1));
      expect(events.single.kind, DoseLogEventKind.controllerDispenseSucceeded);
      expect(events.single.doseId, 'morning-dose');
      expect(events.single.marksDoseTaken, isFalse);
    },
  );

  test('migration marks existing installs as already onboarded', () async {
    final executor = NativeDatabase.memory(
      setup: (database) {
        database
          ..execute('''
            CREATE TABLE app_settings (
              key TEXT NOT NULL PRIMARY KEY,
              value TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            );
          ''')
          ..execute('PRAGMA user_version = 4;');
      },
    );
    final database = DoseyDatabase(executor);
    addTearDown(database.close);
    final settings = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    expect(await settings.watchOnboardingCompleted().first, isTrue);
  });
}
