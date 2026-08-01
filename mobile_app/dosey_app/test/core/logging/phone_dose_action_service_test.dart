import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dosey_app/core/logging/phone_dose_action_service.dart';
import 'package:dosey_app/core/reminders/reminder_occurrence.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/common.dart' show SqlError, SqliteException;

void main() {
  test(
    'all action kinds persist exact flags, logs, and outbox eligibility',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final service = PhoneDoseActionService(database);
      final kinds = PhoneDoseActionKind.values;
      await _seedPrescription(database, available: 2, remaining: 2);

      for (var index = 0; index < kinds.length; index++) {
        await service.record(
          _request(
            _occurrence(index + 1),
            kinds[index],
            occurredAt: _time(index),
          ),
        );
      }

      final events =
          (await database.select(database.phoneDoseActionEvents).get())..sort(
            (left, right) => left.occurredAt.compareTo(right.occurredAt),
          );
      final logs = (await database.select(database.doseLogEvents).get())
        ..sort((left, right) => left.occurredAt.compareTo(right.occurredAt));
      final outbox = (await database.select(database.syncOutboxMutations).get())
        ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
      expect(
        events.map((row) => row.kind),
        kinds.map((kind) => kind.storageValue),
      );
      expect(
        events.map((row) => row.marksDoseTaken),
        kinds.map((kind) => kind.marksTaken),
      );
      expect(logs.map((row) => row.kind), const [
        'doseTakenConfirmed',
        'doseSkipped',
        'doseSnoozed',
        'caregiverHelpRequested',
        'doseMissed',
        'doseMissedRecognized',
      ]);
      expect(
        logs.map((row) => row.marksDoseTaken),
        kinds.map((kind) => kind.marksTaken),
      );
      expect(
        outbox.map((row) => row.entityId),
        events
            .where(
              (row) =>
                  row.kind != PhoneDoseActionKind.missed.storageValue &&
                  row.kind !=
                      PhoneDoseActionKind.missedAcknowledged.storageValue,
            )
            .map((row) => row.id),
      );
    },
  );

  test(
    'same-device exact and occurredAt-only replays reuse persisted action',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final service = PhoneDoseActionService(database);
      final occurrence = _occurrence(1);
      final first = await service.record(
        _request(occurrence, PhoneDoseActionKind.helpRequested),
      );
      final replay = await service.record(
        _request(
          occurrence,
          PhoneDoseActionKind.helpRequested,
          occurredAt: _time(2),
        ),
      );

      expect(replay, isA<PhoneDoseActionResult>());
      expect(replay.eventId, first.eventId);
      expect(replay.inserted, isFalse);
      expect(replay.occurredAt, first.occurredAt);
      expect(
        await database.select(database.phoneDoseActionEvents).get(),
        hasLength(1),
      );
      expect(await database.select(database.doseLogEvents).get(), hasLength(1));
      expect(
        await database.select(database.syncOutboxMutations).get(),
        hasLength(1),
      );
    },
  );

  test('immutable occurrence semantic mismatch conflicts', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final service = PhoneDoseActionService(database);
    final occurrence = _occurrence(1);
    await service.record(
      _request(occurrence, PhoneDoseActionKind.helpRequested),
    );

    await expectLater(
      service.record(
        _request(
          _occurrence(1, medicationId: 'different-medication'),
          PhoneDoseActionKind.helpRequested,
        ),
      ),
      throwsStateError,
    );
  });

  test(
    'profile changes reject an otherwise identical occurrence replay',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final service = PhoneDoseActionService(database);
      final occurrence = _occurrence(1);
      await service.record(
        _request(occurrence, PhoneDoseActionKind.helpRequested),
      );

      await expectLater(
        service.record(
          _request(
            _occurrence(1, profileId: 'different-profile'),
            PhoneDoseActionKind.helpRequested,
          ),
        ),
        throwsStateError,
      );
    },
  );

  test(
    'canonical tuple IDs distinguish old colon-boundary collisions',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final service = PhoneDoseActionService(database);
      final first = await service.record(
        _request(
          _occurrence(1, scheduleId: 'schedule'),
          PhoneDoseActionKind.snoozed,
          deviceId: 'device:a',
          intentToken: 'intent',
        ),
      );
      final second = await service.record(
        _request(
          _occurrence(1, scheduleId: 'a:schedule'),
          PhoneDoseActionKind.snoozed,
          deviceId: 'device',
          intentToken: 'a:intent',
        ),
      );

      final events = await database
          .select(database.phoneDoseActionEvents)
          .get();
      final outbox = await database.select(database.syncOutboxMutations).get();
      expect(events, hasLength(2));
      expect(outbox, hasLength(2));
      expect(first.eventId, isNot(second.eventId));
      expect(events.map((row) => row.idempotencyKey).toSet(), hasLength(2));
      expect(events.map((row) => row.id).toSet(), hasLength(2));
      expect(outbox.map((row) => row.mutationId).toSet(), hasLength(2));
    },
  );

  test('fixed-width IDs support very long device and schedule IDs', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final result = await PhoneDoseActionService(database).record(
      _request(
        _occurrence(1, scheduleId: 'schedule-${'x' * 512}'),
        PhoneDoseActionKind.helpRequested,
        deviceId: 'device-${'y' * 512}',
      ),
    );

    final event = await database
        .select(database.phoneDoseActionEvents)
        .getSingle();
    final mutation = await database
        .select(database.syncOutboxMutations)
        .getSingle();
    expect(result.inserted, isTrue);
    expect(event.idempotencyKey.length, lessThanOrEqualTo(64));
    expect(event.id.length, lessThanOrEqualTo(64));
    expect(mutation.mutationId.length, lessThanOrEqualTo(64));
  });

  test(
    'subsecond occurredAt normalizes all persisted action timestamps',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final occurrence = _occurrence(1);
      final request = _request(
        occurrence,
        PhoneDoseActionKind.helpRequested,
        occurredAt: DateTime.utc(2026, 1, 1, 16, 1, 2, 345, 678),
      );
      final service = PhoneDoseActionService(database);

      final first = await service.record(request);
      final replay = await service.record(
        _request(
          occurrence,
          PhoneDoseActionKind.helpRequested,
          occurredAt: DateTime.utc(2026, 1, 1, 16, 1, 59, 999),
        ),
      );
      final expected = DateTime.utc(2026, 1, 1, 16, 1, 2);
      final event = await database
          .select(database.phoneDoseActionEvents)
          .getSingle();
      final log = await database.select(database.doseLogEvents).getSingle();
      final mutation = await database
          .select(database.syncOutboxMutations)
          .getSingle();

      expect(first.occurredAt, expected);
      expect(replay.occurredAt, expected);
      expect(event.occurredAt.toUtc(), expected);
      expect(event.createdAt.toUtc(), expected);
      expect(log.occurredAt.toUtc(), expected);
      expect(mutation.createdAt.toUtc(), expected);
      expect(mutation.updatedAt.toUtc(), expected);
      expect(jsonDecode(mutation.payloadJson), {
        'medicationId': 'medication-1',
        'profileId': 'profile-1',
        'kind': 'help_requested',
        'occurredAt': expected.toIso8601String(),
        'occurrence': {
          'occurrenceId': occurrence.id,
          'scheduleId': occurrence.scheduleId,
          'scheduleRevision': occurrence.scheduleRevision,
          'scheduledAtUtc': occurrence.scheduledAtUtc.toIso8601String(),
          'localDate': occurrence.localDate,
          'timezoneId': occurrence.timezoneId,
        },
      });
    },
  );

  test(
    'global second-device taken reuses one action and inventory decrement',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescription(database, available: 2, remaining: 2);
      final service = PhoneDoseActionService(database);
      final occurrence = _occurrence(1);
      final first = await service.record(
        _request(occurrence, PhoneDoseActionKind.takenConfirmed),
      );
      final replay = await service.record(
        _request(
          occurrence,
          PhoneDoseActionKind.takenConfirmed,
          deviceId: 'device-2',
        ),
      );

      final prescription = await database
          .select(database.prescriptions)
          .getSingle();
      expect(replay.eventId, first.eventId);
      expect(replay.inserted, isFalse);
      expect(prescription.availableDoses, 1);
      expect(prescription.remainingDoses, 1);
      expect(
        await database.select(database.phoneDoseActionEvents).get(),
        hasLength(1),
      );
      expect(await database.select(database.doseLogEvents).get(), hasLength(1));
      expect(
        await database.select(database.syncOutboxMutations).get(),
        hasLength(1),
      );
    },
  );

  test(
    'intent token validation rejects invalid and forbidden tokens',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescription(database, available: 1, remaining: 1);
      final service = PhoneDoseActionService(database);
      for (final kind in [
        PhoneDoseActionKind.snoozed,
        PhoneDoseActionKind.helpRequested,
      ]) {
        for (final token in <String?>[null, '', ' ', 'x' * 129]) {
          await expectLater(
            service.record(_request(_occurrence(1), kind, intentToken: token)),
            throwsArgumentError,
          );
        }
      }
      for (final kind in [
        PhoneDoseActionKind.takenConfirmed,
        PhoneDoseActionKind.skipped,
        PhoneDoseActionKind.missed,
        PhoneDoseActionKind.missedAcknowledged,
      ]) {
        await expectLater(
          service.record(_request(_occurrence(1), kind, intentToken: 'intent')),
          throwsArgumentError,
        );
      }
      final prescription = await database
          .select(database.prescriptions)
          .getSingle();
      expect(prescription.availableDoses, 1);
      expect(prescription.remainingDoses, 1);
      expect(
        await database.select(database.phoneDoseActionEvents).get(),
        isEmpty,
      );
      expect(await database.select(database.doseLogEvents).get(), isEmpty);
      expect(
        await database.select(database.syncOutboxMutations).get(),
        isEmpty,
      );
    },
  );

  test('canonical intent replay trims token and reuses effects', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final service = PhoneDoseActionService(database);
    final occurrence = _occurrence(1);
    final first = await service.record(
      _request(
        occurrence,
        PhoneDoseActionKind.snoozed,
        intentToken: ' intent-1 ',
      ),
    );
    final replay = await service.record(
      _request(
        occurrence,
        PhoneDoseActionKind.snoozed,
        intentToken: 'intent-1',
        occurredAt: _time(2),
      ),
    );
    expect(replay.inserted, isFalse);
    expect(replay.eventId, first.eventId);
    expect(replay.occurredAt, first.occurredAt);
    expect(
      await database.select(database.phoneDoseActionEvents).get(),
      hasLength(1),
    );
    expect(await database.select(database.doseLogEvents).get(), hasLength(1));
    expect(
      await database.select(database.syncOutboxMutations).get(),
      hasLength(1),
    );
  });

  test('different Snooze tokens create independent effects', () async {
    await _expectDistinctTokenEffects(PhoneDoseActionKind.snoozed);
  });

  test('different Help tokens create independent effects', () async {
    await _expectDistinctTokenEffects(PhoneDoseActionKind.helpRequested);
  });

  test('reusing a token for Snooze then Help fails closed', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final service = PhoneDoseActionService(database);
    final occurrence = _occurrence(1);
    await service.record(
      _request(occurrence, PhoneDoseActionKind.snoozed, intentToken: 'intent'),
    );
    await expectLater(
      service.record(
        _request(
          occurrence,
          PhoneDoseActionKind.helpRequested,
          intentToken: 'intent',
        ),
      ),
      throwsStateError,
    );
    await _expectOneTokenEffect(database);
  });

  test('reusing a token for another occurrence fails closed', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final service = PhoneDoseActionService(database);
    await service.record(
      _request(
        _occurrence(1),
        PhoneDoseActionKind.snoozed,
        intentToken: 'intent',
      ),
    );
    await expectLater(
      service.record(
        _request(
          _occurrence(2),
          PhoneDoseActionKind.snoozed,
          intentToken: 'intent',
        ),
      ),
      throwsStateError,
    );
    await _expectOneTokenEffect(database);
  });

  test('device-scoped token namespaces allow independent effects', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final service = PhoneDoseActionService(database);
    final occurrence = _occurrence(1);
    await service.record(
      _request(occurrence, PhoneDoseActionKind.snoozed, intentToken: 'intent'),
    );
    await service.record(
      _request(
        occurrence,
        PhoneDoseActionKind.snoozed,
        intentToken: 'intent',
        deviceId: 'device-2',
      ),
    );
    expect(
      await database.select(database.phoneDoseActionEvents).get(),
      hasLength(2),
    );
    expect(await database.select(database.doseLogEvents).get(), hasLength(2));
    expect(
      await database.select(database.syncOutboxMutations).get(),
      hasLength(2),
    );
  });

  test(
    'opposite terminals conflict while nonterminal actions coexist',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final service = PhoneDoseActionService(database);
      final occurrence = _occurrence(1);
      await service.record(_request(occurrence, PhoneDoseActionKind.skipped));
      await expectLater(
        service.record(
          _request(occurrence, PhoneDoseActionKind.takenConfirmed),
        ),
        throwsStateError,
      );
      for (final kind in [
        PhoneDoseActionKind.snoozed,
        PhoneDoseActionKind.helpRequested,
        PhoneDoseActionKind.missed,
        PhoneDoseActionKind.missedAcknowledged,
      ]) {
        await service.record(_request(occurrence, kind));
      }
      expect(
        await database.select(database.phoneDoseActionEvents).get(),
        hasLength(5),
      );
    },
  );

  test(
    'inconsistent available stock leaves coupled inventory unchanged',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescription(database, available: 1, remaining: 0);

      await PhoneDoseActionService(
        database,
      ).record(_request(_occurrence(1), PhoneDoseActionKind.takenConfirmed));

      final prescription = await database
          .select(database.prescriptions)
          .getSingle();
      expect(prescription.availableDoses, 1);
      expect(prescription.remainingDoses, 0);
    },
  );

  test(
    'taken with only loaded or review stock records no inventory change',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescription(
        database,
        available: 0,
        remaining: 3,
        loaded: 2,
        review: 1,
      );

      await PhoneDoseActionService(
        database,
      ).record(_request(_occurrence(1), PhoneDoseActionKind.takenConfirmed));

      final prescription = await database
          .select(database.prescriptions)
          .getSingle();
      expect(prescription.availableDoses, 0);
      expect(prescription.remainingDoses, 3);
      expect(prescription.loadedDoses, 2);
      expect(prescription.reviewDoses, 1);
    },
  );

  test(
    'missing prescription fails without action, log, or outbox effects',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await expectLater(
        PhoneDoseActionService(
          database,
        ).record(_request(_occurrence(1), PhoneDoseActionKind.takenConfirmed)),
        throwsStateError,
      );
      expect(
        await database.select(database.phoneDoseActionEvents).get(),
        isEmpty,
      );
      expect(await database.select(database.doseLogEvents).get(), isEmpty);
      expect(
        await database.select(database.syncOutboxMutations).get(),
        isEmpty,
      );
    },
  );

  test(
    'late outbox failure rolls back action, inventory, log, and outbox',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescription(database, available: 1, remaining: 1);
      await database.customStatement('''
      CREATE TRIGGER reject_outbox BEFORE INSERT ON sync_outbox_mutations
      BEGIN SELECT RAISE(ABORT, 'late failure'); END;
    ''');

      await expectLater(
        PhoneDoseActionService(
          database,
        ).record(_request(_occurrence(1), PhoneDoseActionKind.takenConfirmed)),
        throwsA(isA<SqliteException>()),
      );

      final prescription = await database
          .select(database.prescriptions)
          .getSingle();
      expect(prescription.availableDoses, 1);
      expect(prescription.remainingDoses, 1);
      expect(
        await database.select(database.phoneDoseActionEvents).get(),
        isEmpty,
      );
      expect(await database.select(database.doseLogEvents).get(), isEmpty);
      expect(
        await database.select(database.syncOutboxMutations).get(),
        isEmpty,
      );
    },
  );

  test('retries only typed busy failures up to four attempts', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final request = _request(_occurrence(1), PhoneDoseActionKind.helpRequested);
    final busyOnce = _WriterIntentFailureInterceptor([
      _sqliteError(SqlError.SQLITE_BUSY),
    ]);
    await database.runWithInterceptor(
      () => PhoneDoseActionService(database).record(request),
      interceptor: busyOnce,
    );
    expect(busyOnce.attempts, 2);

    final nonBusy = _WriterIntentFailureInterceptor([
      _sqliteError(SqlError.SQLITE_CONSTRAINT),
    ]);
    await expectLater(
      database.runWithInterceptor(
        () => PhoneDoseActionService(
          database,
        ).record(_request(_occurrence(2), PhoneDoseActionKind.helpRequested)),
        interceptor: nonBusy,
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(nonBusy.attempts, 1);

    final permanentBusy = _WriterIntentFailureInterceptor(
      List<SqliteException>.filled(
        4,
        _sqliteError(SqlError.SQLITE_BUSY),
      ).toList(),
    );
    await expectLater(
      database.runWithInterceptor(
        () => PhoneDoseActionService(
          database,
        ).record(_request(_occurrence(3), PhoneDoseActionKind.helpRequested)),
        interceptor: permanentBusy,
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(permanentBusy.attempts, 4);
    expect(
      await database.select(database.phoneDoseActionEvents).get(),
      hasLength(1),
    );
  });

  test('two connections converge on one global taken action', () async {
    final directory = await Directory.systemTemp.createTemp('dosey-action-');
    final file = File('${directory.path}/dosey.sqlite');
    final firstDatabase = DoseyDatabase(NativeDatabase(file));
    final secondDatabase = DoseyDatabase(NativeDatabase(file));
    final lock = _WriterIntentLock();
    addTearDown(() async {
      if (!lock.releaseFirstWriter.isCompleted) {
        lock.releaseFirstWriter.complete();
      }
      await firstDatabase.close();
      await secondDatabase.close();
      await directory.delete(recursive: true);
    });
    await firstDatabase.customSelect('SELECT 1').get();
    await secondDatabase.customSelect('SELECT 1').get();
    await _seedPrescription(firstDatabase, available: 2, remaining: 2);
    final occurrence = _occurrence(1);
    final first = firstDatabase.runWithInterceptor(
      () => PhoneDoseActionService(
        firstDatabase,
      ).record(_request(occurrence, PhoneDoseActionKind.takenConfirmed)),
      interceptor: _WriterIntentRaceInterceptor(lock, pauseAfterLock: true),
    );
    await lock.firstWriterLocked.future;
    final second = secondDatabase.runWithInterceptor(
      () => PhoneDoseActionService(secondDatabase).record(
        _request(
          occurrence,
          PhoneDoseActionKind.takenConfirmed,
          deviceId: 'device-2',
        ),
      ),
      interceptor: _WriterIntentRaceInterceptor(lock),
    );
    await lock.secondWriterBusy.future;
    lock.releaseFirstWriter.complete();
    final results = await Future.wait([first, second]);

    expect(results.where((result) => result.inserted), hasLength(1));
    expect(results.where((result) => !result.inserted), hasLength(1));
    expect(
      await secondDatabase.select(secondDatabase.phoneDoseActionEvents).get(),
      hasLength(1),
    );
    expect(
      await secondDatabase.select(secondDatabase.doseLogEvents).get(),
      hasLength(1),
    );
    expect(
      await secondDatabase.select(secondDatabase.syncOutboxMutations).get(),
      hasLength(1),
    );
    final prescription = await secondDatabase
        .select(secondDatabase.prescriptions)
        .getSingle();
    expect(prescription.availableDoses, 1);
    expect(prescription.remainingDoses, 1);
  });
}

ReminderOccurrence _occurrence(
  int index, {
  String medicationId = 'medication-1',
  String? profileId,
  String? scheduleId,
}) => ReminderOccurrence(
  scheduleId: scheduleId ?? 'schedule-$index',
  scheduleRevision: 1,
  scheduledAtUtc: DateTime.utc(2026, 1, index, 16),
  localDate: '2026-01-${index.toString().padLeft(2, '0')}',
  timezoneId: 'America/Los_Angeles',
  medicationId: medicationId,
  profileId: profileId ?? 'profile-1',
);

PhoneDoseActionRequest _request(
  ReminderOccurrence occurrence,
  PhoneDoseActionKind kind, {
  String deviceId = 'device-1',
  DateTime? occurredAt,
  Object? intentToken = _intentTokenUnspecified,
}) => PhoneDoseActionRequest(
  occurrence: occurrence,
  kind: kind,
  deviceId: deviceId,
  occurredAt: occurredAt ?? _time(1),
  intentToken: intentToken == _intentTokenUnspecified
      ? (kind == PhoneDoseActionKind.snoozed ||
                kind == PhoneDoseActionKind.helpRequested
            ? 'intent:${kind.storageValue}'
            : null)
      : intentToken as String?,
);

const _intentTokenUnspecified = Object();

DateTime _time(int minute) => DateTime.utc(2026, 1, 1, 16, minute);

Future<void> _seedPrescription(
  DoseyDatabase database, {
  required int available,
  required int remaining,
  int loaded = 0,
  int review = 0,
}) => database
    .into(database.prescriptions)
    .insert(
      PrescriptionsCompanion.insert(
        id: 'medication-1',
        name: 'Medication',
        pillType: 'tablet',
        remainingDoses: Value(remaining),
        availableDoses: Value(available),
        loadedDoses: Value(loaded),
        reviewDoses: Value(review),
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );

Future<void> _expectDistinctTokenEffects(PhoneDoseActionKind kind) async {
  final database = DoseyDatabase.inMemory();
  addTearDown(database.close);
  final service = PhoneDoseActionService(database);
  await service.record(_request(_occurrence(1), kind, intentToken: 'intent-1'));
  await service.record(_request(_occurrence(1), kind, intentToken: 'intent-2'));
  final events = await database.select(database.phoneDoseActionEvents).get();
  final outbox = await database.select(database.syncOutboxMutations).get();
  expect(events, hasLength(2));
  expect(await database.select(database.doseLogEvents).get(), hasLength(2));
  expect(outbox, hasLength(2));
  expect(events.map((row) => row.id).toSet(), hasLength(2));
  expect(events.map((row) => row.idempotencyKey).toSet(), hasLength(2));
  expect(outbox.map((row) => row.mutationId).toSet(), hasLength(2));
}

Future<void> _expectOneTokenEffect(DoseyDatabase database) async {
  expect(
    await database.select(database.phoneDoseActionEvents).get(),
    hasLength(1),
  );
  expect(await database.select(database.doseLogEvents).get(), hasLength(1));
  expect(
    await database.select(database.syncOutboxMutations).get(),
    hasLength(1),
  );
}

SqliteException _sqliteError(int code) => SqliteException(
  extendedResultCode: code,
  message: 'injected sqlite failure',
);

class _WriterIntentFailureInterceptor extends QueryInterceptor {
  _WriterIntentFailureInterceptor(this.errors);

  final List<SqliteException> errors;
  var attempts = 0;

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (statement.contains('UPDATE app_settings SET updated_at = updated_at')) {
      attempts += 1;
      if (errors.isNotEmpty) throw errors.removeAt(0);
    }
    return executor.runUpdate(statement, args);
  }
}

class _WriterIntentLock {
  final firstWriterLocked = Completer<void>();
  final secondWriterBusy = Completer<void>();
  final releaseFirstWriter = Completer<void>();
}

class _WriterIntentRaceInterceptor extends QueryInterceptor {
  _WriterIntentRaceInterceptor(this.lock, {this.pauseAfterLock = false});

  final _WriterIntentLock lock;
  final bool pauseAfterLock;
  var handled = false;

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (handled ||
        !statement.contains(
          'UPDATE app_settings SET updated_at = updated_at',
        )) {
      return executor.runUpdate(statement, args);
    }
    handled = true;
    try {
      final result = await executor.runUpdate(statement, args);
      if (pauseAfterLock) {
        lock.firstWriterLocked.complete();
        await lock.releaseFirstWriter.future;
      }
      return result;
    } on SqliteException catch (error) {
      if (error.resultCode == SqlError.SQLITE_BUSY &&
          !lock.secondWriterBusy.isCompleted) {
        lock.secondWriterBusy.complete();
      }
      rethrow;
    }
  }
}
