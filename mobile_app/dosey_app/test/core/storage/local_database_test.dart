import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/controller/local_controller_command_repository.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings_repository.dart';
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
    'robot face settings default to not flipped, dim after inactivity, and keep voice features off',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = RobotFaceSettingsRepository(database);

      expect(
        await repository.getSettings(),
        const RobotFaceSettings(
          voiceVolumePreset: RobotVoiceVolumePreset.normal,
          voiceQuietHoursEnabled: false,
          voiceQuietHoursStartMinutes:
              RobotFaceSettings.defaultVoiceQuietHoursStartMinutes,
          voiceQuietHoursEndMinutes:
              RobotFaceSettings.defaultVoiceQuietHoursEndMinutes,
          voiceSafetyDuringQuietHoursEnabled: false,
          reminderVoiceEnabled: true,
          dispenseNarrationEnabled: true,
          safetyConfirmationVoiceEnabled: true,
          missedDoseVoiceEnabled: true,
          controllerAlertVoiceEnabled: true,
          idleChatterVoiceEnabled: true,
          idleChatterCooldownMinutes:
              RobotFaceSettings.defaultIdleChatterCooldownMinutes,
          reminderRepeatCooldownMinutes:
              RobotFaceSettings.defaultReminderRepeatCooldownMinutes,
          reminderRepeatPolicy: RobotReminderRepeatPolicy.noRepeats,
          wakeBeforeDoseMinutes: RobotFaceSettings.defaultWakeBeforeDoseMinutes,
          stayAwakeAfterDoseMinutes:
              RobotFaceSettings.defaultStayAwakeAfterDoseMinutes,
        ),
      );
    },
  );

  test(
    'robot face settings fall back to defaults for malformed values',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = RobotFaceSettingsRepository(database);

      await database.setAppSetting('robot_face_wake_before_dose_minutes', '-5');
      await database.setAppSetting(
        'robot_face_stay_awake_after_dose_minutes',
        'not-a-number',
      );
      await database.setAppSetting(
        'robot_face_idle_chatter_cooldown_minutes',
        '-1',
      );
      await database.setAppSetting(
        'robot_face_reminder_repeat_cooldown_minutes',
        'oops',
      );

      expect(
        await repository.getSettings(),
        const RobotFaceSettings(
          voiceVolumePreset: RobotVoiceVolumePreset.normal,
          voiceQuietHoursEnabled: false,
          voiceQuietHoursStartMinutes:
              RobotFaceSettings.defaultVoiceQuietHoursStartMinutes,
          voiceQuietHoursEndMinutes:
              RobotFaceSettings.defaultVoiceQuietHoursEndMinutes,
          voiceSafetyDuringQuietHoursEnabled: false,
          reminderVoiceEnabled: true,
          dispenseNarrationEnabled: true,
          safetyConfirmationVoiceEnabled: true,
          missedDoseVoiceEnabled: true,
          controllerAlertVoiceEnabled: true,
          idleChatterVoiceEnabled: true,
          idleChatterCooldownMinutes:
              RobotFaceSettings.defaultIdleChatterCooldownMinutes,
          reminderRepeatCooldownMinutes:
              RobotFaceSettings.defaultReminderRepeatCooldownMinutes,
          reminderRepeatPolicy: RobotReminderRepeatPolicy.noRepeats,
          wakeBeforeDoseMinutes: RobotFaceSettings.defaultWakeBeforeDoseMinutes,
          stayAwakeAfterDoseMinutes:
              RobotFaceSettings.defaultStayAwakeAfterDoseMinutes,
        ),
      );
    },
  );

  test('robot face settings stream updates after save', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = RobotFaceSettingsRepository(database);
    final states = <RobotFaceSettings>[];
    final subscription = repository.watchSettings().listen(states.add);
    addTearDown(subscription.cancel);

    await Future<void>.delayed(Duration.zero);
    await repository.saveSettings(
      const RobotFaceSettings(
        isFlipped: true,
        dimAfterInactivity: false,
        voiceEnabled: false,
        voiceVarietyEnabled: true,
        voiceVolumePreset: RobotVoiceVolumePreset.loud,
        voiceQuietHoursEnabled: true,
        voiceQuietHoursStartMinutes: 21 * 60,
        voiceQuietHoursEndMinutes: 6 * 60,
        voiceSafetyDuringQuietHoursEnabled: true,
        reminderVoiceEnabled: false,
        dispenseNarrationEnabled: false,
        safetyConfirmationVoiceEnabled: false,
        missedDoseVoiceEnabled: false,
        controllerAlertVoiceEnabled: false,
        idleChatterVoiceEnabled: false,
        idleChatterCooldownMinutes: 15,
        reminderRepeatCooldownMinutes: 10,
        reminderRepeatPolicy: RobotReminderRepeatPolicy.repeatRemindersOnly,
        wakeBeforeDoseMinutes: 15,
        stayAwakeAfterDoseMinutes: 20,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(states, [
      const RobotFaceSettings(
        voiceVolumePreset: RobotVoiceVolumePreset.normal,
        voiceQuietHoursEnabled: false,
        voiceQuietHoursStartMinutes:
            RobotFaceSettings.defaultVoiceQuietHoursStartMinutes,
        voiceQuietHoursEndMinutes:
            RobotFaceSettings.defaultVoiceQuietHoursEndMinutes,
        voiceSafetyDuringQuietHoursEnabled: false,
        reminderVoiceEnabled: true,
        dispenseNarrationEnabled: true,
        safetyConfirmationVoiceEnabled: true,
        missedDoseVoiceEnabled: true,
        controllerAlertVoiceEnabled: true,
        idleChatterVoiceEnabled: true,
        idleChatterCooldownMinutes:
            RobotFaceSettings.defaultIdleChatterCooldownMinutes,
        reminderRepeatCooldownMinutes:
            RobotFaceSettings.defaultReminderRepeatCooldownMinutes,
        reminderRepeatPolicy: RobotReminderRepeatPolicy.noRepeats,
        wakeBeforeDoseMinutes: RobotFaceSettings.defaultWakeBeforeDoseMinutes,
        stayAwakeAfterDoseMinutes:
            RobotFaceSettings.defaultStayAwakeAfterDoseMinutes,
      ),
      const RobotFaceSettings(
        isFlipped: true,
        dimAfterInactivity: false,
        voiceEnabled: false,
        voiceVarietyEnabled: true,
        voiceVolumePreset: RobotVoiceVolumePreset.loud,
        voiceQuietHoursEnabled: true,
        voiceQuietHoursStartMinutes: 21 * 60,
        voiceQuietHoursEndMinutes: 6 * 60,
        voiceSafetyDuringQuietHoursEnabled: true,
        reminderVoiceEnabled: false,
        dispenseNarrationEnabled: false,
        safetyConfirmationVoiceEnabled: false,
        missedDoseVoiceEnabled: false,
        controllerAlertVoiceEnabled: false,
        idleChatterVoiceEnabled: false,
        idleChatterCooldownMinutes: 15,
        reminderRepeatCooldownMinutes: 10,
        reminderRepeatPolicy: RobotReminderRepeatPolicy.repeatRemindersOnly,
        wakeBeforeDoseMinutes: 15,
        stayAwakeAfterDoseMinutes: 20,
      ),
    ]);
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

  test(
    'local dose log persists missed recognition without marking taken',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = DriftDoseLogRepository(database);

      await repository.addEvent(
        DoseLogEvent.doseMissedRecognized(
          doseId: 'missed-dose',
          occurredAt: DateTime.utc(2026, 6, 9, 19),
        ),
      );

      final events = await repository.watchEvents().first;
      expect(events, hasLength(1));
      expect(events.single.kind, DoseLogEventKind.doseMissedRecognized);
      expect(events.single.doseId, 'missed-dose');
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
    expect(await database.select(database.doseLogEvents).get(), isEmpty);
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

  test('carousel slot status rejects invalid storage values', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    await database
        .into(database.carouselSlots)
        .insert(
          CarouselSlotsCompanion.insert(
            id: 'slot-valid-status',
            slotNumber: 1,
            prescriptionId: 'vitamin-d',
            scheduleId: 'vitamin-d-morning',
            profileId: 'schedule-1',
            status: CarouselSlotStatus.loaded.storageValue,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        );

    expect(
      () => database
          .into(database.carouselSlots)
          .insert(
            CarouselSlotsCompanion.insert(
              id: 'slot-invalid-status',
              slotNumber: 2,
              prescriptionId: 'vitamin-d',
              scheduleId: 'vitamin-d-evening',
              profileId: 'schedule-1',
              status: 'invalid-status',
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          ),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('status'),
        ),
      ),
    );
  });

  test('migration from schema eight preserves carousel slots', () async {
    final database = DoseyDatabase(
      _schemaEightExecutor(status: CarouselSlotStatus.loaded.storageValue),
    );
    addTearDown(database.close);

    final slots = await database.select(database.carouselSlots).get();

    expect(slots, hasLength(1));
    expect(slots.single.id, 'slot-1');
    expect(slots.single.status, CarouselSlotStatus.loaded.storageValue);
  });

  test('migration from schema eight normalizes legacy slot statuses', () async {
    final database = DoseyDatabase(_schemaEightExecutor(status: 'legacy'));
    addTearDown(database.close);

    final slots = await database.select(database.carouselSlots).get();

    expect(slots, hasLength(1));
    expect(slots.single.id, 'slot-1');
    expect(slots.single.status, CarouselSlotStatus.needsReview.storageValue);
  });

  test(
    'migration from schema nine adds prescription refill tracking',
    () async {
      final database = DoseyDatabase(_schemaNineExecutor());
      addTearDown(database.close);

      final prescriptions = await database.select(database.prescriptions).get();
      final refillEvents = await database
          .select(database.prescriptionRefills)
          .get();

      expect(prescriptions.single.id, 'vitamin-d');
      expect(prescriptions.single.remainingDoses, 0);
      expect(prescriptions.single.refillThreshold, 3);
      expect(refillEvents, isEmpty);
    },
  );

  test(
    'migration from schema nine preserves non-negative prescription constraints',
    () async {
      final database = DoseyDatabase(_schemaNineExecutor());
      addTearDown(database.close);

      expect(
        () => database.customStatement('''
          INSERT INTO prescriptions (
            id,
            name,
            pill_type,
            remaining_doses,
            refill_threshold,
            created_at,
            updated_at
          ) VALUES (
            'negative-test',
            'Negative test',
            'capsule',
            -1,
            -2,
            0,
            0
          );
        '''),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('CHECK constraint failed'),
          ),
        ),
      );
    },
  );

  test('migration from schema ten creates controller command tables', () async {
    final database = DoseyDatabase(_schemaTenExecutor());
    addTearDown(database.close);

    final repository = LocalControllerCommandRepository(database);
    final session = await repository.createSession(
      commandType: ControllerCommandType.status,
      now: DateTime.utc(2026, 7, 10, 11),
    );

    await repository.appendEvent(
      session.id,
      ControllerCommandEventType.commandSent,
      occurredAt: DateTime.utc(2026, 7, 10, 11, 0, 5),
    );

    final sessions = await repository.getUnresolvedSessions();
    final events = await repository.getEventsForSession(session.id);

    expect(sessions.single.commandType, ControllerCommandType.status);
    expect(events.single.sequence, 1);
    expect(events.single.eventType, ControllerCommandEventType.commandSent);
  });
}

NativeDatabase _schemaEightExecutor({required String status}) {
  final now = DateTime.utc(2026, 6, 25).millisecondsSinceEpoch ~/ 1000;
  return NativeDatabase.memory(
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
          CREATE TABLE carousel_slots (
            id TEXT NOT NULL PRIMARY KEY,
            slot_number INTEGER NOT NULL,
            prescription_id TEXT NOT NULL,
            schedule_id TEXT NOT NULL,
            profile_id TEXT NOT NULL,
            status TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            CHECK (slot_number > 0),
            UNIQUE (profile_id, slot_number),
            UNIQUE (profile_id, schedule_id)
          );
        ''')
        ..execute('''
          INSERT INTO carousel_slots (
            id,
            slot_number,
            prescription_id,
            schedule_id,
            profile_id,
            status,
            created_at,
            updated_at
          ) VALUES (
            'slot-1',
            1,
            'vitamin-d',
            'vitamin-d-morning',
            'schedule-1',
            '$status',
            $now,
            $now
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
        ..execute('PRAGMA user_version = 8;');
    },
  );
}

NativeDatabase _schemaNineExecutor() {
  final now = DateTime.utc(2026, 6, 25).millisecondsSinceEpoch ~/ 1000;
  return NativeDatabase.memory(
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
          INSERT INTO prescriptions (
            id,
            name,
            pill_type,
            created_at,
            updated_at
          ) VALUES (
            'vitamin-d',
            'Vitamin D',
            'capsule',
            $now,
            $now
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
          CREATE TABLE carousel_slots (
            id TEXT NOT NULL PRIMARY KEY,
            slot_number INTEGER NOT NULL,
            prescription_id TEXT NOT NULL,
            schedule_id TEXT NOT NULL,
            profile_id TEXT NOT NULL,
            status TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            CHECK (slot_number > 0),
            CHECK (status IN ('assigned', 'loaded', 'dispensed', 'needs_review')),
            UNIQUE (profile_id, slot_number),
            UNIQUE (profile_id, schedule_id)
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
        ..execute('PRAGMA user_version = 9;');
    },
  );
}

NativeDatabase _schemaTenExecutor() {
  final now = DateTime.utc(2026, 6, 25).millisecondsSinceEpoch ~/ 1000;
  return NativeDatabase.memory(
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
            remaining_doses INTEGER NOT NULL DEFAULT 0 CHECK (remaining_doses >= 0),
            refill_threshold INTEGER NOT NULL DEFAULT 3 CHECK (refill_threshold >= 0),
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          );
        ''')
        ..execute('''
          CREATE TABLE prescription_refills (
            id TEXT NOT NULL PRIMARY KEY,
            prescription_id TEXT NOT NULL,
            dose_delta INTEGER NOT NULL CHECK (dose_delta > 0),
            remaining_after INTEGER NOT NULL CHECK (remaining_after >= 0),
            occurred_at INTEGER NOT NULL,
            note TEXT NULL
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
          INSERT INTO schedule_profiles (id, name, is_active, created_at, updated_at)
          VALUES ('schedule-1', 'Schedule 1', 1, $now, $now);
        ''')
        ..execute('''
          CREATE TABLE carousel_slots (
            id TEXT NOT NULL PRIMARY KEY,
            slot_number INTEGER NOT NULL,
            prescription_id TEXT NOT NULL,
            schedule_id TEXT NOT NULL,
            profile_id TEXT NOT NULL,
            status TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            CHECK (slot_number > 0),
            CHECK (status IN ('assigned', 'loaded', 'dispensed', 'needs_review')),
            UNIQUE (profile_id, slot_number),
            UNIQUE (profile_id, schedule_id)
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
        ..execute('PRAGMA user_version = 10;');
    },
  );
}
