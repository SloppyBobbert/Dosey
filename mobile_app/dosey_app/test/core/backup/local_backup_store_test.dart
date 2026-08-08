import 'dart:io';

import 'package:dosey_app/core/backup/backup_validator.dart';
import 'package:dosey_app/core/backup/backup_codec.dart';
import 'package:dosey_app/core/backup/backup_document.dart';
import 'package:dosey_app/core/backup/local_backup_store.dart';
import 'package:dosey_app/core/build/app_build_profile.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/effective_device_role_source.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/common.dart' show SqlError, SqliteException;

void main() {
  test('snapshot includes seeded state but excludes device settings', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final store = LocalBackupStore(database);

    final snapshot = await store.readSnapshot();

    expect(snapshot.data['scheduleProfiles'], hasLength(1));
    expect(snapshot.data['carouselStates'], hasLength(1));
    expect(snapshot.data['settings'], isEmpty);
    expect(const BackupValidator().validate(snapshot), isEmpty);
  });

  test('replacement preserves auth and excluded settings', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final store = LocalBackupStore(database);
    final now = DateTime.utc(2026);
    await database
        .into(database.authSessions)
        .insert(
          AuthSessionsCompanion.insert(
            id: 'current',
            userId: 'user',
            email: 'private@example.com',
            provider: 'google',
            updatedAt: now,
          ),
        );
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: 'action_pin_hash',
            value: 'secret',
            updatedAt: now,
          ),
        );
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: 'profile_display_name',
            value: 'Old',
            updatedAt: now,
          ),
        );
    final source = await store.readSnapshot();
    final data = mutableData(source);
    data['settings'] = [
      {
        'key': 'profile_display_name',
        'value': 'Restored',
        'updatedAt': now.microsecondsSinceEpoch,
      },
    ];

    await database.transaction(
      () => store.replaceSnapshot(BackupDocument(data: data)),
    );

    expect(
      (await database.select(database.authSessions).getSingle()).email,
      'private@example.com',
    );
    final settings = await database.select(database.appSettings).get();
    expect(
      settings.firstWhere((row) => row.key == 'action_pin_hash').value,
      'secret',
    );
    expect(
      settings.firstWhere((row) => row.key == 'profile_display_name').value,
      'Restored',
    );
  });

  test('restored data cannot override either fixed Android profile', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final store = LocalBackupStore(database);
    final settings = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );
    await settings.setDeviceRole(AppDeviceRole.androidRobot);
    final snapshot = await store.readSnapshot();

    await database.transaction(() => store.replaceSnapshot(snapshot));

    expect(await settings.getDeviceRole(), AppDeviceRole.androidRobot);
    expect(
      await EffectiveDeviceRoleSource(
        settings,
        profile: AppBuildProfile.personal,
        platform: AppDevicePlatform.android,
      ).getDeviceRole(),
      AppDeviceRole.androidPersonal,
    );
    expect(
      await EffectiveDeviceRoleSource(
        settings,
        profile: AppBuildProfile.robot,
        platform: AppDevicePlatform.android,
      ).getDeviceRole(),
      AppDeviceRole.androidRobot,
    );
  });

  test(
    'replacement deletes only exact deferred-delete prefix matches',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final store = LocalBackupStore(database);
      const deferredKey = 'deferred_deleted_prescription:rx-old';
      const nearMatchKey = 'deferredXdeletedYprescription:rx-old';
      await database.customStatement(
        'INSERT INTO app_settings (key, value, updated_at) VALUES (?, ?, ?)',
        [deferredKey, 'true', 1],
      );
      await database.customStatement(
        'INSERT INTO app_settings (key, value, updated_at) VALUES (?, ?, ?)',
        [nearMatchKey, 'keep', 1],
      );
      final data = mutableData(await store.readSnapshot())..['settings'] = [];

      await database.transaction(
        () => store.replaceSnapshot(BackupDocument(data: data)),
      );

      final keys = (await database.select(database.appSettings).get())
          .map((row) => row.key)
          .toSet();
      expect(keys, contains(nearMatchKey));
      expect(keys, isNot(contains(deferredKey)));
    },
  );

  test('health reports logical violations without changing rows', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final store = LocalBackupStore(database);
    final now = DateTime.utc(2026);
    await database
        .into(database.prescriptions)
        .insert(
          PrescriptionsCompanion.insert(
            id: 'rx',
            name: 'Test',
            pillType: 'pill',
            remainingDoses: const Value(2),
            availableDoses: const Value(1),
            loadedDoses: const Value(0),
            reviewDoses: const Value(0),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final result = await store.checkHealth();

    expect(result.status, DatabaseHealthStatus.logicalFailure);
    expect(await database.select(database.prescriptions).get(), hasLength(1));
  });

  test('populated snapshot round-trips every included table exactly', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final store = LocalBackupStore(database);
    final source = _populatedDocument();

    await database.transaction(() => store.replaceSnapshot(source));
    final restored = await database.transaction(store.readSnapshot);

    expect(const BackupValidator().validate(restored), isEmpty);
    expect(
      const BackupCodec().encode(restored),
      const BackupCodec().encode(source),
    );
    expect(restored.data['doseLogEvents']!.single['marksDoseTaken'], isFalse);
    expect(restored.data['phoneDoseActionEvents'], hasLength(1));
    expect(restored.data['syncOutboxMutations'], hasLength(1));
    expect(
      restored.data['medicationShortageAlerts']!.single['localDeliveryState'],
      'sent',
    );
  });

  test(
    'schema 18 fixture persists quarantined bound outbox identity exactly',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final store = LocalBackupStore(database);
      final document = const BackupCodec().decode(
        _fixtureBytes('schema18.json'),
      );

      await database.transaction(() => store.replaceSnapshot(document));
      final restored = await store.readSnapshot();
      final outbox = restored.data['syncOutboxMutations']!.single;

      expect(restored.data['prescriptions']!.single['remainingDoses'], 4);
      expect(restored.data['prescriptions']!.single['availableDoses'], 3);
      expect(restored.data['prescriptions']!.single['loadedDoses'], 1);
      expect(restored.data['prescriptions']!.single['reviewDoses'], 0);
      expect(outbox['state'], 'permanent_failure');
      expect(outbox['attemptCount'], 0);
      expect(outbox['nextAttemptAt'], isNull);
      expect(outbox['lastAttemptAt'], isNull);
      expect(outbox['lastErrorCode'], 'restore_review_required');
      expect(outbox['mutationId'], 'bound-flight');
      expect(outbox['deviceId'], 'source-device');
      expect(outbox['actorAccountId'], 'account-fixture');
      expect(outbox['robotId'], 'robot-fixture');
      expect(outbox['scopeState'], 'bound');
      expect(outbox['idempotencyKey'], 'outbox-key-1');
      expect(outbox['entityType'], 'dose_event');
      expect(outbox['operation'], 'append');
      expect(outbox['entityId'], 'action-bound-flight');
      expect(outbox['baseRevision'], isNull);
      expect(
        outbox['payloadJson'],
        contains('schedule-1:1:1970-01-01T00:00:01.000Z'),
      );
    },
  );

  test('replacement deletes stale action and outbox rows', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final store = LocalBackupStore(database);
    final source = _populatedDocument();

    await database.transaction(() => store.replaceSnapshot(source));
    await database.customStatement(
      "INSERT INTO phone_dose_action_events VALUES ('stale-action', 'device-2', 'occurrence-2', 'schedule-1', 1, 1, '2026-01-02', 'UTC', 'rx-1', 'missed', 1, 0, 'stale-action-key', 1)",
    );
    await database.customStatement(
      "INSERT INTO sync_outbox_mutations VALUES ('stale-mutation', 'device-2', NULL, NULL, 'local_only', 'stale-mutation-key', 'action', 'upsert', 'stale-action', NULL, '{}', 'pending', 0, NULL, NULL, NULL, 1, 1)",
    );

    await database.transaction(() => store.replaceSnapshot(source));

    expect(
      (await database.select(database.phoneDoseActionEvents).get()).map(
        (row) => row.id,
      ),
      ['action-1'],
    );
    expect(
      (await database.select(database.syncOutboxMutations).get()).map(
        (row) => row.mutationId,
      ),
      ['mutation-1'],
    );
  });

  test('duplicate taken replacement rolls back current action rows', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final store = LocalBackupStore(
      database,
      validator: const _TestOnlyPermissiveBackupValidator(),
    );
    final original = _populatedDocument();
    await store.replaceSnapshot(original);
    final before = const BackupCodec().encode(await store.readSnapshot());
    final duplicateData = mutableData(original);
    duplicateData['phoneDoseActionEvents']!.single
      ..['kind'] = 'taken_confirmed'
      ..['marksDoseTaken'] = true
      ..['occurrenceId'] = 'occurrence-1';
    duplicateData['phoneDoseActionEvents']!.add({
      'id': 'action-2',
      'deviceId': 'device-2',
      'occurrenceId': 'occurrence-1',
      'scheduleId': 'schedule-1',
      'scheduleRevision': 1,
      'scheduledAt': 1767225600000000,
      'localDate': '1969-12-31',
      'timezoneId': 'America/Los_Angeles',
      'medicationId': 'rx-1',
      'kind': 'taken_confirmed',
      'occurredAt': 1767225600000000,
      'marksDoseTaken': true,
      'idempotencyKey': 'action-key-2',
      'createdAt': 1767225600000000,
    });

    await expectLater(
      store.replaceSnapshot(BackupDocument(data: duplicateData)),
      throwsA(
        isA<SqliteException>().having(
          (error) => error.resultCode,
          'resultCode',
          SqlError.SQLITE_CONSTRAINT,
        ),
      ),
    );
    final after = const BackupCodec().encode(await store.readSnapshot());
    expect(after, before);
  });

  test('on-disk current-format restore persists after reopening', () async {
    final directory = await Directory.systemTemp.createTemp(
      'dosey-backup-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/dosey.sqlite');
    var database = DoseyDatabase(NativeDatabase(file));
    addTearDown(() => database.close());
    final source = _populatedDocument();
    final currentFormat = const BackupCodec().decode(
      const BackupCodec().encode(source),
    );

    await database.transaction(
      () => LocalBackupStore(database).replaceSnapshot(currentFormat),
    );
    await database.close();
    database = DoseyDatabase(NativeDatabase(file));
    final reopenedStore = LocalBackupStore(database);
    final restored = await reopenedStore.readSnapshot();

    expect(
      const BackupCodec().encode(restored),
      const BackupCodec().encode(source),
    );
    expect(
      (await reopenedStore.checkHealth()).status,
      DatabaseHealthStatus.healthy,
    );
  });

  test('replacement submits deletes and inserts as one Drift batch', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final store = LocalBackupStore(database);
    final interceptor = _BatchCountingInterceptor();

    await database.runWithInterceptor(
      () => database.transaction(
        () => store.replaceSnapshot(_populatedDocument()),
      ),
      interceptor: interceptor,
    );

    expect(interceptor.batchCalls, 1);
  });

  test('replacement invalidates streams for every restored table', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final store = LocalBackupStore(database);
    await store.readSnapshot();
    final updates = database.tableUpdates().first.timeout(
      const Duration(seconds: 1),
    );

    await database.transaction(
      () => store.replaceSnapshot(_populatedDocument()),
    );

    expect(
      (await updates).map((update) => update.table),
      unorderedEquals(const {
        'app_settings',
        'schedule_profiles',
        'prescriptions',
        'prescription_refills',
        'reminder_schedules',
        'carousel_slots',
        'carousel_load_sessions',
        'carousel_load_slot_snapshots',
        'carousel_states',
        'medication_shortage_alerts',
        'dose_log_events',
        'controller_command_sessions',
        'controller_command_events',
        'admin_audit_events',
        'phone_dose_action_events',
        'sync_outbox_mutations',
      }),
    );
  });

  test('on-disk health check detects an unreadable database file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'dosey-backup-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/dosey.sqlite');
    var database = DoseyDatabase(NativeDatabase(file));

    expect(
      (await LocalBackupStore(database).checkHealth()).status,
      DatabaseHealthStatus.healthy,
    );
    await database.close();
    await file.writeAsBytes(List<int>.filled(4096, 0x5A), flush: true);
    database = DoseyDatabase(NativeDatabase(file));
    addTearDown(database.close);

    expect(
      (await LocalBackupStore(database).checkHealth()).status,
      isNot(DatabaseHealthStatus.healthy),
    );
  });
}

class _BatchCountingInterceptor extends QueryInterceptor {
  int batchCalls = 0;

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) {
    batchCalls++;
    return executor.runBatched(statements);
  }
}

/// Test-only bypass that lets SQLite enforce the malformed payload constraint.
class _TestOnlyPermissiveBackupValidator extends BackupValidator {
  const _TestOnlyPermissiveBackupValidator();

  @override
  void validateOrThrow(BackupDocument document) {}
}

Map<String, List<Map<String, Object?>>> mutableData(BackupDocument document) =>
    {
      for (final entry in document.data.entries)
        entry.key: entry.value.map(Map<String, Object?>.from).toList(),
    };

Uint8List _fixtureBytes(String name) => Uint8List.fromList(
  File('test/core/backup/fixtures/$name').readAsBytesSync(),
);

BackupDocument _populatedDocument() {
  const time = 1000000;
  final data = BackupDocument.emptyData();
  data['settings'] = [
    {'key': 'profile_display_name', 'value': 'Alex', 'updatedAt': time},
  ];
  data['scheduleProfiles'] = [
    {
      'id': 'profile-1',
      'name': 'Every day',
      'isActive': true,
      'createdAt': time,
      'updatedAt': time,
    },
  ];
  data['prescriptions'] = [
    {
      'id': 'rx-1',
      'name': 'Vitamin',
      'pillType': 'tablet',
      'remainingDoses': 5,
      'guidedPillIcon': 'roundPill',
      'availableDoses': 3,
      'loadedDoses': 1,
      'usedDoses': 7,
      'reviewDoses': 1,
      'defaultRefillQuantity': 30,
      'defaultDoseCountPerDose': 1,
      'doseInstructions': 'With water',
      'refillThreshold': 3,
      'createdAt': time,
      'updatedAt': time,
    },
  ];
  data['prescriptionRefills'] = [
    {
      'id': 'refill-1',
      'prescriptionId': 'rx-1',
      'doseDelta': 30,
      'remainingAfter': 30,
      'occurredAt': time,
      'note': 'Local refill',
    },
  ];
  data['reminderSchedules'] = [
    {
      'id': 'schedule-1',
      'label': 'Morning',
      'prescriptionId': 'rx-1',
      'profileId': 'profile-1',
      'hour': 8,
      'minute': 15,
      'revision': 1,
      'isEnabled': true,
      'createdAt': time,
      'updatedAt': time,
    },
  ];
  data['phoneDoseActionEvents'] = [
    {
      'id': 'action-1',
      'deviceId': 'device-1',
      'occurrenceId': 'schedule-1:1:1970-01-01T00:00:01.000Z',
      'scheduleId': 'schedule-1',
      'scheduleRevision': 1,
      'scheduledAt': time,
      'localDate': '1969-12-31',
      'timezoneId': 'America/Los_Angeles',
      'medicationId': 'rx-1',
      'kind': 'snoozed',
      'occurredAt': time,
      'marksDoseTaken': false,
      'idempotencyKey': 'mutation-key-1',
      'createdAt': time,
    },
  ];
  data['syncOutboxMutations'] = [
    {
      'mutationId': 'mutation-1',
      'deviceId': 'device-1',
      'actorAccountId': null,
      'robotId': null,
      'scopeState': 'local_only',
      'idempotencyKey': 'mutation-key-1',
      'entityType': 'dose_event',
      'operation': 'append',
      'entityId': 'action-1',
      'baseRevision': null,
      'payloadJson':
          '{"medicationId":"rx-1","profileId":"profile-1","kind":"snoozed","occurredAt":"1970-01-01T00:00:01.000Z","occurrence":{"occurrenceId":"schedule-1:1:1970-01-01T00:00:01.000Z","scheduleId":"schedule-1","scheduleRevision":1,"scheduledAtUtc":"1970-01-01T00:00:01.000Z","localDate":"1969-12-31","timezoneId":"America/Los_Angeles"}}',
      'state': 'pending',
      'attemptCount': 0,
      'nextAttemptAt': null,
      'lastAttemptAt': null,
      'lastErrorCode': null,
      'createdAt': time,
      'updatedAt': time,
    },
  ];
  data['carouselSlots'] = [
    {
      'id': 'slot-1',
      'slotNumber': 1,
      'prescriptionId': 'rx-1',
      'scheduleId': 'schedule-1',
      'profileId': 'profile-1',
      'status': 'needs_review',
      'createdAt': time,
      'updatedAt': time,
    },
  ];
  data['carouselLoadSessions'] = [
    {
      'id': 'load-1',
      'profileId': 'profile-1',
      'mode': 'full_load',
      'status': 'confirmed',
      'predecessorSessionId': null,
      'planCreatedAt': time,
      'startedAt': time,
      'confirmedAt': time,
      'staleAt': null,
      'staleReason': null,
      'supersededAt': null,
      'supersededReason': null,
      'positionBefore': 0,
      'positionAfter': 1,
      'createdAt': time,
      'updatedAt': time,
    },
  ];
  data['carouselLoadSlotSnapshots'] = [
    {
      'id': 'snapshot-1',
      'sessionId': 'load-1',
      'slotNumber': 1,
      'status': 'needs_review',
      'scheduledAt': time,
      'bundleKey': 'schedule-1',
      'scheduleIdsJson': '["schedule-1"]',
      'prescriptionIdsJson': '["rx-1"]',
      'prescriptionNamesJson': '["Vitamin"]',
      'pillIconsJson': '["roundPill"]',
      'doseInstructionsJson': '["With water"]',
      'loadedAt': time,
      'movedAt': time,
      'resolvedAt': null,
      'reviewReason': 'disconnect',
      'createdAt': time,
    },
  ];
  data['carouselStates'] = [
    {
      'profileId': 'profile-1',
      'activeLoadSessionId': 'load-1',
      'currentPosition': 1,
      'updatedAt': time,
    },
  ];
  data['medicationShortageAlerts'] = [
    {
      'id': 'shortage-1',
      'profileId': 'profile-1',
      'loadSessionId': 'load-1',
      'slotNumber': 1,
      'bundleKey': 'schedule-1',
      'scheduledAt': time,
      'prescriptionIdsJson': '["rx-1"]',
      'prescriptionNamesJson': '["Vitamin"]',
      'status': 'active',
      'recognizedAt': null,
      'resolvedAt': null,
      'resolution': null,
      'intendedAudience': 'household',
      'localDeliveryState': 'sent',
      'localNotificationSentAt': time,
      'remoteDeliveryState': 'not_configured',
      'createdAt': time,
      'updatedAt': time,
    },
  ];
  data['doseLogEvents'] = [
    {
      'id': 'dose-event-1',
      'kind': 'controllerDispenseSucceeded',
      'doseId': 'dose-1',
      'occurredAt': time,
      'marksDoseTaken': false,
    },
  ];
  data['controllerCommandSessions'] = [
    {
      'id': 'command-1',
      'commandType': 'dispenseNext',
      'doseId': 'dose-1',
      'scheduleId': 'schedule-1',
      'slotId': 'slot-1',
      'state': 'succeeded',
      'failureReason': null,
      'createdAt': time,
      'acceptedAt': time,
      'resolvedAt': time,
      'updatedAt': time,
    },
  ];
  data['controllerCommandEvents'] = [
    {
      'id': 'command-event-1',
      'sessionId': 'command-1',
      'sequence': 1,
      'eventType': 'servoDone',
      'occurredAt': time,
      'details': 'movement only',
    },
  ];
  data['adminAuditEvents'] = [
    {
      'id': 'audit-1',
      'eventType': 'guidedLoadConfirmed',
      'targetType': 'carouselLoadSession',
      'targetId': 'load-1',
      'actorType': 'localAdmin',
      'actorUserId': null,
      'actorLabel': 'local admin',
      'sourceDeviceRole': 'android_personal',
      'summary': 'Confirmed guided load.',
      'detailsJson': '{"state":"kept"}',
      'cloudEventId': null,
      'lastSyncedAt': null,
      'occurredAt': time,
    },
  ];
  return BackupDocument(data: data);
}
