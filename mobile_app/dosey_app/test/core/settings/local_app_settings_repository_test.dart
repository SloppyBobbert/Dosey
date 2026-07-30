import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/settings/app_theme_preference.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/settings/personal_setup_step.dart';
import 'package:dosey_app/core/settings/robot_onboarding_step.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('theme preference defaults to dark', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    expect(
      await repository.watchThemePreference().first,
      AppThemePreference.dark,
    );
  });

  test('theme preferences round-trip and emit updates', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );
    for (final preference in AppThemePreference.values) {
      final update = repository.watchThemePreference().firstWhere(
        (value) => value == preference,
      );

      await repository.setThemePreference(preference);

      expect(await update, preference);
      expect(await repository.watchThemePreference().first, preference);
    }
  });

  test('malformed theme preference falls back to dark', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    await database.setAppSetting('theme_preference', 'sepia');

    expect(
      await repository.watchThemePreference().first,
      AppThemePreference.dark,
    );
  });

  test('guided trial is incomplete by default', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    expect(await repository.getGuidedTrialCompletion(), isNull);
  });

  test('guided trial completion stores time and app version', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );
    final completedAt = DateTime.utc(2026, 7, 26, 12, 30);

    await repository.setGuidedTrialCompleted(
      completedAt: completedAt,
      appVersion: '1.0.0+1',
    );

    expect(
      await repository.getGuidedTrialCompletion(),
      GuidedTrialCompletion(completedAt: completedAt, appVersion: '1.0.0+1'),
    );
  });

  test('guided trial ignores malformed or incomplete metadata', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    await database.setAppSetting('guided_trial_completed', 'true');
    await database.setAppSetting('guided_trial_completed_at', 'not-a-date');
    await database.setAppSetting('guided_trial_app_version', '');

    expect(await repository.getGuidedTrialCompletion(), isNull);
  });

  test('guided trial completion rejects a blank app version', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    expect(
      () => repository.setGuidedTrialCompleted(
        completedAt: DateTime.utc(2026, 7, 26),
        appVersion: '   ',
      ),
      throwsArgumentError,
    );
  });

  test('local app settings persist safety acknowledgement', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    expect(await repository.watchSafetyAcknowledged().first, isFalse);
    expect(await repository.getSafetyAcknowledged(), isFalse);

    await repository.setSafetyAcknowledged(true);

    expect(await repository.watchSafetyAcknowledged().first, isTrue);
    expect(await repository.getSafetyAcknowledged(), isTrue);
  });

  test('local app settings persist onboarding completion', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    expect(await repository.watchOnboardingCompleted().first, isFalse);

    await repository.setOnboardingCompleted(true);

    expect(await repository.watchOnboardingCompleted().first, isTrue);
  });

  test(
    'missing personal setup step is incomplete without completed onboarding',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalAppSettingsRepository(
        database,
        defaultRole: AppDeviceRole.androidPersonal,
      );

      expect(
        await repository.watchPersonalSetupStep().first,
        PersonalSetupStep.chooseNextAction,
      );
    },
  );

  test(
    'legacy completed installs migrate to complete personal setup',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalAppSettingsRepository(
        database,
        defaultRole: AppDeviceRole.androidPersonal,
      );

      await repository.setOnboardingCompleted(true);

      expect(
        await repository.watchPersonalSetupStep().first,
        PersonalSetupStep.complete,
      );
    },
  );

  test('malformed personal setup step is incomplete', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    await database
        .into(database.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            key: 'personal_setup_step_v1',
            value: 'not-a-step',
            updatedAt: DateTime.now().toUtc(),
          ),
        );

    expect(
      await repository.watchPersonalSetupStep().first,
      PersonalSetupStep.chooseNextAction,
    );
  });

  test(
    'beginning personal setup persists resumable choice atomically',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalAppSettingsRepository(
        database,
        defaultRole: AppDeviceRole.androidPersonal,
      );

      await repository.beginPersonalSetup();

      expect(
        await repository.watchPersonalSetupStep().first,
        PersonalSetupStep.chooseNextAction,
      );
      expect(await repository.watchOnboardingCompleted().first, isTrue);
    },
  );

  test('local app settings reset setup state together', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    await repository.setSafetyAcknowledged(true);
    await repository.setOnboardingCompleted(true);
    await repository.setRobotOnboardingStep(
      RobotOnboardingStep.notificationSetup,
    );
    await repository.setClaimedRobotId('robot-17');

    await repository.resetSetupState();

    expect(await repository.watchSafetyAcknowledged().first, isFalse);
    expect(await repository.watchOnboardingCompleted().first, isFalse);
    expect(
      await repository.getRobotOnboardingStep(),
      RobotOnboardingStep.chooseMode,
    );
    expect(await repository.getClaimedRobotId(), isNull);
  });

  test('robot onboarding step and claimed robot survive restart', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final first = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidRobot,
    );

    await first.setRobotOnboardingStep(RobotOnboardingStep.pairing);
    await first.setClaimedRobotId(' robot-17 ');

    final restarted = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidRobot,
    );
    expect(
      await restarted.getRobotOnboardingStep(),
      RobotOnboardingStep.pairing,
    );
    expect(await restarted.getClaimedRobotId(), 'robot-17');
  });

  test('action PIN is disabled by default', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    expect(await repository.watchActionPinEnabled().first, isFalse);
    expect(await repository.verifyActionPin('1234'), isFalse);
  });

  test('action PIN stores verification data without plaintext PIN', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    await repository.setActionPin('1234');

    expect(await repository.watchActionPinEnabled().first, isTrue);
    expect(await repository.verifyActionPin('1234'), isTrue);
    expect(await repository.verifyActionPin('4321'), isFalse);

    final storedSettings = await database.getAppSettings({
      'action_pin_hash',
      'action_pin_salt',
    });
    expect(
      storedSettings.map((setting) => setting.value),
      isNot(contains('1234')),
    );
  });

  test('action PIN rejects non-digit values', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    await expectLater(repository.setActionPin('12a4'), throwsArgumentError);
    await expectLater(repository.setActionPin('12 34'), throwsArgumentError);
    expect(await repository.watchActionPinEnabled().first, isFalse);
  });

  test('action PIN can be cleared', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    await repository.setActionPin('1234');
    await repository.clearActionPin();

    expect(await repository.watchActionPinEnabled().first, isFalse);
    expect(await repository.verifyActionPin('1234'), isFalse);
  });

  test('action PIN lifecycle audits without storing secrets', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );
    const actorType = AdminAuditActorType.localAdmin;

    await repository.setActionPin(
      '1234',
      auditEvent: AdminAuditEvent(
        eventType: AdminAuditEventType.pinEnabled,
        targetType: AdminAuditTargetType.pin,
        actorType: actorType,
        actorLabel: 'local admin',
        sourceDeviceRole: 'androidPersonal',
        summary: 'enabled pin',
        occurredAt: DateTime.utc(2026, 7, 21),
      ),
    );
    await repository.clearActionPin(
      auditEvent: AdminAuditEvent(
        eventType: AdminAuditEventType.pinDisabled,
        targetType: AdminAuditTargetType.pin,
        actorType: actorType,
        actorLabel: 'local admin',
        sourceDeviceRole: 'androidPersonal',
        summary: 'disabled pin',
        occurredAt: DateTime.utc(2026, 7, 21, 0, 0, 1),
      ),
    );

    final rows = await database.select(database.adminAuditEvents).get();
    expect(rows, hasLength(2));
    expect(rows.every((row) => !(row.summary.contains('1234'))), isTrue);
    expect(
      rows.every((row) => !(row.detailsJson ?? '').contains('1234')),
      isTrue,
    );
  });
}
