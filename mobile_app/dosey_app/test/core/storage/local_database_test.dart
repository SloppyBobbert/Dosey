import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/audit/local_admin_audit_repository.dart';
import 'package:dosey_app/core/controller/local_controller_command_repository.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

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
    'existing v13 databases upgrade carousel load snapshots to allow retained status',
    () async {
      final sqlite = sqlite3.openInMemory();
      addTearDown(sqlite.close);
      sqlite.execute('PRAGMA foreign_keys = OFF;');
      sqlite.execute('''
        CREATE TABLE app_settings (
          key TEXT NOT NULL PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');
      sqlite.execute('''
        CREATE TABLE reminder_schedules (
          id TEXT NOT NULL PRIMARY KEY,
          label TEXT NOT NULL,
          prescription_id TEXT,
          profile_id TEXT NOT NULL DEFAULT 'schedule-1',
          hour INTEGER NOT NULL,
          minute INTEGER NOT NULL,
          is_enabled INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');
      sqlite.execute('''
        CREATE TABLE prescriptions (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          pill_type TEXT NOT NULL,
          remaining_doses INTEGER NOT NULL DEFAULT 0,
          guided_pill_icon TEXT NOT NULL DEFAULT 'round_pill',
          available_doses INTEGER NOT NULL DEFAULT 0,
          loaded_doses INTEGER NOT NULL DEFAULT 0,
          default_refill_quantity INTEGER NOT NULL DEFAULT 30,
          default_dose_count_per_dose INTEGER NOT NULL DEFAULT 1,
          refill_threshold INTEGER NOT NULL DEFAULT 3,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');
      sqlite.execute('''
        CREATE TABLE prescription_refills (
          id TEXT NOT NULL PRIMARY KEY,
          prescription_id TEXT NOT NULL,
          dose_delta INTEGER NOT NULL,
          remaining_after INTEGER NOT NULL,
          occurred_at INTEGER NOT NULL,
          note TEXT
        );
      ''');
      sqlite.execute('''
        CREATE TABLE schedule_profiles (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          is_active INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');
      sqlite.execute('''
        CREATE TABLE carousel_slots (
          id TEXT NOT NULL PRIMARY KEY,
          slot_number INTEGER NOT NULL,
          prescription_id TEXT NOT NULL,
          schedule_id TEXT NOT NULL,
          profile_id TEXT NOT NULL,
          status TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');
      sqlite.execute('''
        CREATE TABLE carousel_load_sessions (
          id TEXT NOT NULL PRIMARY KEY,
          profile_id TEXT NOT NULL,
          mode TEXT NOT NULL,
          status TEXT NOT NULL,
          plan_created_at INTEGER,
          started_at INTEGER,
          confirmed_at INTEGER,
          position_before INTEGER NOT NULL DEFAULT 0,
          position_after INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');
      sqlite.execute('''
        CREATE TABLE carousel_load_slot_snapshots (
          id TEXT NOT NULL PRIMARY KEY,
          session_id TEXT NOT NULL,
          slot_number INTEGER NOT NULL,
          status TEXT NOT NULL CHECK (status IN ('loaded', 'dispensed', 'needs_review', 'empty', 'shortage')),
          scheduled_at INTEGER,
          bundle_key TEXT,
          schedule_ids_json TEXT NOT NULL,
          prescription_ids_json TEXT NOT NULL,
          prescription_names_json TEXT NOT NULL,
          pill_icons_json TEXT NOT NULL,
          dose_instructions_json TEXT NOT NULL,
          loaded_at INTEGER,
          moved_at INTEGER,
          resolved_at INTEGER,
          review_reason TEXT,
          created_at INTEGER NOT NULL,
          UNIQUE (session_id, slot_number)
        );
      ''');
      sqlite.execute('''
        CREATE TABLE carousel_states (
          profile_id TEXT NOT NULL PRIMARY KEY,
          active_load_session_id TEXT,
          current_position INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL
        );
      ''');
      sqlite.execute('''
        CREATE TABLE medication_shortage_alerts (
          id TEXT NOT NULL PRIMARY KEY,
          profile_id TEXT NOT NULL,
          load_session_id TEXT NOT NULL,
          shortage_status TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          resolved_at INTEGER
        );
      ''');
      sqlite.execute('''
        CREATE TABLE auth_sessions (
          id TEXT NOT NULL PRIMARY KEY,
          user_id TEXT NOT NULL,
          email TEXT NOT NULL,
          display_name TEXT,
          photo_url TEXT,
          provider TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');
      sqlite.execute('''
        CREATE TABLE dose_log_events (
          id TEXT NOT NULL PRIMARY KEY,
          kind TEXT NOT NULL,
          dose_id TEXT NOT NULL,
          occurred_at INTEGER NOT NULL,
          marks_dose_taken INTEGER NOT NULL
        );
      ''');
      sqlite.execute('''
        CREATE TABLE controller_command_sessions (
          id TEXT NOT NULL PRIMARY KEY,
          command_type TEXT NOT NULL,
          dose_id TEXT,
          schedule_id TEXT,
          slot_id TEXT,
          state TEXT NOT NULL,
          failure_reason TEXT,
          created_at INTEGER NOT NULL,
          accepted_at INTEGER,
          resolved_at INTEGER,
          updated_at INTEGER NOT NULL
        );
      ''');
      sqlite.execute('''
        CREATE TABLE controller_command_events (
          id TEXT NOT NULL PRIMARY KEY,
          session_id TEXT NOT NULL,
          sequence INTEGER NOT NULL,
          event_type TEXT NOT NULL,
          occurred_at INTEGER NOT NULL,
          details TEXT
        );
      ''');
      sqlite.execute('''
        CREATE TABLE admin_audit_events (
          id TEXT NOT NULL PRIMARY KEY,
          event_type TEXT NOT NULL,
          target_type TEXT NOT NULL,
          target_id TEXT,
          actor_type TEXT NOT NULL,
          actor_user_id TEXT,
          actor_label TEXT NOT NULL,
          source_device_role TEXT NOT NULL,
          summary TEXT NOT NULL,
          details_json TEXT,
          cloud_event_id TEXT,
          last_synced_at INTEGER,
          occurred_at INTEGER NOT NULL
        );
      ''');
      sqlite.execute('PRAGMA user_version = 13;');

      final database = DoseyDatabase(
        DatabaseConnection(NativeDatabase.opened(sqlite)),
      );
      addTearDown(database.close);
      await database.customStatement('''
        INSERT INTO carousel_load_slot_snapshots (
          id,
          session_id,
          slot_number,
          status,
          schedule_ids_json,
          prescription_ids_json,
          prescription_names_json,
          pill_icons_json,
          dose_instructions_json,
          created_at
        ) VALUES (
          'snapshot-1',
          'session-1',
          1,
          'retained',
          '[]',
          '[]',
          '[]',
          '[]',
          '[]',
          0
        );
      ''');

      final rows = await database
          .select(database.carouselLoadSlotSnapshots)
          .get();
      expect(rows.single.status, 'retained');
    },
  );

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

  test('robot face return timeout defaults to two minutes', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = RobotFaceSettingsRepository(database);

    final settings = await repository.getSettings();

    expect(
      settings.returnToFaceAfterInactivityMinutes,
      RobotFaceSettings.defaultReturnToFaceAfterInactivityMinutes,
    );
    expect(settings.returnToFaceAfterInactivityMinutes, 2);
  });

  test('robot face PIR wake duration defaults to 60 seconds', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = RobotFaceSettingsRepository(database);

    final settings = await repository.getSettings();

    expect(
      settings.pirWakeDurationSeconds,
      RobotFaceSettings.defaultPirWakeDurationSeconds,
    );
    expect(settings.pirWakeDurationSeconds, 60);
  });

  test('robot face PIR wake duration persists a custom value', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = RobotFaceSettingsRepository(database);

    await repository.saveSettings(
      const RobotFaceSettings(pirWakeDurationSeconds: 120),
    );

    expect((await repository.getSettings()).pirWakeDurationSeconds, 120);
  });

  test(
    'robot face PIR wake duration falls back for malformed storage',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = RobotFaceSettingsRepository(database);
      await database.setAppSetting(
        'robot_face_pir_wake_duration_seconds',
        'not-a-number',
      );

      expect(
        (await repository.getSettings()).pirWakeDurationSeconds,
        RobotFaceSettings.defaultPirWakeDurationSeconds,
      );
    },
  );

  test(
    'robot face PIR wake duration falls back for unsupported storage',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = RobotFaceSettingsRepository(database);
      await database.setAppSetting(
        'robot_face_pir_wake_duration_seconds',
        '90',
      );

      expect(
        (await repository.getSettings()).pirWakeDurationSeconds,
        RobotFaceSettings.defaultPirWakeDurationSeconds,
      );
    },
  );

  test('robot face return timeout persists a custom value', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = RobotFaceSettingsRepository(database);

    await repository.saveSettings(
      const RobotFaceSettings(returnToFaceAfterInactivityMinutes: 5),
    );

    expect(
      (await repository.getSettings()).returnToFaceAfterInactivityMinutes,
      5,
    );
  });

  test('robot face return timeout falls back for malformed storage', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = RobotFaceSettingsRepository(database);
    await database.setAppSetting(
      'robot_face_return_to_face_after_inactivity_minutes',
      'not-a-number',
    );

    expect(
      (await repository.getSettings()).returnToFaceAfterInactivityMinutes,
      RobotFaceSettings.defaultReturnToFaceAfterInactivityMinutes,
    );
  });

  test(
    'robot face return timeout falls back for unsupported storage',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = RobotFaceSettingsRepository(database);
      await database.setAppSetting(
        'robot_face_return_to_face_after_inactivity_minutes',
        '99',
      );

      expect(
        (await repository.getSettings()).returnToFaceAfterInactivityMinutes,
        RobotFaceSettings.defaultReturnToFaceAfterInactivityMinutes,
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

  test(
    'robot face settings constructor validates quiet-hours minute bounds',
    () {
      const settings = RobotFaceSettings(
        voiceQuietHoursStartMinutes: -1,
        voiceQuietHoursEndMinutes: 24 * 60,
      );

      expect(
        settings.voiceQuietHoursStartMinutes,
        RobotFaceSettings.defaultVoiceQuietHoursStartMinutes,
      );
      expect(
        settings.voiceQuietHoursEndMinutes,
        RobotFaceSettings.defaultVoiceQuietHoursEndMinutes,
      );

      const validSettings = RobotFaceSettings(
        voiceQuietHoursStartMinutes: 21 * 60,
        voiceQuietHoursEndMinutes: 6 * 60,
      );
      expect(validSettings.voiceQuietHoursStartMinutes, 21 * 60);
      expect(validSettings.voiceQuietHoursEndMinutes, 6 * 60);
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

  test(
    'admin audit recent history uses deterministic descending order',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalAdminAuditRepository(database);
      final occurredAt = DateTime.utc(2026, 6, 9, 12);

      await repository.addEvent(
        AdminAuditEvent(
          id: 'audit-1',
          eventType: AdminAuditEventType.householdProfileUpdated,
          targetType: AdminAuditTargetType.household,
          actorType: AdminAuditActorType.signedInUser,
          actorUserId: 'google:user-a',
          actorLabel: 'Alpha (google)',
          sourceDeviceRole: 'androidRobot',
          summary: 'First',
          occurredAt: occurredAt,
        ),
      );
      await repository.addEvent(
        AdminAuditEvent(
          id: 'audit-2',
          eventType: AdminAuditEventType.householdProfileUpdated,
          targetType: AdminAuditTargetType.household,
          actorType: AdminAuditActorType.signedInUser,
          actorUserId: 'apple:user-b',
          actorLabel: 'Beta (apple)',
          sourceDeviceRole: 'androidRobot',
          summary: 'Second',
          targetId: 'z-target',
          occurredAt: occurredAt,
        ),
      );

      final events = await repository.watchRecentEvents(limit: 2).first;
      expect(events.map((event) => event.summary).toList(), [
        'Second',
        'First',
      ]);
      expect(events.first.actorUserId, 'apple:user-b');
    },
  );

  test('admin audit recent history updates after new events', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAdminAuditRepository(database);

    final states = <List<AdminAuditEvent>>[];
    final subscription = repository
        .watchRecentEvents(limit: 8)
        .listen(states.add);
    addTearDown(subscription.cancel);
    await Future<void>.delayed(Duration.zero);

    await repository.addEvent(
      AdminAuditEvent(
        id: 'audit-reactive',
        eventType: AdminAuditEventType.householdProfileUpdated,
        targetType: AdminAuditTargetType.household,
        actorType: AdminAuditActorType.localAdmin,
        actorLabel: 'local admin',
        sourceDeviceRole: 'androidRobot',
        summary: 'Updated household profile',
        occurredAt: DateTime.utc(2026, 6, 9, 12),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(states, hasLength(2));
    expect(states.first, isEmpty);
    expect(states.last.single.summary, 'Updated household profile');
  });

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

  test(
    'migration from schema fourteen creates the health event index',
    () async {
      final executor = NativeDatabase.memory(
        setup: (database) {
          database.execute('PRAGMA user_version = 14;');
        },
      );
      final database = DoseyDatabase(executor);
      addTearDown(database.close);

      final index = await database
          .customSelect(
            "SELECT sql FROM sqlite_master WHERE type = 'index' AND name = ?",
            variables: [
              Variable<String>('controller_health_events_occurred_at_idx'),
            ],
          )
          .getSingle();

      expect(index.read<String>('sql'), contains('occurred_at DESC'));
    },
  );

  test(
    'fresh revised guided loading storage persists inventory buckets and explicit snapshot fields',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final now = DateTime.utc(2026, 7, 22, 12);
      final repository = LocalPrescriptionRepository(database);

      await repository.upsertPrescription(
        Prescription(
          id: 'rx-1',
          name: 'Vitamin D',
          pillType: PillType.capsule,
          guidedPillIcon: GuidedPillIcon.softgel,
          availableDoses: 12,
          loadedDoses: 5,
          usedDoses: 3,
          reviewDoses: 1,
          defaultRefillQuantity: 30,
          defaultDoseCountPerDose: 2,
          doseInstructions: 'Take with breakfast',
          refillThreshold: 4,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await database
          .into(database.carouselStates)
          .insertOnConflictUpdate(
            CarouselStatesCompanion.insert(
              profileId: 'schedule-1',
              currentPosition: const Value(0),
              updatedAt: now,
            ),
          );
      await database
          .into(database.carouselLoadSessions)
          .insert(
            CarouselLoadSessionsCompanion.insert(
              id: 'session-1',
              profileId: 'schedule-1',
              mode: 'full_load',
              status: 'confirmed',
              planCreatedAt: Value(now),
              startedAt: Value(now),
              confirmedAt: Value(now.add(const Duration(minutes: 5))),
              positionBefore: 0,
              positionAfter: 14,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await database
          .into(database.carouselLoadSlotSnapshots)
          .insert(
            CarouselLoadSlotSnapshotsCompanion.insert(
              id: 'snapshot-1',
              sessionId: 'session-1',
              slotNumber: 1,
              status: 'shortage',
              scheduleIdsJson: '[]',
              prescriptionIdsJson: '["rx-1"]',
              prescriptionNamesJson: '["Vitamin D"]',
              pillIconsJson: '["softgel"]',
              doseInstructionsJson: '["Take with breakfast"]',
              scheduledAt: Value(now),
              bundleKey: const Value('bundle-1'),
              reviewReason: const Value('missing dose'),
              createdAt: now,
            ),
          );
      await database
          .into(database.medicationShortageAlerts)
          .insert(
            MedicationShortageAlertsCompanion.insert(
              id: 'alert-1',
              profileId: 'schedule-1',
              slotNumber: 1,
              bundleKey: 'bundle-1',
              scheduledAt: now,
              prescriptionIdsJson: '["rx-1"]',
              prescriptionNamesJson: '["Vitamin D"]',
              status: 'active',
              localDeliveryState: 'pending',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final prescriptions = await repository.watchPrescriptions().first;
      final session = await database
          .select(database.carouselLoadSessions)
          .getSingle();
      final snapshot = await database
          .select(database.carouselLoadSlotSnapshots)
          .getSingle();
      final state = await database.select(database.carouselStates).getSingle();

      expect(prescriptions.single.usedDoses, 3);
      expect(prescriptions.single.reviewDoses, 1);
      expect(prescriptions.single.doseInstructions, 'Take with breakfast');
      expect(session.positionBefore, 0);
      expect(session.positionAfter, 14);
      expect(snapshot.scheduleIdsJson, '[]');
      expect(snapshot.prescriptionIdsJson, '["rx-1"]');
      expect(snapshot.doseInstructionsJson, '["Take with breakfast"]');
      expect(state.currentPosition, 0);
    },
  );

  test(
    'legacy prescription compatibility keeps total on hand semantics and preserves guided fields on edit',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalPrescriptionRepository(database);
      final now = DateTime.utc(2026, 7, 22, 12);

      await repository.upsertPrescription(
        Prescription(
          id: 'rx-compat',
          name: 'Vitamin D',
          pillType: PillType.capsule,
          availableDoses: 12,
          loadedDoses: 5,
          usedDoses: 3,
          reviewDoses: 1,
          guidedPillIcon: GuidedPillIcon.softgel,
          defaultRefillQuantity: 45,
          defaultDoseCountPerDose: 2,
          doseInstructions: 'With food',
          refillThreshold: 4,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await repository.upsertPrescription(
        Prescription(
          id: 'rx-compat',
          name: 'Vitamin D updated',
          pillType: PillType.capsule,
          remainingDoses: 18,
          refillThreshold: 6,
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );

      final prescriptions = await repository.watchPrescriptions().first;
      final prescription = prescriptions.single;

      expect(prescription.remainingDoses, 18);
      expect(prescription.needsRefill, isFalse);
      expect(prescription.availableDoses, 12);
      expect(prescription.loadedDoses, 5);
      expect(prescription.usedDoses, 3);
      expect(prescription.reviewDoses, 1);
      expect(prescription.guidedPillIcon, GuidedPillIcon.softgel);
      expect(prescription.defaultRefillQuantity, 45);
      expect(prescription.defaultDoseCountPerDose, 2);
      expect(prescription.doseInstructions, 'With food');
    },
  );

  test('refills and taken doses conserve explicit inventory buckets', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalPrescriptionRepository(database);
    final now = DateTime.utc(2026, 7, 22, 12);

    await repository.upsertPrescription(
      Prescription(
        id: 'rx-buckets',
        name: 'Omega 3',
        pillType: PillType.capsule,
        availableDoses: 10,
        loadedDoses: 4,
        usedDoses: 2,
        reviewDoses: 1,
        refillThreshold: 3,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await repository.addRefill(
      prescriptionId: 'rx-buckets',
      doseCount: 6,
      occurredAt: now.add(const Duration(minutes: 1)),
    );
    await repository.recordTakenDose(
      'rx-buckets',
      occurredAt: now.add(const Duration(minutes: 2)),
    );

    final prescription = (await repository.watchPrescriptions().first).single;

    expect(prescription.availableDoses, 16);
    expect(prescription.loadedDoses, 3);
    expect(prescription.usedDoses, 3);
    expect(prescription.reviewDoses, 1);
    expect(prescription.remainingDoses, 20);
    expect(prescription.needsRefill, isFalse);
    expect(
      (await database.select(database.prescriptionRefills).get())
          .single
          .remainingAfter,
      21,
    );
  });

  test(
    'legacy taken dose still decrements total inventory when loaded bucket is zero',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalPrescriptionRepository(database);
      final now = DateTime.utc(2026, 7, 22, 12);

      await repository.upsertPrescription(
        Prescription(
          id: 'rx-legacy-taken',
          name: 'Calcium',
          pillType: PillType.tablet,
          remainingDoses: 9,
          refillThreshold: 2,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await repository.recordTakenDose(
        'rx-legacy-taken',
        occurredAt: now.add(const Duration(minutes: 1)),
      );

      final prescription = (await repository.watchPrescriptions().first).single;

      expect(prescription.remainingDoses, 8);
      expect(prescription.availableDoses, 8);
      expect(prescription.loadedDoses, 0);
      expect(prescription.usedDoses, 0);
    },
  );

  test(
    'migration adds revised guided loading storage and copies remaining doses into available doses',
    () async {
      final database = DoseyDatabase(_schemaTwelveExecutor());
      addTearDown(database.close);

      final prescriptions = await database.select(database.prescriptions).get();
      final states = await database.select(database.carouselStates).get();

      expect(prescriptions, hasLength(1));
      expect(prescriptions.single.remainingDoses, 12);
      expect(prescriptions.single.availableDoses, 12);
      expect(prescriptions.single.loadedDoses, 0);
      expect(prescriptions.single.usedDoses, 0);
      expect(prescriptions.single.reviewDoses, 0);
      expect(
        prescriptions.single.guidedPillIcon,
        GuidedPillIcon.roundPill.storageValue,
      );
      expect(prescriptions.single.defaultRefillQuantity, 30);
      expect(prescriptions.single.defaultDoseCountPerDose, 1);
      expect(prescriptions.single.doseInstructions, '');
      expect(states.single.currentPosition, 0);
    },
  );

  test(
    'migration seeds carousel state rows for every existing schedule profile',
    () async {
      final database = DoseyDatabase(_schemaTwelveExecutor(extraProfiles: 2));
      addTearDown(database.close);

      final states = await database.select(database.carouselStates).get();

      expect(states.map((row) => row.profileId).toSet(), {
        'schedule-1',
        'schedule-2',
        'schedule-3',
      });
      expect(states.every((row) => row.currentPosition == 0), isTrue);
    },
  );

  test(
    'revised guided loading storage enforces prescription and position constraints',
    () async {
      final database = DoseyDatabase(_schemaTwelveExecutor());
      addTearDown(database.close);

      expect(
        () => database.customStatement('''
          INSERT INTO prescriptions (
            id,
            name,
            pill_type,
            remaining_doses,
            guided_pill_icon,
            available_doses,
            loaded_doses,
            used_doses,
            review_doses,
            default_refill_quantity,
            default_dose_count_per_dose,
            dose_instructions,
            refill_threshold,
            created_at,
            updated_at
          ) VALUES (
            'invalid-guided',
            'Invalid Guided',
            'capsule',
            1,
            'roundPill',
            -1,
            -1,
            -1,
            -1,
            -1,
            0,
            '',
            1,
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

      expect(
        () => database
            .into(database.carouselStates)
            .insert(
              CarouselStatesCompanion.insert(
                profileId: 'bad-position',
                currentPosition: const Value(-1),
                updatedAt: DateTime.utc(2026),
              ),
            ),
        throwsA(isA<Exception>()),
      );

      expect(
        () => database
            .into(database.carouselStates)
            .insert(
              CarouselStatesCompanion.insert(
                profileId: 'bad-position-high',
                currentPosition: const Value(15),
                updatedAt: DateTime.utc(2026),
              ),
            ),
        throwsA(isA<Exception>()),
      );

      await database
          .into(database.carouselStates)
          .insert(
            CarouselStatesCompanion.insert(
              profileId: 'ok-low',
              currentPosition: const Value(0),
              updatedAt: DateTime.utc(2026),
            ),
          );
      await database
          .into(database.carouselStates)
          .insert(
            CarouselStatesCompanion.insert(
              profileId: 'ok-high',
              currentPosition: const Value(14),
              updatedAt: DateTime.utc(2026),
            ),
          );
    },
  );

  test(
    'shortage recognition remains independent from shortage status',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final now = DateTime.utc(2026, 7, 22, 12);

      await database
          .into(database.carouselLoadSessions)
          .insert(
            CarouselLoadSessionsCompanion.insert(
              id: 'session-1',
              profileId: 'schedule-1',
              mode: 'top_off',
              status: 'confirmed',
              startedAt: Value(now),
              positionBefore: 0,
              positionAfter: 1,
              planCreatedAt: Value(now),
              confirmedAt: Value(now.add(const Duration(minutes: 5))),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await database
          .into(database.medicationShortageAlerts)
          .insert(
            MedicationShortageAlertsCompanion.insert(
              id: 'alert-1',
              profileId: 'schedule-1',
              loadSessionId: const Value('session-1'),
              slotNumber: 1,
              bundleKey: 'bundle-1',
              scheduledAt: now,
              prescriptionIdsJson: '["rx-1"]',
              prescriptionNamesJson: '["Vitamin D"]',
              status: 'active',
              recognizedAt: Value(now.add(const Duration(minutes: 1))),
              localDeliveryState: 'sent',
              localNotificationSentAt: Value(
                now.add(const Duration(minutes: 1)),
              ),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final alert = await database
          .select(database.medicationShortageAlerts)
          .getSingle();

      expect(alert.status, 'active');
      expect(alert.recognizedAt, isNot(equals(null)));
      expect(alert.resolvedAt, equals(null));
    },
  );
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

NativeDatabase _schemaTwelveExecutor({int extraProfiles = 0}) {
  final now = DateTime.utc(2026, 7, 22).millisecondsSinceEpoch ~/ 1000;
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
          INSERT INTO prescriptions (
            id,
            name,
            pill_type,
            remaining_doses,
            refill_threshold,
            created_at,
            updated_at
          ) VALUES (
            'vitamin-d',
            'Vitamin D',
            'capsule',
            12,
            4,
            $now,
            $now
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
        ..execute('''
          CREATE TABLE controller_command_sessions (
            id TEXT NOT NULL PRIMARY KEY,
            command_type TEXT NOT NULL,
            dose_id TEXT NULL,
            schedule_id TEXT NULL,
            slot_id TEXT NULL,
            state TEXT NOT NULL,
            failure_reason TEXT NULL,
            created_at INTEGER NOT NULL,
            accepted_at INTEGER NULL,
            resolved_at INTEGER NULL,
            updated_at INTEGER NOT NULL
          );
        ''')
        ..execute('''
          CREATE INDEX controller_command_sessions_unresolved_idx
          ON controller_command_sessions (resolved_at, state, updated_at);
        ''')
        ..execute('''
          CREATE TABLE controller_command_events (
            id TEXT NOT NULL PRIMARY KEY,
            session_id TEXT NOT NULL,
            sequence INTEGER NOT NULL,
            event_type TEXT NOT NULL,
            occurred_at INTEGER NOT NULL,
            details TEXT NULL
          );
        ''')
        ..execute('''
          CREATE UNIQUE INDEX controller_command_events_session_sequence_idx
          ON controller_command_events (session_id, sequence);
        ''')
        ..execute('''
          CREATE TABLE admin_audit_events (
            id TEXT NOT NULL PRIMARY KEY,
            event_type TEXT NOT NULL,
            target_type TEXT NOT NULL,
            target_id TEXT NULL,
            actor_type TEXT NOT NULL,
            actor_user_id TEXT NULL,
            actor_label TEXT NOT NULL,
            source_device_role TEXT NOT NULL,
            summary TEXT NOT NULL,
            details_json TEXT NULL,
            cloud_event_id TEXT NULL,
            last_synced_at INTEGER NULL,
            occurred_at INTEGER NOT NULL
          );
        ''')
        ..execute('PRAGMA user_version = 12;');

      if (extraProfiles > 0) {
        database.execute(
          [
            for (var index = 0; index < extraProfiles; index++)
              '''
            INSERT INTO schedule_profiles (id, name, is_active, created_at, updated_at)
            VALUES ('schedule-${index + 2}', 'Schedule ${index + 2}', 0, $now, $now);
          ''',
          ].join(),
        );
      }
    },
  );
}
