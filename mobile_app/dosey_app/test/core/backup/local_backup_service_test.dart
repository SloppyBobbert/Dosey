import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

import 'package:dosey_app/core/backup/backup_codec.dart';
import 'package:dosey_app/core/backup/backup_document.dart';
import 'package:dosey_app/core/backup/backup_file_gateway.dart';
import 'package:dosey_app/core/backup/local_backup_service.dart';
import 'package:dosey_app/core/backup/local_backup_store.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule_service.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invalid import is rejected before recovery is written', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final gateway = _FakeGateway()..picked = Uint8List.fromList([1, 2, 3]);
    final service = LocalBackupService(
      database: database,
      store: LocalBackupStore(database),
      gateway: gateway,
    );

    final result = await service.pickBackupForRestore();

    expect(result.status, BackupOperationStatus.invalidBackup);
    expect(gateway.recoveryWrites, 0);
  });

  test('restore rejects a valid document paired with invalid bytes', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await database.customStatement(
      "INSERT INTO app_settings (key, value, updated_at) VALUES ('profile_display_name', 'Before', 1)",
    );
    final store = LocalBackupStore(database);
    final valid = await store.readSnapshot();
    final gateway = _FakeGateway();
    final service = LocalBackupService(
      database: database,
      store: store,
      gateway: gateway,
    );

    final result = await service.restore(
      BackupPreview(valid, Uint8List.fromList([1, 2, 3])),
    );

    expect(result.status, BackupOperationStatus.invalidBackup);
    expect(gateway.recoveryWrites, 0);
    expect(
      (await store.readSnapshot()).data['settings']!.single['value'],
      'Before',
    );
  });

  test('unsupported fixture schema is rejected before replacement', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await database.customStatement(
      "INSERT INTO app_settings (key, value, updated_at) VALUES ('profile_display_name', 'Before', 1)",
    );
    final payload =
        jsonDecode(utf8.decode(_fixtureBytes('schema18.json')))
            as Map<String, Object?>;
    payload['sourceSchemaVersion'] = 16;
    final gateway = _FakeGateway()
      ..picked = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
    final service = LocalBackupService(
      database: database,
      store: LocalBackupStore(database),
      gateway: gateway,
    );

    final result = await service.pickBackupForRestore();

    expect(result.status, BackupOperationStatus.invalidBackup);
    expect(gateway.recoveryWrites, 0);
    expect(
      (await LocalBackupStore(
        database,
      ).readSnapshot()).data['settings']!.single['value'],
      'Before',
    );
  });

  test(
    'schema 17 fixture restores normalized outbox without changing inventory',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      List<ReminderScheduleRow>? schedulesSeenBySync;
      final gateway = _FakeGateway()..picked = _fixtureBytes('schema17.json');
      final service = LocalBackupService(
        database: database,
        store: LocalBackupStore(database),
        gateway: gateway,
        syncNotifications: () async {
          schedulesSeenBySync = await database
              .select(database.reminderSchedules)
              .get();
        },
      );

      final preview = await service.pickBackupForRestore();
      final result = await service.restore(preview.preview!);
      final snapshot = await LocalBackupStore(database).readSnapshot();
      final outbox = {
        for (final row in snapshot.data['syncOutboxMutations']!)
          row['mutationId'] as String: row,
      };

      expect(result.status, BackupOperationStatus.success);
      expect(schedulesSeenBySync!.single.id, 'schedule-1');
      expect(snapshot.data['prescriptions']!.single['remainingDoses'], 4);
      expect(snapshot.data['prescriptions']!.single['availableDoses'], 3);
      expect(snapshot.data['prescriptions']!.single['loadedDoses'], 1);
      expect(snapshot.data['prescriptions']!.single['reviewDoses'], 0);
      expect(outbox['local-flight']!['state'], 'pending');
      expect(outbox['bound-flight']!['state'], 'permanent_failure');
      expect(
        outbox['bound-flight']!['lastErrorCode'],
        'restore_review_required',
      );
      expect(outbox['bound-flight']!['mutationId'], 'bound-flight');
      expect(outbox['bound-flight']!['deviceId'], 'source-device');
      expect(outbox['bound-flight']!['actorAccountId'], 'account-fixture');
      expect(outbox['bound-flight']!['robotId'], 'robot-fixture');
      expect(outbox['bound-flight']!['idempotencyKey'], 'outbox-key-4');
      expect(outbox['bound-flight']!['entityId'], 'action-bound-flight');
      expect(
        outbox['bound-flight']!['payloadJson'],
        contains('schedule-1:1:1970-01-01T00:00:01.000Z'),
      );
    },
  );

  test(
    'restore quarantines a direct preview with replay-eligible bound work',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final unsafe = _fixtureDocument('schema18.json');
      final bytes = const BackupCodec().encode(unsafe);
      final service = LocalBackupService(
        database: database,
        store: LocalBackupStore(database),
        gateway: _FakeGateway(),
      );

      final result = await service.restore(BackupPreview(unsafe, bytes));
      final outbox = (await LocalBackupStore(
        database,
      ).readSnapshot()).data['syncOutboxMutations']!.single;

      expect(result.status, BackupOperationStatus.success);
      expect(outbox['state'], 'permanent_failure');
      expect(outbox['lastErrorCode'], 'restore_review_required');
    },
  );

  test('restore writes verified recovery and replaces atomically', () async {
    final sourceDatabase = DoseyDatabase.inMemory();
    await sourceDatabase.customStatement(
      "INSERT INTO app_settings (key, value, updated_at) VALUES ('profile_display_name', 'Source', 1)",
    );
    final source = await LocalBackupStore(sourceDatabase).readSnapshot();
    await sourceDatabase.close();
    final destinationDatabase = DoseyDatabase.inMemory();
    addTearDown(destinationDatabase.close);
    final gateway = _FakeGateway()..picked = const BackupCodec().encode(source);
    var notificationSyncs = 0;
    final service = LocalBackupService(
      database: destinationDatabase,
      store: LocalBackupStore(destinationDatabase),
      gateway: gateway,
      syncNotifications: () async => notificationSyncs++,
    );

    final preview = await service.pickBackupForRestore();
    final result = await service.restore(preview.preview!);

    expect(result.status, BackupOperationStatus.success);
    expect(gateway.recoveryWrites, 1);
    expect(notificationSyncs, 1);
    expect(
      (await LocalBackupStore(
        destinationDatabase,
      ).readSnapshot()).data['settings']!.single['value'],
      'Source',
    );
  });

  test('notification failure warns after committed restore', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final store = LocalBackupStore(database);
    final gateway = _FakeGateway();
    final source = await store.readSnapshot();
    final service = LocalBackupService(
      database: database,
      store: store,
      gateway: gateway,
      syncNotifications: () async => throw StateError('platform unavailable'),
    );

    final result = await service.restore(
      BackupPreview(source, const BackupCodec().encode(source)),
    );

    expect(result.status, BackupOperationStatus.successWithNotificationWarning);
  });

  test('restore commits before independent notification reconciliation', () async {
    final sourceDatabase = DoseyDatabase.inMemory();
    await sourceDatabase.customStatement(
      "INSERT INTO reminder_schedules (id, label, profile_id, hour, minute, is_enabled, created_at, updated_at) VALUES ('enabled-schedule', 'Restored enabled', 'schedule-1', 9, 45, 1, 1, 1)",
    );
    await sourceDatabase.customStatement(
      "INSERT INTO reminder_schedules (id, label, profile_id, hour, minute, is_enabled, created_at, updated_at) VALUES ('disabled-schedule', 'Restored disabled', 'schedule-1', 12, 0, 0, 1, 1)",
    );
    final source = await LocalBackupStore(sourceDatabase).readSnapshot();
    await sourceDatabase.close();
    final directory = await Directory.systemTemp.createTemp(
      'dosey-backup-service-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/dosey.sqlite');
    final destinationDatabase = DoseyDatabase(NativeDatabase(file));
    addTearDown(destinationDatabase.close);
    final notificationDatabase = DoseyDatabase(NativeDatabase(file));
    addTearDown(notificationDatabase.close);
    await destinationDatabase.customStatement(
      "INSERT INTO reminder_schedules (id, label, profile_id, hour, minute, is_enabled, created_at, updated_at) VALUES ('stale-database-schedule', 'Stale database', 'schedule-1', 7, 30, 1, 1, 1)",
    );
    expect(
      (await notificationDatabase
              .select(notificationDatabase.reminderSchedules)
              .get())
          .map((schedule) => schedule.id),
      ['stale-database-schedule'],
    );
    final scheduler = _ReconciliationScheduler()
      ..activeReminders['enabled-schedule'] = _ReminderNotification(
        label: 'Stale enabled',
        scheduledFor: DateTime(2026, 6, 29, 8),
      )
      ..activeReminders['disabled-schedule'] = _ReminderNotification(
        label: 'Stale disabled',
        scheduledFor: DateTime(2026, 6, 29, 12),
      );
    final reminders = ReminderScheduleService(
      repository: LocalReminderRepository(notificationDatabase),
      scheduler: scheduler,
      now: () => DateTime(2026, 6, 29, 7, 15),
    );
    List<ReminderScheduleRow>? schedulesAtReconciliation;
    final service = LocalBackupService(
      database: destinationDatabase,
      store: LocalBackupStore(destinationDatabase),
      gateway: _FakeGateway(),
      syncNotifications: () async {
        schedulesAtReconciliation = await notificationDatabase
            .select(notificationDatabase.reminderSchedules)
            .get();
        await reminders.syncScheduledNotifications();
      },
    );

    final result = await service.restore(
      BackupPreview(source, const BackupCodec().encode(source)),
    );

    expect(result.status, BackupOperationStatus.success);
    expect(
      schedulesAtReconciliation!.map((schedule) => schedule.id),
      unorderedEquals(['enabled-schedule', 'disabled-schedule']),
    );
    expect(scheduler.cancelledDoseIds, ['disabled-schedule']);
    expect(scheduler.activeReminders, {
      'enabled-schedule': _ReminderNotification(
        label: 'Restored enabled',
        scheduledFor: DateTime(2026, 6, 29, 9, 45),
      ),
    });
  });

  test('restore accepts valid non-canonical JSON', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final store = LocalBackupStore(database);
    final document = await store.readSnapshot();
    final nonCanonicalBytes = Uint8List.fromList(
      utf8.encode(
        const JsonEncoder.withIndent('  ').convert(
          jsonDecode(utf8.decode(const BackupCodec().encode(document))),
        ),
      ),
    );
    final gateway = _FakeGateway()..picked = nonCanonicalBytes;
    final service = LocalBackupService(
      database: database,
      store: store,
      gateway: gateway,
    );

    final preview = await service.pickBackupForRestore();
    final result = await service.restore(preview.preview!);

    expect(result.status, BackupOperationStatus.success);
  });

  test('recovery write failure prevents replacement', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final store = LocalBackupStore(database);
    final source = await store.readSnapshot();
    final gateway = _FakeGateway()..failRecoveryWrite = true;
    final service = LocalBackupService(
      database: database,
      store: store,
      gateway: gateway,
    );

    final result = await service.restore(
      BackupPreview(source, const BackupCodec().encode(source)),
    );

    expect(result.status, BackupOperationStatus.recoveryFailure);
  });

  test(
    'invalid recovery snapshot prevents recovery write and replacement',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final normalStore = LocalBackupStore(database);
      final target = await normalStore.readSnapshot();
      final gateway = _FakeGateway();
      final service = LocalBackupService(
        database: database,
        store: _InvalidSnapshotStore(database),
        gateway: gateway,
      );

      final result = await service.restore(
        BackupPreview(target, const BackupCodec().encode(target)),
      );

      expect(result.status, BackupOperationStatus.recoveryFailure);
      expect(gateway.recoveryWrites, 0);
      expect((await normalStore.readSnapshot()).data, target.data);
    },
  );

  test('replacement failure rolls back database changes', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await database.customStatement(
      "INSERT INTO app_settings (key, value, updated_at) VALUES ('profile_display_name', 'Before', 1)",
    );
    final normalStore = LocalBackupStore(database);
    final source = await normalStore.readSnapshot();
    final gateway = _FakeGateway();
    var notificationSyncs = 0;
    final service = LocalBackupService(
      database: database,
      store: _FailingReplacementStore(database),
      gateway: gateway,
      syncNotifications: () async => notificationSyncs++,
    );

    final result = await service.restore(
      BackupPreview(source, const BackupCodec().encode(source)),
    );

    expect(result.status, BackupOperationStatus.restoreRolledBack);
    expect(gateway.recoveryWrites, 1);
    expect(notificationSyncs, 0);
    expect(
      (await normalStore.readSnapshot()).data['settings']!.single['value'],
      'Before',
    );
  });

  test(
    'database change during recovery write aborts restore without loss',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await database.customStatement(
        "INSERT INTO app_settings (key, value, updated_at) VALUES ('profile_display_name', 'Before', 1)",
      );
      final store = LocalBackupStore(database);
      final targetData =
          {
              for (final entry in (await store.readSnapshot()).data.entries)
                entry.key: entry.value.map(Map<String, Object?>.from).toList(),
            }
            ..['settings'] = [
              {
                'key': 'profile_display_name',
                'value': 'Target',
                'updatedAt': 1000000,
              },
            ];
      final target = BackupDocument(data: targetData);
      final gateway = _FakeGateway()
        ..onWriteRecovery = () => database.customStatement(
          "UPDATE app_settings SET value = 'During' WHERE key = 'profile_display_name'",
        );
      final service = LocalBackupService(
        database: database,
        store: store,
        gateway: gateway,
      );

      final result = await service.restore(
        BackupPreview(target, const BackupCodec().encode(target)),
      );

      expect(result.status, BackupOperationStatus.restoreRolledBack);
      expect(
        (await database.select(database.appSettings).get())
            .firstWhere((row) => row.key == 'profile_display_name')
            .value,
        'During',
      );
    },
  );
}

Uint8List _fixtureBytes(String name) => Uint8List.fromList(
  File('test/core/backup/fixtures/$name').readAsBytesSync(),
);

BackupDocument _fixtureDocument(String name) {
  final payload = jsonDecode(utf8.decode(_fixtureBytes(name))) as Map;
  final rawData = payload['data'] as Map;
  return BackupDocument(
    data: {
      for (final entry in rawData.entries)
        entry.key as String: (entry.value as List)
            .map((row) => Map<String, Object?>.from(row as Map))
            .toList(),
    },
  );
}

class _FailingReplacementStore extends LocalBackupStore {
  _FailingReplacementStore(super.database);

  @override
  Future<void> replaceSnapshot(BackupDocument snapshot) async {
    await database.customStatement(
      "DELETE FROM app_settings WHERE key = 'profile_display_name'",
    );
    throw StateError('simulated insert failure');
  }
}

class _InvalidSnapshotStore extends LocalBackupStore {
  _InvalidSnapshotStore(super.database);

  @override
  Future<DatabaseHealthResult> checkHealth() async =>
      const DatabaseHealthResult(DatabaseHealthStatus.healthy);

  @override
  Future<BackupDocument> readSnapshot() async => BackupDocument.empty();
}

class _FakeGateway implements BackupFileGateway {
  Uint8List? picked;
  Uint8List? recovery;
  int recoveryWrites = 0;
  bool failRecoveryWrite = false;
  Future<void> Function()? onWriteRecovery;

  @override
  Future<bool> hasRecovery() async => recovery != null;
  @override
  Future<Uint8List?> pickImportBytes() async => picked;
  @override
  Future<Uint8List?> readRecovery() async => recovery;
  @override
  Future<BackupShareResult> shareExport({
    required Uint8List bytes,
    required String filename,
  }) async => BackupShareResult.completed;
  @override
  Future<void> writeRecovery(Uint8List bytes) async {
    recoveryWrites++;
    if (failRecoveryWrite) throw const FileSystemException('disk full');
    recovery = Uint8List.fromList(bytes);
    await onWriteRecovery?.call();
  }
}

class _ReconciliationScheduler implements ReminderScheduler {
  final activeReminders = <String, _ReminderNotification>{};
  final cancelledDoseIds = <String>[];

  @override
  Future<void> cancelDoseReminder(String doseId) async {
    cancelledDoseIds.add(doseId);
    activeReminders.remove(doseId);
  }

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> scheduleDoseReminder({
    required String doseId,
    required DateTime scheduledFor,
    required String label,
    required bool repeatsDaily,
  }) async {
    activeReminders[doseId] = _ReminderNotification(
      label: label,
      scheduledFor: scheduledFor,
    );
  }
}

class _ReminderNotification {
  const _ReminderNotification({
    required this.label,
    required this.scheduledFor,
  });

  final String label;
  final DateTime scheduledFor;

  @override
  bool operator ==(Object other) {
    return other is _ReminderNotification &&
        other.label == label &&
        other.scheduledFor == scheduledFor;
  }

  @override
  int get hashCode => Object.hash(label, scheduledFor);
}
