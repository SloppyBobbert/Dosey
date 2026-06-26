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

  test(
    'local dose log persists skipped and missed without marking taken',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = DriftDoseLogRepository(database);

      await repository.addEvent(
        DoseLogEvent.doseSkipped(
          doseId: 'morning-dose',
          occurredAt: DateTime.utc(2026, 6, 9, 12),
        ),
      );
      await repository.addEvent(
        DoseLogEvent.doseMissed(
          doseId: 'evening-dose',
          occurredAt: DateTime.utc(2026, 6, 9, 18),
        ),
      );

      final events = await repository.watchEvents().first;
      expect(events, hasLength(2));
      expect(events.first.kind, DoseLogEventKind.doseMissed);
      expect(events.first.marksDoseTaken, isFalse);
      expect(events.last.kind, DoseLogEventKind.doseSkipped);
      expect(events.last.marksDoseTaken, isFalse);
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
          ..execute('''
            CREATE TABLE reminder_schedules (
              id TEXT NOT NULL PRIMARY KEY,
              label TEXT NOT NULL,
              hour INTEGER NOT NULL,
              minute INTEGER NOT NULL,
              is_enabled INTEGER NOT NULL CHECK (is_enabled IN (0, 1)),
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              CHECK (hour >= 0 AND hour <= 23),
              CHECK (minute >= 0 AND minute <= 59)
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

  test('migration from schema one creates current schedule tables', () async {
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
          ..execute('PRAGMA user_version = 1;');
      },
    );
    final database = DoseyDatabase(executor);
    addTearDown(database.close);

    expect(await database.select(database.reminderSchedules).get(), isEmpty);
    expect(await database.select(database.prescriptions).get(), isEmpty);
    final profiles = await database.select(database.scheduleProfiles).get();

    expect(profiles, hasLength(1));
    expect(profiles.single.id, 'schedule-1');
    expect(profiles.single.isActive, isTrue);
  });

  test('migration from schema seven creates carousel slots table', () async {
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
          ..execute('''
            CREATE TABLE reminder_schedules (
              id TEXT NOT NULL PRIMARY KEY,
              label TEXT NOT NULL,
              prescription_id TEXT NULL,
              profile_id TEXT NOT NULL DEFAULT 'schedule-1',
              hour INTEGER NOT NULL,
              minute INTEGER NOT NULL,
              is_enabled INTEGER NOT NULL CHECK (is_enabled IN (0, 1)),
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              CHECK (hour >= 0 AND hour <= 23),
              CHECK (minute >= 0 AND minute <= 59)
            );
          ''')
          ..execute('''
            CREATE TABLE prescriptions (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              pill_type TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            );
          ''')
          ..execute('''
            CREATE TABLE schedule_profiles (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              is_active INTEGER NOT NULL CHECK (is_active IN (0, 1)),
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            );
          ''')
          ..execute('''
            CREATE TABLE auth_sessions (
              id TEXT NOT NULL PRIMARY KEY,
              user_id TEXT NOT NULL,
              email TEXT NOT NULL,
              display_name TEXT NULL,
              photo_url TEXT NULL,
              provider TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            );
          ''')
          ..execute('''
            CREATE TABLE dose_log_events (
              id TEXT NOT NULL PRIMARY KEY,
              kind TEXT NOT NULL,
              dose_id TEXT NOT NULL,
              occurred_at INTEGER NOT NULL,
              marks_dose_taken INTEGER NOT NULL CHECK (marks_dose_taken IN (0, 1))
            );
          ''')
          ..execute('PRAGMA user_version = 7;');
      },
    );
    final database = DoseyDatabase(executor);
    addTearDown(database.close);

    expect(await database.select(database.carouselSlots).get(), isEmpty);
  });
}
