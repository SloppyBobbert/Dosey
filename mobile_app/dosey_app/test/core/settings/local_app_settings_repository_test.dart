import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local app settings persist safety acknowledgement', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    expect(await repository.watchSafetyAcknowledged().first, isFalse);

    await repository.setSafetyAcknowledged(true);

    expect(await repository.watchSafetyAcknowledged().first, isTrue);
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

  test('local app settings reset setup state together', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    await repository.setSafetyAcknowledged(true);
    await repository.setOnboardingCompleted(true);

    await repository.resetSetupState();

    expect(await repository.watchSafetyAcknowledged().first, isFalse);
    expect(await repository.watchOnboardingCompleted().first, isFalse);
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
      rows.every((row) => (row.detailsJson ?? '').contains('1234')),
      isFalse,
    );
  });
}
