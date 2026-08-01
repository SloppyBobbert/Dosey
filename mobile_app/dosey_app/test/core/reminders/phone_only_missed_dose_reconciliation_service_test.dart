import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dosey_app/core/backup/local_backup_store.dart';
import 'package:dosey_app/core/logging/phone_dose_action_service.dart';
import 'package:dosey_app/core/reminders/reminder_occurrence.dart';
import 'package:dosey_app/core/reminders/phone_only_missed_dose_reconciliation_service.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/common.dart' show SqlError, SqliteException;

void main() {
  test('first run writes a baseline without missed actions', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final now = DateTime.utc(2026, 1, 2, 12);
    await _schedule(database, prescriptionId: 'medication-1');

    await _service(database, now).reconcile();

    expect(
      await database.select(database.phoneDoseActionEvents).get(),
      isEmpty,
    );
    expect(await database.select(database.doseLogEvents).get(), isEmpty);
    final checkpoint =
        await (database.select(database.appSettings)..where(
              (row) => row.key.equals(
                PhoneOnlyMissedDoseReconciliationService.checkpointKey,
              ),
            ))
            .getSingle();
    expect(
      jsonDecode(checkpoint.value)['observedAtUtc'],
      now.toIso8601String(),
    );
  });

  test(
    'trusted checkpoint records only an expired grace deadline once',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _schedule(database, prescriptionId: 'medication-1');
      await _service(database, DateTime.utc(2026, 1, 2, 9)).reconcile();
      await _service(database, DateTime.utc(2026, 1, 2, 11)).reconcile();
      expect(
        await database.select(database.phoneDoseActionEvents).get(),
        hasLength(1),
      );
      await _service(database, DateTime.utc(2026, 1, 2, 11)).reconcile();
      expect(
        await database.select(database.phoneDoseActionEvents).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.syncOutboxMutations).get(),
        isEmpty,
      );
    },
  );

  test(
    'blank prescriptions are omitted instead of constructing occurrences',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _schedule(database, prescriptionId: '');
      await _service(database, DateTime.utc(2026, 1, 2, 9)).reconcile();
      await _service(database, DateTime.utc(2026, 1, 2, 11)).reconcile();
      expect(
        await database.select(database.phoneDoseActionEvents).get(),
        isEmpty,
      );
    },
  );

  test('malformed and future checkpoints baseline without backfill', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _schedule(database, prescriptionId: 'medication-1');
    final now = DateTime.utc(2026, 1, 2, 12);
    for (final value in [
      'not-json',
      jsonEncode({
        'version': 1,
        'deviceId': 'device-1',
        'observedAtUtc': DateTime.utc(2026, 1, 3).toIso8601String(),
        'timezoneId': 'UTC',
        'schedules': [],
      }),
    ]) {
      await database
          .into(database.appSettings)
          .insertOnConflictUpdate(
            AppSettingsCompanion.insert(
              key: PhoneOnlyMissedDoseReconciliationService.checkpointKey,
              value: value,
              updatedAt: now,
            ),
          );
      await _service(database, now).reconcile();
      expect(
        await database.select(database.phoneDoseActionEvents).get(),
        isEmpty,
      );
    }
  });

  test('strict checkpoint variants baseline without backfill', () async {
    final now = DateTime.utc(2026, 1, 2, 12);
    for (final checkpoint in [
      {
        'version': 1,
        'deviceId': 'device-1',
        'observedAtUtc': now.toIso8601String(),
        'timezoneId': 'UTC',
        'schedules': [],
        'extra': true,
      },
      {
        'version': 1,
        'deviceId': 'other',
        'observedAtUtc': now.toIso8601String(),
        'timezoneId': 'UTC',
        'schedules': [],
      },
      {
        'version': 1,
        'deviceId': 'device-1',
        'observedAtUtc': now.toIso8601String(),
        'timezoneId': 'America/Los_Angeles',
        'schedules': [],
      },
    ]) {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _schedule(database, prescriptionId: 'medication-1');
      await database
          .into(database.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              key: PhoneOnlyMissedDoseReconciliationService.checkpointKey,
              value: jsonEncode(checkpoint),
              updatedAt: now,
            ),
          );
      await _service(database, now).reconcile();
      expect(
        await database.select(database.phoneDoseActionEvents).get(),
        isEmpty,
      );
    }
  });

  test('constructor rejects unsafe runtime inputs', () {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    expect(
      () => PhoneOnlyMissedDoseReconciliationService(
        database,
        deviceId: () => 'device',
        timezoneId: () => 'UTC',
        now: () => DateTime.utc(2026),
        gracePeriod: Duration.zero,
      ),
      throwsArgumentError,
    );
    expect(
      () => PhoneOnlyMissedDoseReconciliationService(
        database,
        deviceId: () => 'device',
        timezoneId: () => 'UTC',
        now: () => DateTime.utc(2026),
        maxWindow: const Duration(days: 8),
      ),
      throwsArgumentError,
    );
  });

  test(
    'late checkpoint failure rolls back missed action and leaves physical state unchanged',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final baseline = DateTime.utc(2026, 1, 2, 9);
      final observedAt = DateTime.utc(2026, 1, 2, 11);
      await _schedule(database, prescriptionId: 'medication-1');
      await _seedUntouchedState(database, baseline);
      await _service(database, baseline).reconcile();
      await database.customStatement('''
        CREATE TRIGGER reject_missed_checkpoint
        BEFORE INSERT ON app_settings
        WHEN NEW.key = '${PhoneOnlyMissedDoseReconciliationService.checkpointKey}'
        BEGIN SELECT RAISE(ABORT, 'late checkpoint failure'); END;
      ''');

      await expectLater(
        _service(database, observedAt).reconcile(),
        throwsA(isA<SqliteException>()),
      );

      await _expectNoMissedSideEffects(database, baseline);
      await database.customStatement('DROP TRIGGER reject_missed_checkpoint');
      await _service(database, observedAt).reconcile();

      expect(
        await database.select(database.phoneDoseActionEvents).get(),
        hasLength(1),
      );
      expect(await database.select(database.doseLogEvents).get(), hasLength(1));
      await _expectUntouchedState(database);
      expect(
        jsonDecode(
          (await (database.select(database.appSettings)..where(
                    (row) => row.key.equals(
                      PhoneOnlyMissedDoseReconciliationService.checkpointKey,
                    ),
                  ))
                  .getSingle())
              .value,
        )['observedAtUtc'],
        observedAt.toIso8601String(),
      );
    },
  );

  test(
    'retries only typed busy failures for the whole reconciliation',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final baseline = DateTime.utc(2026, 1, 2, 9);
      final observedAt = DateTime.utc(2026, 1, 2, 11);
      await _schedule(database, prescriptionId: 'medication-1');
      await _seedUntouchedState(database, baseline);
      await _service(database, baseline).reconcile();

      final busyOnce = _WriterIntentFailureInterceptor([
        _sqliteError(SqlError.SQLITE_BUSY),
      ]);
      await database.runWithInterceptor(
        () => _service(database, observedAt).reconcile(),
        interceptor: busyOnce,
      );

      expect(busyOnce.attempts, 2);
      expect(
        await database.select(database.phoneDoseActionEvents).get(),
        hasLength(1),
      );
      expect(await database.select(database.doseLogEvents).get(), hasLength(1));
      expect(
        await database.select(database.syncOutboxMutations).get(),
        isEmpty,
      );
      expect(
        jsonDecode(
          (await (database.select(database.appSettings)..where(
                    (row) => row.key.equals(
                      PhoneOnlyMissedDoseReconciliationService.checkpointKey,
                    ),
                  ))
                  .getSingle())
              .value,
        )['observedAtUtc'],
        observedAt.toIso8601String(),
      );
      await _expectUntouchedState(database);
    },
  );

  test(
    'rethrows non-busy writer failures without retrying reconciliation',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final baseline = DateTime.utc(2026, 1, 2, 9);
      await _schedule(database, prescriptionId: 'medication-1');
      await _seedUntouchedState(database, baseline);
      await _service(database, baseline).reconcile();
      final failure = _WriterIntentFailureInterceptor([
        _sqliteError(SqlError.SQLITE_CONSTRAINT),
      ]);

      await expectLater(
        database.runWithInterceptor(
          () => _service(database, DateTime.utc(2026, 1, 2, 11)).reconcile(),
          interceptor: failure,
        ),
        throwsA(isA<SqliteException>()),
      );

      expect(failure.attempts, 1);
      await _expectNoMissedSideEffects(database, baseline);
    },
  );

  test(
    'rethrows permanent busy after four attempts without mutation',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final baseline = DateTime.utc(2026, 1, 2, 9);
      await _schedule(database, prescriptionId: 'medication-1');
      await _seedUntouchedState(database, baseline);
      await _service(database, baseline).reconcile();
      final failure = _WriterIntentFailureInterceptor(
        List<SqliteException>.generate(
          4,
          (_) => _sqliteError(SqlError.SQLITE_BUSY),
        ),
      );

      await expectLater(
        database.runWithInterceptor(
          () => _service(database, DateTime.utc(2026, 1, 2, 11)).reconcile(),
          interceptor: failure,
        ),
        throwsA(isA<SqliteException>()),
      );

      expect(failure.attempts, 4);
      await _expectNoMissedSideEffects(database, baseline);
    },
  );

  test(
    'two file-backed reconcilers converge after writer-intent contention',
    () async {
      final directory = await Directory.systemTemp.createTemp('dosey-missed-');
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
      final baseline = DateTime.utc(2026, 1, 2, 9);
      final observedAt = DateTime.utc(2026, 1, 2, 11);
      await _schedule(firstDatabase, prescriptionId: 'medication-1');
      await _seedUntouchedState(firstDatabase, baseline);
      await _service(firstDatabase, baseline).reconcile();

      final first = firstDatabase.runWithInterceptor(
        () => _service(firstDatabase, observedAt).reconcile(),
        interceptor: _WriterIntentRaceInterceptor(lock, pauseAfterLock: true),
      );
      await lock.firstWriterLocked.future.timeout(const Duration(seconds: 2));
      final second = secondDatabase.runWithInterceptor(
        () => _service(secondDatabase, observedAt).reconcile(),
        interceptor: _WriterIntentRaceInterceptor(lock),
      );
      await lock.secondWriterBusy.future.timeout(const Duration(seconds: 2));
      lock.releaseFirstWriter.complete();
      await Future.wait([first, second]).timeout(const Duration(seconds: 5));

      expect(
        await secondDatabase.select(secondDatabase.phoneDoseActionEvents).get(),
        hasLength(1),
      );
      expect(
        await secondDatabase.select(secondDatabase.doseLogEvents).get(),
        hasLength(1),
      );
      expect(
        await (secondDatabase.select(secondDatabase.appSettings)..where(
              (row) => row.key.equals(
                PhoneOnlyMissedDoseReconciliationService.checkpointKey,
              ),
            ))
            .get(),
        hasLength(1),
      );
      expect(
        await secondDatabase.select(secondDatabase.syncOutboxMutations).get(),
        isEmpty,
      );
      await _expectUntouchedState(secondDatabase);
    },
  );

  test('same service coalesces an in-flight reconciliation', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final baseline = DateTime.utc(2026, 1, 2, 9);
    final observedAt = DateTime.utc(2026, 1, 2, 11);
    await _schedule(database, prescriptionId: 'medication-1');
    await _service(database, baseline).reconcile();
    final lock = _WriterIntentLock();
    var nowCalls = 0;
    final service = PhoneOnlyMissedDoseReconciliationService(
      database,
      deviceId: () => 'device-1',
      timezoneId: () => 'UTC',
      now: () {
        nowCalls += 1;
        return observedAt;
      },
    );

    await database.runWithInterceptor(() async {
      final first = service.reconcile();
      await lock.firstWriterLocked.future.timeout(const Duration(seconds: 2));
      final second = service.reconcile();
      expect(identical(first, second), isTrue);
      lock.releaseFirstWriter.complete();
      await first.timeout(const Duration(seconds: 2));
    }, interceptor: _WriterIntentRaceInterceptor(lock, pauseAfterLock: true));

    expect(nowCalls, 1);
    expect(
      await database.select(database.phoneDoseActionEvents).get(),
      hasLength(1),
    );
    expect(await database.select(database.doseLogEvents).get(), hasLength(1));
    expect(
      await (database.select(database.appSettings)..where(
            (row) => row.key.equals(
              PhoneOnlyMissedDoseReconciliationService.checkpointKey,
            ),
          ))
          .get(),
      hasLength(1),
    );
  });

  test(
    'schedule fingerprint changes baseline without historical backfill',
    () async {
      final baseline = DateTime.utc(2026, 1, 2, 9);
      final observedAt = DateTime.utc(2026, 1, 2, 11);
      final cases = <String, Future<void> Function(DoseyDatabase)>{
        'occurrence edit': (database) =>
            _updateSchedule(database, hour: 9, revision: 2),
        'new schedule': (database) => _schedule(
          database,
          id: 'schedule-2',
          prescriptionId: 'medication-1',
        ),
        'delete and recreate': (database) async {
          await (database.delete(
            database.reminderSchedules,
          )..where((row) => row.id.equals('schedule-1'))).go();
          await _schedule(
            database,
            prescriptionId: 'medication-1',
            createdAt: DateTime.utc(2026, 1, 2),
          );
        },
        'disable': (database) =>
            _updateSchedule(database, isEnabled: false, revision: 2),
      };

      for (final entry in cases.entries) {
        final database = DoseyDatabase.inMemory();
        addTearDown(database.close);
        await _schedule(database, prescriptionId: 'medication-1');
        await _service(database, baseline).reconcile();
        await entry.value(database);

        await _service(database, observedAt).reconcile();

        expect(
          await database.select(database.phoneDoseActionEvents).get(),
          isEmpty,
          reason: entry.key,
        );
        expect(await database.select(database.doseLogEvents).get(), isEmpty);
        expect(
          await (database.select(database.appSettings)..where(
                (row) => row.key.equals(
                  PhoneOnlyMissedDoseReconciliationService.checkpointKey,
                ),
              ))
              .get(),
          hasLength(1),
        );
        expect(await _checkpointObservedAt(database), observedAt);
      }
    },
  );

  test(
    'a future occurrence after re-enable is recorded once grace expires',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _schedule(database, prescriptionId: 'medication-1', hour: 11);
      await _service(database, DateTime.utc(2026, 1, 2, 9)).reconcile();
      await _updateSchedule(database, isEnabled: false, revision: 2);
      await _service(database, DateTime.utc(2026, 1, 2, 11)).reconcile();
      expect(
        await database.select(database.phoneDoseActionEvents).get(),
        isEmpty,
      );
      expect(
        await _checkpointObservedAt(database),
        DateTime.utc(2026, 1, 2, 11),
      );
      await _updateSchedule(database, isEnabled: true, revision: 3);
      await _service(database, DateTime.utc(2026, 1, 3, 9)).reconcile();
      expect(
        await database.select(database.phoneDoseActionEvents).get(),
        isEmpty,
      );
      expect(
        await _checkpointObservedAt(database),
        DateTime.utc(2026, 1, 3, 9),
      );

      await _service(
        database,
        DateTime.utc(2026, 1, 3, 12, 59, 59),
      ).reconcile();
      expect(
        await database.select(database.phoneDoseActionEvents).get(),
        isEmpty,
      );
      await _service(database, DateTime.utc(2026, 1, 3, 13)).reconcile();

      final action = await database
          .select(database.phoneDoseActionEvents)
          .getSingle();
      expect(action.localDate, '2026-01-03');
      expect(action.scheduledAt.toUtc(), DateTime.utc(2026, 1, 3, 11));
      expect(await database.select(database.doseLogEvents).get(), hasLength(1));
      expect(
        await _checkpointObservedAt(database),
        DateTime.utc(2026, 1, 3, 13),
      );
    },
  );

  test('two-hour grace includes its exact deadline', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _schedule(database, prescriptionId: 'medication-1');
    await _service(database, DateTime.utc(2026, 1, 2, 9)).reconcile();

    await _service(database, DateTime.utc(2026, 1, 2, 9, 59, 59)).reconcile();
    expect(
      await database.select(database.phoneDoseActionEvents).get(),
      isEmpty,
    );
    await _service(database, DateTime.utc(2026, 1, 2, 10)).reconcile();

    final action = await database
        .select(database.phoneDoseActionEvents)
        .getSingle();
    expect(action.localDate, '2026-01-02');
    expect(action.scheduledAt.toUtc(), DateTime.utc(2026, 1, 2, 8));
    expect(await _checkpointObservedAt(database), DateTime.utc(2026, 1, 2, 10));
  });

  test('seven-day trusted window excludes its lower boundary', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final lowerBound = DateTime.utc(2026, 1, 1, 11);
    await _schedule(database, prescriptionId: 'medication-1', hour: 9);
    await _service(database, DateTime.utc(2026, 1, 1, 8)).reconcile();

    await _service(
      database,
      lowerBound.add(const Duration(days: 7)),
    ).reconcile();

    final actions = await database.select(database.phoneDoseActionEvents).get();
    expect(
      DateTime.utc(2026, 1, 1, 9).add(const Duration(hours: 2)),
      lowerBound,
    );
    expect(actions, hasLength(7));
    expect(actions.map((action) => action.localDate).toSet(), {
      '2026-01-02',
      '2026-01-03',
      '2026-01-04',
      '2026-01-05',
      '2026-01-06',
      '2026-01-07',
      '2026-01-08',
    });
    expect(actions.any((action) => action.localDate == '2026-01-01'), isFalse);
  });

  test(
    'Los Angeles gap and fold reconcile canonical local occurrences once',
    () async {
      for (final values in [
        (
          localDate: '2026-03-08',
          baseline: DateTime.utc(2026, 3, 8, 9),
          observedAt: DateTime.utc(2026, 3, 8, 12, 30),
          scheduledAt: DateTime.utc(2026, 3, 8, 10, 30),
          hour: 2,
          minute: 30,
        ),
        (
          localDate: '2026-11-01',
          baseline: DateTime.utc(2026, 11, 1, 8),
          observedAt: DateTime.utc(2026, 11, 1, 10, 30),
          scheduledAt: DateTime.utc(2026, 11, 1, 8, 30),
          hour: 1,
          minute: 30,
        ),
      ]) {
        final database = DoseyDatabase.inMemory();
        addTearDown(database.close);
        await _schedule(
          database,
          prescriptionId: 'medication-1',
          hour: values.hour,
          minute: values.minute,
        );
        await _service(
          database,
          values.baseline,
          timezoneId: 'America/Los_Angeles',
        ).reconcile();
        await _service(
          database,
          values.observedAt,
          timezoneId: 'America/Los_Angeles',
        ).reconcile();
        await _service(
          database,
          values.observedAt,
          timezoneId: 'America/Los_Angeles',
        ).reconcile();

        final action = await database
            .select(database.phoneDoseActionEvents)
            .getSingle();
        expect(action.localDate, values.localDate);
        expect(action.scheduledAt.toUtc(), values.scheduledAt);
        expect(
          await database.select(database.doseLogEvents).get(),
          hasLength(1),
        );
        expect(
          await database.select(database.phoneDoseActionEvents).get(),
          hasLength(1),
        );
      }
    },
  );

  test(
    'terminal actions suppress missed only at their intended scope',
    () async {
      for (final values in [
        (
          kind: PhoneDoseActionKind.takenConfirmed,
          deviceId: 'other',
          missed: 0,
        ),
        (kind: PhoneDoseActionKind.skipped, deviceId: 'device-1', missed: 0),
        (kind: PhoneDoseActionKind.skipped, deviceId: 'other', missed: 1),
      ]) {
        final database = DoseyDatabase.inMemory();
        addTearDown(database.close);
        final baseline = DateTime.utc(2026, 1, 2, 9);
        final observedAt = DateTime.utc(2026, 1, 2, 11);
        await _schedule(database, prescriptionId: 'medication-1');
        await _seedUntouchedState(database, baseline);
        await _service(database, baseline).reconcile();
        await PhoneDoseActionService(database).record(
          _actionRequest(
            kind: values.kind,
            deviceId: values.deviceId,
            occurredAt: baseline,
          ),
        );
        final prescriptionBefore = await database
            .select(database.prescriptions)
            .getSingle();

        await _service(database, observedAt).reconcile();

        expect(
          await database.select(database.phoneDoseActionEvents).get(),
          hasLength(1 + values.missed),
        );
        expect(
          await database.select(database.doseLogEvents).get(),
          hasLength(1 + values.missed),
        );
        expect(
          await database.select(database.syncOutboxMutations).get(),
          hasLength(1),
        );
        final prescriptionAfter = await database
            .select(database.prescriptions)
            .getSingle();
        expect(
          prescriptionAfter.availableDoses,
          prescriptionBefore.availableDoses,
        );
        expect(
          prescriptionAfter.remainingDoses,
          prescriptionBefore.remainingDoses,
        );
        final state = await database
            .select(database.carouselStates)
            .getSingle();
        expect(state.activeLoadSessionId, 'load-1');
        expect(state.currentPosition, 2);
      }
    },
  );

  test(
    'runtime validation fails without persisted reconciliation effects',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final invalidConstructors = [
        () => PhoneOnlyMissedDoseReconciliationService(
          database,
          deviceId: () => 'd',
          timezoneId: () => 'UTC',
          now: () => DateTime.utc(2026),
          gracePeriod: Duration.zero,
        ),
        () => PhoneOnlyMissedDoseReconciliationService(
          database,
          deviceId: () => 'd',
          timezoneId: () => 'UTC',
          now: () => DateTime.utc(2026),
          gracePeriod: const Duration(seconds: -1),
        ),
        () => PhoneOnlyMissedDoseReconciliationService(
          database,
          deviceId: () => 'd',
          timezoneId: () => 'UTC',
          now: () => DateTime.utc(2026),
          maxWindow: Duration.zero,
        ),
        () => PhoneOnlyMissedDoseReconciliationService(
          database,
          deviceId: () => 'd',
          timezoneId: () => 'UTC',
          now: () => DateTime.utc(2026),
          maxWindow: const Duration(seconds: -1),
        ),
        () => PhoneOnlyMissedDoseReconciliationService(
          database,
          deviceId: () => 'd',
          timezoneId: () => 'UTC',
          now: () => DateTime.utc(2026),
          maxWindow: const Duration(days: 8),
        ),
      ];
      for (final create in invalidConstructors) {
        expect(create, throwsArgumentError);
      }
      for (final service in [
        PhoneOnlyMissedDoseReconciliationService(
          database,
          deviceId: () => ' ',
          timezoneId: () => 'UTC',
          now: () => DateTime.utc(2026),
        ),
        PhoneOnlyMissedDoseReconciliationService(
          database,
          deviceId: () => 'd',
          timezoneId: () => ' ',
          now: () => DateTime.utc(2026),
        ),
        PhoneOnlyMissedDoseReconciliationService(
          database,
          deviceId: () => 'd',
          timezoneId: () => 'Mars/Olympus_Mons',
          now: () => DateTime.utc(2026),
        ),
        PhoneOnlyMissedDoseReconciliationService(
          database,
          deviceId: () => 'd',
          timezoneId: () => 'UTC',
          now: () => DateTime(2026),
        ),
      ]) {
        await expectLater(
          service.reconcile(),
          throwsA(anyOf(isA<ArgumentError>(), isA<FormatException>())),
        );
      }
      await _expectNoReconciliationRows(database);
    },
  );

  test('portable backup excludes the reconciliation checkpoint', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _schedule(database, prescriptionId: 'medication-1');
    await _service(database, DateTime.utc(2026, 1, 2, 9)).reconcile();

    final snapshot = await LocalBackupStore(database).readSnapshot();

    expect(snapshot.data['settings'], isEmpty);
    expect(
      snapshot.data.values
          .expand((rows) => rows)
          .any(
            (row) =>
                row['key'] ==
                PhoneOnlyMissedDoseReconciliationService.checkpointKey,
          ),
      isFalse,
    );
  });

  test(
    'transaction-internal missed API rejects invalid kinds and preserves replay',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final now = DateTime.utc(2026, 1, 2, 11);
      await _seedUntouchedState(database, now);
      final service = PhoneDoseActionService(database);
      for (final kind in PhoneDoseActionKind.values.where(
        (kind) => kind != PhoneDoseActionKind.missed,
      )) {
        await expectLater(
          database.transaction(
            () => service.recordMissedIfNoTerminalInCurrentTransaction(
              _actionRequest(kind: kind, occurredAt: now),
            ),
          ),
          throwsArgumentError,
        );
      }
      final first = await database.transaction(
        () => service.recordMissedIfNoTerminalInCurrentTransaction(
          _actionRequest(kind: PhoneDoseActionKind.missed, occurredAt: now),
        ),
      );
      final replay = await database.transaction(
        () => service.recordMissedIfNoTerminalInCurrentTransaction(
          _actionRequest(
            kind: PhoneDoseActionKind.missed,
            occurredAt: now.add(const Duration(minutes: 1)),
          ),
        ),
      );
      expect(replay!.eventId, first!.eventId);
      expect(replay.inserted, isFalse);
      await expectLater(
        database.transaction(
          () => service.recordMissedIfNoTerminalInCurrentTransaction(
            _actionRequest(
              kind: PhoneDoseActionKind.missed,
              occurredAt: now,
              medicationId: 'other',
            ),
          ),
        ),
        throwsStateError,
      );
      expect(
        await database.select(database.phoneDoseActionEvents).get(),
        hasLength(1),
      );
      expect(await database.select(database.doseLogEvents).get(), hasLength(1));
      expect(
        await database.select(database.syncOutboxMutations).get(),
        isEmpty,
      );
      await _expectUntouchedState(database);
    },
  );
}

PhoneDoseActionRequest _actionRequest({
  required PhoneDoseActionKind kind,
  required DateTime occurredAt,
  String deviceId = 'device-1',
  String medicationId = 'medication-1',
}) => PhoneDoseActionRequest(
  occurrence: ReminderOccurrence(
    scheduleId: 'schedule-1',
    scheduleRevision: 1,
    scheduledAtUtc: DateTime.utc(2026, 1, 2, 8),
    localDate: '2026-01-02',
    timezoneId: 'UTC',
    medicationId: medicationId,
    profileId: 'schedule-1',
  ),
  kind: kind,
  deviceId: deviceId,
  occurredAt: occurredAt,
);

Future<void> _expectNoReconciliationRows(DoseyDatabase database) async {
  expect(
    await (database.select(database.appSettings)..where(
          (row) => row.key.equals(
            PhoneOnlyMissedDoseReconciliationService.checkpointKey,
          ),
        ))
        .get(),
    isEmpty,
  );
  expect(await database.select(database.phoneDoseActionEvents).get(), isEmpty);
  expect(await database.select(database.doseLogEvents).get(), isEmpty);
  expect(await database.select(database.syncOutboxMutations).get(), isEmpty);
}

PhoneOnlyMissedDoseReconciliationService _service(
  DoseyDatabase database,
  DateTime now, {
  String timezoneId = 'UTC',
}) => PhoneOnlyMissedDoseReconciliationService(
  database,
  deviceId: () => 'device-1',
  timezoneId: () => timezoneId,
  now: () => now,
);

Future<void> _schedule(
  DoseyDatabase database, {
  String id = 'schedule-1',
  required String prescriptionId,
  int hour = 8,
  int minute = 0,
  int revision = 1,
  bool isEnabled = true,
  DateTime? createdAt,
}) => database
    .into(database.reminderSchedules)
    .insert(
      ReminderSchedulesCompanion.insert(
        id: id,
        label: 'Morning',
        prescriptionId: Value(prescriptionId),
        hour: hour,
        minute: minute,
        revision: Value(revision),
        isEnabled: isEnabled,
        createdAt: createdAt ?? DateTime.utc(2026),
        updatedAt: createdAt ?? DateTime.utc(2026),
      ),
    );

Future<void> _updateSchedule(
  DoseyDatabase database, {
  int? hour,
  bool? isEnabled,
  required int revision,
}) =>
    (database.update(
      database.reminderSchedules,
    )..where((row) => row.id.equals('schedule-1'))).write(
      ReminderSchedulesCompanion(
        hour: hour == null ? const Value.absent() : Value(hour),
        isEnabled: isEnabled == null ? const Value.absent() : Value(isEnabled),
        revision: Value(revision),
      ),
    );

Future<DateTime> _checkpointObservedAt(DoseyDatabase database) async =>
    DateTime.parse(
      jsonDecode(
            (await (database.select(database.appSettings)..where(
                      (row) => row.key.equals(
                        PhoneOnlyMissedDoseReconciliationService.checkpointKey,
                      ),
                    ))
                    .getSingle())
                .value,
          )['observedAtUtc']
          as String,
    );

Future<void> _seedUntouchedState(DoseyDatabase database, DateTime now) async {
  await database
      .into(database.prescriptions)
      .insert(
        PrescriptionsCompanion.insert(
          id: 'medication-1',
          name: 'Medication',
          pillType: 'tablet',
          remainingDoses: const Value(3),
          availableDoses: const Value(3),
          loadedDoses: const Value(1),
          reviewDoses: const Value(1),
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.carouselLoadSessions)
      .insert(
        CarouselLoadSessionsCompanion.insert(
          id: 'load-1',
          profileId: 'schedule-1',
          mode: 'full_load',
          status: 'confirmed',
          positionBefore: 2,
          positionAfter: 2,
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.carouselStates)
      .insertOnConflictUpdate(
        CarouselStatesCompanion(
          profileId: const Value('schedule-1'),
          activeLoadSessionId: const Value('load-1'),
          currentPosition: const Value(2),
          updatedAt: Value(now),
        ),
      );
  await database
      .into(database.controllerCommandSessions)
      .insert(
        ControllerCommandSessionsCompanion.insert(
          id: 'controller-1',
          commandType: 'dispense',
          state: 'accepted',
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<void> _expectNoMissedSideEffects(
  DoseyDatabase database,
  DateTime expectedCheckpoint,
) async {
  expect(await database.select(database.phoneDoseActionEvents).get(), isEmpty);
  expect(await database.select(database.doseLogEvents).get(), isEmpty);
  expect(await database.select(database.syncOutboxMutations).get(), isEmpty);
  expect(
    jsonDecode(
      (await (database.select(database.appSettings)..where(
                (row) => row.key.equals(
                  PhoneOnlyMissedDoseReconciliationService.checkpointKey,
                ),
              ))
              .getSingle())
          .value,
    )['observedAtUtc'],
    expectedCheckpoint.toIso8601String(),
  );
  await _expectUntouchedState(database);
}

Future<void> _expectUntouchedState(DoseyDatabase database) async {
  final prescription = await database
      .select(database.prescriptions)
      .getSingle();
  expect(prescription.remainingDoses, 3);
  expect(prescription.availableDoses, 3);
  expect(prescription.loadedDoses, 1);
  expect(prescription.reviewDoses, 1);
  final load = await database.select(database.carouselLoadSessions).getSingle();
  expect(load.status, 'confirmed');
  final state = await database.select(database.carouselStates).getSingle();
  expect(state.activeLoadSessionId, 'load-1');
  expect(state.currentPosition, 2);
  final controller = await database
      .select(database.controllerCommandSessions)
      .getSingle();
  expect(controller.id, 'controller-1');
  expect(controller.state, 'accepted');
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
    if (_isWriterIntent(statement)) {
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
    if (handled || !_isWriterIntent(statement)) {
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

bool _isWriterIntent(String statement) =>
    statement ==
    'UPDATE app_settings SET updated_at = updated_at WHERE key = ?';
