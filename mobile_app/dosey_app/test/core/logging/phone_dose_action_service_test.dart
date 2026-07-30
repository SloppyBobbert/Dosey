import 'dart:convert';
import 'dart:io';

import 'package:dosey_app/core/logging/phone_dose_action_service.dart';
import 'package:dosey_app/core/reminders/reminder_occurrence.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/sync/domain_contracts.dart';
import 'package:dosey_app/core/sync/sync_outbox_serializer.dart';
import 'package:dosey_app/core/sync/sync_outbox_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' show Database;

void main() {
  late DoseyDatabase database;
  late PhoneDoseActionService service;
  late ReminderOccurrence occurrence;

  setUp(() {
    database = DoseyDatabase.inMemory();
    service = PhoneDoseActionService(database);
    occurrence = ReminderOccurrence(
      scheduleId: 'schedule-1',
      scheduleRevision: 3,
      scheduledAt: DateTime.utc(2026, 7, 30, 15),
      localDate: '2026-07-30',
      timezoneId: 'America/Los_Angeles',
    );
  });

  tearDown(() => database.close());

  test(
    'explicit taken writes one local event and one pending mutation',
    () async {
      final result = await service.record(
        PhoneDoseActionRequest(
          occurrence: occurrence,
          medicationId: 'medication-1',
          kind: PhoneDoseActionKind.takenConfirmed,
          occurredAt: DateTime.utc(2026, 7, 30, 15, 2),
          deviceId: 'device-1',
        ),
      );

      final events = await database
          .select(database.phoneDoseActionEvents)
          .get();
      final mutations = await database
          .select(database.syncOutboxMutations)
          .get();
      final legacyEvents = await database.select(database.doseLogEvents).get();

      expect(result.inserted, isTrue);
      expect(events.single.kind, 'taken_confirmed');
      expect(events.single.marksDoseTaken, isTrue);
      expect(mutations.single.state, 'pending');
      expect(mutations.single.scopeState, 'local_only');
      expect(mutations.single.actorAccountId, isNull);
      expect(mutations.single.robotId, isNull);
      expect(mutations.single.payloadJson, contains('"occurrenceId"'));
      expect(mutations.single.mutationId.length, lessThanOrEqualTo(64));
      expect(mutations.single.idempotencyKey.length, lessThanOrEqualTo(64));
      expect(events.single.id.length, lessThanOrEqualTo(64));
      expect(legacyEvents.single.marksDoseTaken, isTrue);
      final operation = SyncOutboxSerializer.toMutationJson(mutations.single);
      expect(operation['contractVersion'], 1);
      expect(operation['mutationId'], mutations.single.mutationId);
      expect(operation['deviceId'], 'device-1');
      expect(operation['idempotencyKey'], mutations.single.idempotencyKey);
      expect(operation['entityType'], 'dose_event');
      expect(operation['operation'], 'append');
      expect(operation['entityId'], events.single.id);
      expect(operation['baseRevision'], isNull);
      final payload = operation['payload'] as Map;
      expect(payload.keys, [
        'medicationId',
        'occurrence',
        'kind',
        'occurredAt',
      ]);
      expect((payload['occurrence'] as Map)['contractVersion'], 1);
      final parsedMutation = MutationContract.fromJson(operation);
      expect(parsedMutation.toJson(), operation);

      final pushRequest = SyncOutboxSerializer.toPushRequestJson(
        robotId: 'robot-1',
        mutations: mutations,
      );
      expect(pushRequest, {
        'contractVersion': 1,
        'robotId': 'robot-1',
        'operations': [operation],
      });
      final parsedPushRequest = MedicationSyncPushRequest.fromJson(pushRequest);
      expect(parsedPushRequest.toJson(), pushRequest);
    },
  );

  test(
    'bound sync scope is captured immutably when action is enqueued',
    () async {
      await service.record(
        PhoneDoseActionRequest(
          occurrence: occurrence,
          medicationId: 'medication-1',
          kind: PhoneDoseActionKind.helpRequested,
          occurredAt: DateTime.utc(2026, 7, 30, 15, 2),
          deviceId: 'device-1',
          syncScope: SyncOutboxScope(
            actorAccountId: ' account-1 ',
            robotId: ' robot-1 ',
          ),
        ),
      );

      final mutation = await database
          .select(database.syncOutboxMutations)
          .getSingle();
      expect(mutation.scopeState, 'bound');
      expect(mutation.actorAccountId, 'account-1');
      expect(mutation.robotId, 'robot-1');
      expect(
        SyncOutboxSerializer.toMutationJson(mutation),
        isNot(contains('actorAccountId')),
      );
    },
  );

  test('duplicate tap and restart reuse the original event', () async {
    final request = PhoneDoseActionRequest(
      occurrence: occurrence,
      medicationId: 'medication-1',
      kind: PhoneDoseActionKind.skipped,
      occurredAt: DateTime.utc(2026, 7, 30, 15, 2),
      deviceId: 'device-1',
    );

    final first = await service.record(request);
    final afterRestart = await PhoneDoseActionService(database).record(
      PhoneDoseActionRequest(
        occurrence: occurrence,
        medicationId: 'medication-1',
        kind: PhoneDoseActionKind.skipped,
        occurredAt: DateTime.utc(2026, 7, 30, 15, 3),
        deviceId: 'device-1',
      ),
    );

    expect(first.inserted, isTrue);
    expect(afterRestart.inserted, isFalse);
    expect(afterRestart.eventId, first.eventId);
    expect(
      await database.select(database.phoneDoseActionEvents).get(),
      hasLength(1),
    );
    expect(
      await database.select(database.syncOutboxMutations).get(),
      hasLength(1),
    );
  });

  test(
    'a different terminal action conflicts for one device occurrence',
    () async {
      await service.record(
        PhoneDoseActionRequest(
          occurrence: occurrence,
          medicationId: 'medication-1',
          kind: PhoneDoseActionKind.skipped,
          occurredAt: DateTime.utc(2026, 7, 30, 15, 2),
          deviceId: 'device-1',
        ),
      );

      expect(
        () => service.record(
          PhoneDoseActionRequest(
            occurrence: occurrence,
            medicationId: 'medication-1',
            kind: PhoneDoseActionKind.takenConfirmed,
            occurredAt: DateTime.utc(2026, 7, 30, 15, 3),
            deviceId: 'device-1',
          ),
        ),
        throwsA(isA<PhoneDoseTerminalConflict>()),
      );
      expect(
        (await database.select(database.phoneDoseActionEvents).get()).map(
          (event) => event.kind,
        ),
        ['skipped'],
      );
    },
  );

  test('terminal classification excludes an unacknowledged miss', () {
    expect(PhoneDoseActionKind.takenConfirmed.isTerminal, isTrue);
    expect(PhoneDoseActionKind.skipped.isTerminal, isTrue);
    expect(PhoneDoseActionKind.missedAcknowledged.isTerminal, isTrue);
    expect(PhoneDoseActionKind.missed.isTerminal, isFalse);
    expect(PhoneDoseActionKind.snoozed.isTerminal, isFalse);
    expect(PhoneDoseActionKind.helpRequested.isTerminal, isFalse);
  });

  test('terminal outcomes are isolated by device', () async {
    await service.record(
      PhoneDoseActionRequest(
        occurrence: occurrence,
        medicationId: 'medication-1',
        kind: PhoneDoseActionKind.skipped,
        occurredAt: DateTime.utc(2026, 7, 30, 15, 2),
        deviceId: 'device-1',
      ),
    );

    final result = await service.record(
      PhoneDoseActionRequest(
        occurrence: occurrence,
        medicationId: 'medication-1',
        kind: PhoneDoseActionKind.takenConfirmed,
        occurredAt: DateTime.utc(2026, 7, 30, 15, 3),
        deviceId: 'device-2',
      ),
    );

    expect(result.inserted, isTrue);
    expect(
      await database.select(database.phoneDoseActionEvents).get(),
      hasLength(2),
    );
  });

  test('missed then acknowledgement consumes the terminal outcome', () async {
    Future<PhoneDoseActionResult> record(PhoneDoseActionKind kind) =>
        service.record(
          PhoneDoseActionRequest(
            occurrence: occurrence,
            medicationId: 'medication-1',
            kind: kind,
            occurredAt: DateTime.utc(2026, 7, 30, 16),
            deviceId: 'device-1',
          ),
        );

    await record(PhoneDoseActionKind.missed);
    await record(PhoneDoseActionKind.missedAcknowledged);
    expect(
      () => record(PhoneDoseActionKind.skipped),
      throwsA(isA<PhoneDoseTerminalConflict>()),
    );
    expect(
      await database.select(database.phoneDoseActionEvents).get(),
      hasLength(2),
    );
  });

  test('same idempotency key rejects different medication content', () async {
    await service.record(
      PhoneDoseActionRequest(
        occurrence: occurrence,
        medicationId: 'medication-1',
        kind: PhoneDoseActionKind.helpRequested,
        occurredAt: DateTime.utc(2026, 7, 30, 15, 2),
        deviceId: 'device-1',
      ),
    );

    expect(
      () => service.record(
        PhoneDoseActionRequest(
          occurrence: occurrence,
          medicationId: 'medication-2',
          kind: PhoneDoseActionKind.helpRequested,
          occurredAt: DateTime.utc(2026, 7, 30, 15, 3),
          deviceId: 'device-1',
        ),
      ),
      throwsStateError,
    );
  });

  test('normalizes contract timestamps to UTC millisecond precision', () async {
    await service.record(
      PhoneDoseActionRequest(
        occurrence: occurrence,
        medicationId: 'medication-1',
        kind: PhoneDoseActionKind.snoozed,
        occurredAt: DateTime.utc(2026, 7, 30, 15, 2, 3, 456, 789),
        deviceId: 'device-1',
      ),
    );

    final mutation =
        (await database.select(database.syncOutboxMutations).get()).single;
    final payload = jsonDecode(mutation.payloadJson) as Map<String, Object?>;
    expect(payload['occurredAt'], '2026-07-30T15:02:03.456Z');
    expect(mutation.createdAt.toUtc(), DateTime.utc(2026, 7, 30, 15, 2, 3));
  });

  test('database rejects taken marker for a non-taken action', () async {
    expect(
      () => database.customStatement(
        '''
        INSERT INTO phone_dose_action_events (
          id, device_id, occurrence_id, schedule_id, schedule_revision, scheduled_at,
          local_date, timezone_id, medication_id, kind, occurred_at,
          marks_dose_taken, idempotency_key, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          'invalid-event',
          'device-1',
          occurrence.occurrenceId,
          occurrence.scheduleId,
          occurrence.scheduleRevision,
          occurrence.scheduledAt.millisecondsSinceEpoch ~/ 1000,
          occurrence.localDate,
          occurrence.timezoneId,
          'medication-1',
          'skipped',
          DateTime.utc(2026, 7, 30).millisecondsSinceEpoch ~/ 1000,
          1,
          'invalid-key',
          DateTime.utc(2026, 7, 30).millisecondsSinceEpoch ~/ 1000,
        ],
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('database enforces one terminal per device occurrence', () async {
    Future<void> insert(String id, String deviceId, String kind) {
      return database.customStatement(
        '''INSERT INTO phone_dose_action_events (
          id, device_id, occurrence_id, schedule_id, schedule_revision,
          scheduled_at, local_date, timezone_id, medication_id, kind,
          occurred_at, marks_dose_taken, idempotency_key, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          id,
          deviceId,
          occurrence.occurrenceId,
          occurrence.scheduleId,
          occurrence.scheduleRevision,
          occurrence.scheduledAt.millisecondsSinceEpoch ~/ 1000,
          occurrence.localDate,
          occurrence.timezoneId,
          'medication-1',
          kind,
          0,
          kind == 'taken_confirmed' ? 1 : 0,
          'key-$id',
          0,
        ],
      );
    }

    await insert('skip-1', 'device-1', 'skipped');
    await expectLater(
      insert('taken-1', 'device-1', 'taken_confirmed'),
      throwsA(isA<Exception>()),
    );
    await insert('taken-2', 'device-2', 'taken_confirmed');
    await insert('missed-1', 'device-1', 'missed');
    expect(
      await database.select(database.phoneDoseActionEvents).get(),
      hasLength(3),
    );
  });

  test('missed and missed acknowledgement remain local only', () async {
    for (final kind in [
      PhoneDoseActionKind.missed,
      PhoneDoseActionKind.missedAcknowledged,
    ]) {
      await service.record(
        PhoneDoseActionRequest(
          occurrence: occurrence,
          medicationId: 'medication-1',
          kind: kind,
          occurredAt: DateTime.utc(2026, 7, 30, 16),
          deviceId: 'device-1',
        ),
      );
    }

    final events = await database.select(database.phoneDoseActionEvents).get();

    expect(events.map((event) => event.kind), [
      'missed',
      'missed_acknowledged',
    ]);
    expect(events.every((event) => !event.marksDoseTaken), isTrue);
    expect(await database.select(database.syncOutboxMutations).get(), isEmpty);
  });

  test(
    'cross-instance terminal winner makes derived missed a safe no-op',
    () async {
      final directory = await Directory.systemTemp.createTemp('dosey-race-');
      final file = File('${directory.path}/dosey.sqlite');
      final first = DoseyDatabase(
        NativeDatabase.createInBackground(file, setup: _enableWal),
      );
      final second = DoseyDatabase(
        NativeDatabase.createInBackground(file, setup: _enableWal),
      );
      addTearDown(() async {
        await first.close();
        await second.close();
        await directory.delete(recursive: true);
      });
      await first.customSelect('SELECT 1').get();
      await second.customSelect('SELECT 1').get();
      await first.customStatement('BEGIN IMMEDIATE;');
      await _insertDirectPhoneEvent(
        first,
        occurrence: occurrence,
        id: 'terminal-winner',
        kind: 'skipped',
      );
      final committed = Future<void>.delayed(
        const Duration(milliseconds: 10),
        () => first.customStatement('COMMIT;'),
      );

      final resultFuture = PhoneDoseActionService(
        second,
        missedContentionDelay: const Duration(milliseconds: 50),
      ).recordMissedIfNoTerminal(_missedRequest(occurrence));
      await committed;
      final result = await resultFuture;

      expect(result, isNull);
      expect(
        (await second.select(second.phoneDoseActionEvents).get()).map(
          (event) => event.kind,
        ),
        ['skipped'],
      );
    },
  );

  test(
    'cross-instance derived missed winner allows a later terminal',
    () async {
      final directory = await Directory.systemTemp.createTemp('dosey-race-');
      final file = File('${directory.path}/dosey.sqlite');
      final first = DoseyDatabase(
        NativeDatabase.createInBackground(file, setup: _enableWal),
      );
      final second = DoseyDatabase(
        NativeDatabase.createInBackground(file, setup: _enableWal),
      );
      addTearDown(() async {
        await first.close();
        await second.close();
        await directory.delete(recursive: true);
      });
      await first.customSelect('SELECT 1').get();
      await second.customSelect('SELECT 1').get();

      final missed = await PhoneDoseActionService(
        first,
      ).recordMissedIfNoTerminal(_missedRequest(occurrence));
      final terminal = await PhoneDoseActionService(second).record(
        PhoneDoseActionRequest(
          occurrence: occurrence,
          medicationId: 'medication-1',
          kind: PhoneDoseActionKind.skipped,
          occurredAt: DateTime.utc(2026, 7, 30, 15, 3),
          deviceId: 'device-1',
        ),
      );

      expect(missed, isNotNull);
      expect(terminal.inserted, isTrue);
      expect(
        (await second.select(second.phoneDoseActionEvents).get()).map(
          (event) => event.kind,
        ),
        ['missed', 'skipped'],
      );
    },
  );

  test('concurrent cross-instance derived misses reuse one event', () async {
    final directory = await Directory.systemTemp.createTemp('dosey-race-');
    final file = File('${directory.path}/dosey.sqlite');
    final first = DoseyDatabase(
      NativeDatabase.createInBackground(file, setup: _enableWal),
    );
    final second = DoseyDatabase(
      NativeDatabase.createInBackground(file, setup: _enableWal),
    );
    addTearDown(() async {
      await first.close();
      await second.close();
      await directory.delete(recursive: true);
    });
    await first.customSelect('SELECT 1').get();
    await second.customSelect('SELECT 1').get();

    final results = await Future.wait([
      PhoneDoseActionService(
        first,
      ).recordMissedIfNoTerminal(_missedRequest(occurrence)),
      PhoneDoseActionService(
        second,
      ).recordMissedIfNoTerminal(_missedRequest(occurrence)),
    ]);

    expect(results.where((result) => result!.inserted), hasLength(1));
    expect(results.where((result) => !result!.inserted), hasLength(1));
    expect(
      await second.select(second.phoneDoseActionEvents).get(),
      hasLength(1),
    );
    expect(await second.select(second.doseLogEvents).get(), hasLength(1));
  });

  test('exhausted database contention returns a controlled failure', () async {
    final directory = await Directory.systemTemp.createTemp('dosey-race-');
    final file = File('${directory.path}/dosey.sqlite');
    final first = DoseyDatabase(
      NativeDatabase.createInBackground(file, setup: _enableWal),
    );
    final second = DoseyDatabase(
      NativeDatabase.createInBackground(file, setup: _enableWal),
    );
    addTearDown(() async {
      await first.customStatement('ROLLBACK;');
      await first.close();
      await second.close();
      await directory.delete(recursive: true);
    });
    await first.customSelect('SELECT 1').get();
    await second.customSelect('SELECT 1').get();
    await first.customStatement('BEGIN IMMEDIATE;');

    await expectLater(
      PhoneDoseActionService(
        second,
        missedContentionAttempts: 1,
        missedContentionDelay: Duration.zero,
      ).recordMissedIfNoTerminal(_missedRequest(occurrence)),
      throwsA(isA<PhoneDoseActionWriteFailure>()),
    );
  });

  test('event and outbox insertion roll back together', () async {
    await database.customStatement('''
      CREATE TRIGGER reject_phone_outbox
      BEFORE INSERT ON sync_outbox_mutations
      BEGIN
        SELECT RAISE(ABORT, 'offline write failure');
      END;
    ''');

    expect(
      () => service.record(
        PhoneDoseActionRequest(
          occurrence: occurrence,
          medicationId: 'medication-1',
          kind: PhoneDoseActionKind.helpRequested,
          occurredAt: DateTime.utc(2026, 7, 30, 15, 2),
          deviceId: 'device-1',
        ),
      ),
      throwsA(isA<Exception>()),
    );

    expect(
      await database.select(database.phoneDoseActionEvents).get(),
      isEmpty,
    );
    expect(await database.select(database.doseLogEvents).get(), isEmpty);

    await database.customStatement('DROP TRIGGER reject_phone_outbox;');
    final retry = await service.record(
      PhoneDoseActionRequest(
        occurrence: occurrence,
        medicationId: 'medication-1',
        kind: PhoneDoseActionKind.helpRequested,
        occurredAt: DateTime.utc(2026, 7, 30, 15, 3),
        deviceId: 'device-1',
      ),
    );
    expect(retry.inserted, isTrue);
    expect(
      await database.select(database.phoneDoseActionEvents).get(),
      hasLength(1),
    );
    expect(
      await database.select(database.syncOutboxMutations).get(),
      hasLength(1),
    );
  });
}

PhoneDoseActionRequest _missedRequest(ReminderOccurrence occurrence) {
  return PhoneDoseActionRequest(
    occurrence: occurrence,
    medicationId: 'medication-1',
    kind: PhoneDoseActionKind.missed,
    occurredAt: DateTime.utc(2026, 7, 30, 15, 2),
    deviceId: 'device-1',
  );
}

Future<void> _insertDirectPhoneEvent(
  DoseyDatabase database, {
  required ReminderOccurrence occurrence,
  required String id,
  required String kind,
}) {
  return database.customStatement(
    '''INSERT INTO phone_dose_action_events (
      id, device_id, occurrence_id, schedule_id, schedule_revision,
      scheduled_at, local_date, timezone_id, medication_id, kind,
      occurred_at, marks_dose_taken, idempotency_key, created_at
    ) VALUES (?, 'device-1', ?, ?, ?, ?, ?, ?, 'medication-1', ?, 0, 0, ?, 0)''',
    [
      id,
      occurrence.occurrenceId,
      occurrence.scheduleId,
      occurrence.scheduleRevision,
      occurrence.scheduledAt.millisecondsSinceEpoch ~/ 1000,
      occurrence.localDate,
      occurrence.timezoneId,
      kind,
      'key-$id',
    ],
  );
}

void _enableWal(Database database) {
  database.execute('PRAGMA journal_mode = WAL;');
}
