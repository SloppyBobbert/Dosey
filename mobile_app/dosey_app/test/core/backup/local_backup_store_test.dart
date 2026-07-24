import 'dart:io';

import 'package:dosey_app/core/backup/backup_validator.dart';
import 'package:dosey_app/core/backup/backup_codec.dart';
import 'package:dosey_app/core/backup/backup_document.dart';
import 'package:dosey_app/core/backup/local_backup_store.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

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
    expect(
      restored.data['medicationShortageAlerts']!.single['localDeliveryState'],
      'sent',
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

Map<String, List<Map<String, Object?>>> mutableData(BackupDocument document) =>
    {
      for (final entry in document.data.entries)
        entry.key: entry.value.map(Map<String, Object?>.from).toList(),
    };

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
      'isEnabled': true,
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
