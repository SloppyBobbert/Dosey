import 'dart:async';
import 'dart:io';

import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/common.dart' show SqlError, SqliteException;

void main() {
  test('local reminder repository starts empty', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalReminderRepository(database);

    expect(await repository.watchSchedules().first, isEmpty);
  });

  test('local reminder repository persists schedules', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalReminderRepository(database);
    final createdAt = DateTime.utc(2026, 6, 9, 8);
    final schedule = ReminderSchedule(
      id: 'morning',
      label: 'Morning dose',
      hour: 8,
      minute: 30,
      isEnabled: true,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    await repository.upsertSchedule(schedule);

    final schedules = await repository.watchSchedules().first;
    expect(schedules, hasLength(1));
    expect(schedules.single.id, 'morning');
    expect(schedules.single.label, 'Morning dose');
    expect(schedules.single.hour, 8);
    expect(schedules.single.minute, 30);
    expect(schedules.single.isEnabled, isTrue);
    expect(schedules.single.createdAt, createdAt);
    expect(schedules.single.updatedAt, createdAt);
  });

  test('local reminder repository links schedules to prescriptions', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalReminderRepository(database);
    final createdAt = DateTime.utc(2026, 6, 9, 8);

    await repository.upsertSchedule(
      ReminderSchedule(
        id: 'morning-vitamin',
        label: 'Vitamin D',
        prescriptionId: 'vitamin-d',
        hour: 8,
        minute: 30,
        isEnabled: true,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );

    final schedule = (await repository.watchSchedules().first).single;
    expect(schedule.prescriptionId, 'vitamin-d');
    expect(schedule.profileId, 'schedule-1');
    expect(schedule.label, 'Vitamin D');
  });

  test('local reminder repository owns occurrence revisions', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalReminderRepository(database);
    final now = DateTime.utc(2026, 6, 9, 8);
    final original = ReminderSchedule(
      id: 'morning',
      label: 'Morning dose',
      prescriptionId: 'vitamin-d',
      hour: 8,
      minute: 30,
      isEnabled: true,
      createdAt: now,
      updatedAt: now,
    );

    await repository.upsertSchedule(original);
    expect(
      (await database.select(database.reminderSchedules).getSingle()).revision,
      1,
    );

    await repository.upsertSchedule(
      original.copyWith(
        label: 'Morning vitamin',
        updatedAt: now.add(const Duration(minutes: 1)),
      ),
    );
    expect(
      (await database.select(database.reminderSchedules).getSingle()).revision,
      1,
    );

    var occurrenceEdit = original.copyWith(
      hour: 9,
      updatedAt: now.add(const Duration(minutes: 2)),
    );
    await repository.upsertSchedule(occurrenceEdit);
    expect(
      (await database.select(database.reminderSchedules).getSingle()).revision,
      2,
    );

    occurrenceEdit = occurrenceEdit.copyWith(
      minute: 31,
      updatedAt: now.add(const Duration(minutes: 3)),
    );
    await repository.upsertSchedule(occurrenceEdit);
    occurrenceEdit = occurrenceEdit.copyWith(
      prescriptionId: 'vitamin-d-2',
      updatedAt: now.add(const Duration(minutes: 4)),
    );
    await repository.upsertSchedule(occurrenceEdit);
    occurrenceEdit = occurrenceEdit.copyWith(
      profileId: 'travel',
      updatedAt: now.add(const Duration(minutes: 5)),
    );
    await repository.upsertSchedule(occurrenceEdit);
    occurrenceEdit = occurrenceEdit.copyWith(
      isEnabled: false,
      updatedAt: now.add(const Duration(minutes: 6)),
    );
    await repository.upsertSchedule(occurrenceEdit);
    expect(
      (await database.select(database.reminderSchedules).getSingle()).revision,
      6,
    );
    occurrenceEdit = occurrenceEdit.copyWith(
      isEnabled: true,
      updatedAt: now.add(const Duration(minutes: 7)),
    );
    await repository.upsertSchedule(occurrenceEdit);
    expect(
      (await database.select(database.reminderSchedules).getSingle()).revision,
      7,
    );
    await repository.upsertSchedule(
      occurrenceEdit.copyWith(updatedAt: now.add(const Duration(minutes: 8))),
    );
    expect(
      (await database.select(database.reminderSchedules).getSingle()).revision,
      7,
    );
  });

  test(
    'concurrent schedule writes retry after writer-intent contention',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'dosey-reminder-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/dosey.sqlite');
      final firstDatabase = DoseyDatabase(NativeDatabase(file));
      final secondDatabase = DoseyDatabase(NativeDatabase(file));
      addTearDown(firstDatabase.close);
      addTearDown(secondDatabase.close);
      final now = DateTime.utc(2026, 6, 9, 8);
      final original = ReminderSchedule(
        id: 'morning',
        label: 'Morning dose',
        prescriptionId: 'vitamin-d',
        hour: 8,
        minute: 30,
        isEnabled: true,
        createdAt: now,
        updatedAt: now,
      );
      await LocalReminderRepository(firstDatabase).upsertSchedule(original);
      final lock = _WriterIntentLock();
      addTearDown(() {
        if (!lock.releaseFirstWriter.isCompleted) {
          lock.releaseFirstWriter.complete();
        }
      });
      final firstAudit = _auditEvent('first-audit', now);
      final secondAudit = _auditEvent('second-audit', now);
      final first = firstDatabase.runWithInterceptor(
        () => LocalReminderRepository(firstDatabase).upsertSchedule(
          original.copyWith(
            hour: 9,
            updatedAt: now.add(const Duration(minutes: 1)),
          ),
          auditEvent: firstAudit,
        ),
        interceptor: _WriterIntentInterceptor(lock, pauseAfterLock: true),
      );
      await lock.firstWriterLocked.future.timeout(const Duration(seconds: 2));
      final second = secondDatabase.runWithInterceptor(
        () => LocalReminderRepository(secondDatabase).upsertSchedule(
          original.copyWith(
            hour: 10,
            updatedAt: now.add(const Duration(minutes: 2)),
          ),
          auditEvent: secondAudit,
        ),
        interceptor: _WriterIntentInterceptor(lock),
      );
      await lock.secondWriterBusy.future.timeout(const Duration(seconds: 2));
      lock.releaseFirstWriter.complete();
      await Future.wait([first, second]);

      final saved = await secondDatabase
          .select(secondDatabase.reminderSchedules)
          .getSingle();
      expect(saved.revision, 3);
      expect(saved.hour, anyOf(9, 10));
      final audits = await secondDatabase
          .select(secondDatabase.adminAuditEvents)
          .get();
      expect(audits.where((event) => event.id == firstAudit.id), hasLength(1));
      expect(audits.where((event) => event.id == secondAudit.id), hasLength(1));
    },
  );

  test('retries only typed SQLite busy failures up to four attempts', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final now = DateTime.utc(2026, 6, 9, 8);
    final schedule = ReminderSchedule(
      id: 'morning',
      label: 'Morning dose',
      hour: 8,
      minute: 30,
      isEnabled: true,
      createdAt: now,
      updatedAt: now,
    );

    final busyOnce = _ThrowingWriterIntentInterceptor(
      errors: [_sqliteError(SqlError.SQLITE_BUSY)],
    );
    await database.runWithInterceptor(
      () => LocalReminderRepository(database).upsertSchedule(schedule),
      interceptor: busyOnce,
    );
    expect(busyOnce.attempts, 2);

    final nonBusy = _ThrowingWriterIntentInterceptor(
      errors: [_sqliteError(SqlError.SQLITE_CONSTRAINT)],
    );
    await expectLater(
      database.runWithInterceptor(
        () => LocalReminderRepository(
          database,
        ).upsertSchedule(schedule.copyWith(hour: 9)),
        interceptor: nonBusy,
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(nonBusy.attempts, 1);

    final permanentBusy = _ThrowingWriterIntentInterceptor(
      errors: List<SqliteException>.filled(
        4,
        _sqliteError(SqlError.SQLITE_BUSY),
      ).toList(),
    );
    await expectLater(
      database.runWithInterceptor(
        () => LocalReminderRepository(
          database,
        ).upsertSchedule(schedule.copyWith(hour: 10)),
        interceptor: permanentBusy,
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(permanentBusy.attempts, 4);
    expect(
      (await database.select(database.reminderSchedules).getSingle()).hour,
      8,
    );
  });

  test('late non-busy failures roll back all schedule side effects', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalReminderRepository(database);
    final now = DateTime.utc(2026, 6, 9, 8);
    final original = ReminderSchedule(
      id: 'morning',
      label: 'Morning dose',
      prescriptionId: 'vitamin-d',
      hour: 8,
      minute: 30,
      isEnabled: true,
      createdAt: now,
      updatedAt: now,
    );
    await repository.upsertSchedule(original);
    await LocalCarouselSlotRepository(database).assignSlot(
      CarouselSlot(
        id: 'slot-1',
        slotNumber: 1,
        prescriptionId: 'vitamin-d',
        scheduleId: 'morning',
        profileId: ReminderSchedule.defaultProfileId,
        status: CarouselSlotStatus.loaded,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await database
        .into(database.carouselLoadSessions)
        .insert(
          CarouselLoadSessionsCompanion.insert(
            id: 'load-1',
            profileId: ReminderSchedule.defaultProfileId,
            mode: 'full_load',
            status: 'confirmed',
            positionBefore: 0,
            positionAfter: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.carouselStates)
        .insertOnConflictUpdate(
          CarouselStatesCompanion(
            profileId: Value(ReminderSchedule.defaultProfileId),
            activeLoadSessionId: const Value('load-1'),
            currentPosition: const Value(0),
            updatedAt: Value(now),
          ),
        );
    final interceptor = _LateNonBusyFailureInterceptor('caller-audit');

    await expectLater(
      database.runWithInterceptor(
        () => repository.upsertSchedule(
          original.copyWith(
            prescriptionId: 'allergy-pill',
            updatedAt: now.add(const Duration(minutes: 1)),
          ),
          auditEvent: _auditEvent('caller-audit', now),
        ),
        interceptor: interceptor,
      ),
      throwsA(isA<SqliteException>()),
    );

    final schedule = await database
        .select(database.reminderSchedules)
        .getSingle();
    final slot = await database.select(database.carouselSlots).getSingle();
    final load = await database
        .select(database.carouselLoadSessions)
        .getSingle();
    expect(schedule.prescriptionId, 'vitamin-d');
    expect(schedule.revision, 1);
    expect(slot.id, 'slot-1');
    expect(load.status, 'confirmed');
    expect(await database.select(database.adminAuditEvents).get(), isEmpty);
    expect(interceptor.writerIntentAttempts, 1);
  });

  test('local reminder repository scopes duplicates to one profile', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalReminderRepository(database);
    final createdAt = DateTime.utc(2026, 6, 9, 8);

    await repository.upsertSchedule(
      ReminderSchedule(
        id: 'normal-morning-vitamin',
        label: 'Vitamin D',
        prescriptionId: 'vitamin-d',
        profileId: 'schedule-1',
        hour: 8,
        minute: 30,
        isEnabled: true,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );
    await repository.upsertSchedule(
      ReminderSchedule(
        id: 'travel-morning-vitamin',
        label: 'Vitamin D',
        prescriptionId: 'vitamin-d',
        profileId: 'travel',
        hour: 8,
        minute: 30,
        isEnabled: true,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );

    final schedules = await repository.watchSchedules().first;
    expect(schedules, hasLength(2));
    expect(
      await repository.watchSchedules(profileId: 'schedule-1').first,
      hasLength(1),
    );
    expect(
      await repository.watchSchedules(profileId: 'travel').first,
      hasLength(1),
    );
  });

  test(
    'local reminder repository rejects duplicate prescription times',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalReminderRepository(database);
      final createdAt = DateTime.utc(2026, 6, 9, 8);

      await repository.upsertSchedule(
        ReminderSchedule(
          id: 'morning-vitamin',
          label: 'Vitamin D',
          prescriptionId: 'vitamin-d',
          hour: 8,
          minute: 30,
          isEnabled: true,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );

      expect(
        () => repository.upsertSchedule(
          ReminderSchedule(
            id: 'duplicate-morning-vitamin',
            label: 'Vitamin D',
            prescriptionId: 'vitamin-d',
            profileId: 'schedule-1',
            hour: 8,
            minute: 30,
            isEnabled: true,
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'A schedule already exists for this prescription at 08:30.',
          ),
        ),
      );
    },
  );

  test('local reminder repository deletes schedules', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalReminderRepository(database);
    final now = DateTime.utc(2026, 6, 9, 8);

    await repository.upsertSchedule(
      ReminderSchedule(
        id: 'evening',
        label: 'Evening dose',
        hour: 20,
        minute: 0,
        isEnabled: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.deleteSchedule('evening');

    expect(await repository.watchSchedules().first, isEmpty);
  });

  test('local reminder repository deletes linked carousel slots', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalReminderRepository(database);
    final now = DateTime.utc(2026, 6, 9, 8);

    await repository.upsertSchedule(
      ReminderSchedule(
        id: 'morning',
        label: 'Morning dose',
        prescriptionId: 'vitamin-d',
        hour: 8,
        minute: 30,
        isEnabled: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await LocalCarouselSlotRepository(database).assignSlot(
      CarouselSlot(
        id: 'slot-1',
        slotNumber: 1,
        prescriptionId: 'vitamin-d',
        scheduleId: 'morning',
        profileId: ReminderSchedule.defaultProfileId,
        status: CarouselSlotStatus.loaded,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await repository.deleteSchedule('morning');

    expect(await repository.watchSchedules().first, isEmpty);
    expect(await database.select(database.carouselSlots).get(), isEmpty);
  });

  test(
    'local reminder repository clears carousel slots when prescription changes',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalReminderRepository(database);
      final now = DateTime.utc(2026, 6, 9, 8);

      await repository.upsertSchedule(
        ReminderSchedule(
          id: 'morning',
          label: 'Vitamin D',
          prescriptionId: 'vitamin-d',
          hour: 8,
          minute: 30,
          isEnabled: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.upsertSchedule(
        ReminderSchedule(
          id: 'noon',
          label: 'Allergy pill',
          prescriptionId: 'allergy-pill',
          hour: 12,
          minute: 0,
          isEnabled: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final carouselSlots = LocalCarouselSlotRepository(database);
      await carouselSlots.assignSlot(
        CarouselSlot(
          id: 'slot-1',
          slotNumber: 1,
          prescriptionId: 'vitamin-d',
          scheduleId: 'morning',
          profileId: ReminderSchedule.defaultProfileId,
          status: CarouselSlotStatus.loaded,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await carouselSlots.assignSlot(
        CarouselSlot(
          id: 'slot-2',
          slotNumber: 2,
          prescriptionId: 'allergy-pill',
          scheduleId: 'noon',
          profileId: ReminderSchedule.defaultProfileId,
          status: CarouselSlotStatus.loaded,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await repository.upsertSchedule(
        ReminderSchedule(
          id: 'morning',
          label: 'Allergy pill',
          prescriptionId: 'allergy-pill',
          hour: 8,
          minute: 30,
          isEnabled: true,
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );

      final schedules = await repository.watchSchedules().first;
      expect(schedules, hasLength(2));
      final schedule = schedules.singleWhere(
        (schedule) => schedule.id == 'morning',
      );
      expect(schedule.prescriptionId, 'allergy-pill');

      final slots = await database.select(database.carouselSlots).get();
      expect(slots, hasLength(1));
      expect(slots.single.id, 'slot-2');
      expect(slots.single.scheduleId, 'noon');
      expect(slots.single.prescriptionId, 'allergy-pill');
    },
  );

  test('local reminder repository rejects invalid reminder times', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalReminderRepository(database);
    final now = DateTime.utc(2026, 6, 9, 8);

    expect(
      () => repository.upsertSchedule(
        ReminderSchedule(
          id: 'bad-hour',
          label: 'Bad hour',
          hour: 24,
          minute: 0,
          isEnabled: true,
          createdAt: now,
          updatedAt: now,
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => repository.upsertSchedule(
        ReminderSchedule(
          id: 'bad-minute',
          label: 'Bad minute',
          hour: 8,
          minute: 60,
          isEnabled: true,
          createdAt: now,
          updatedAt: now,
        ),
      ),
      throwsArgumentError,
    );
  });
}

AdminAuditEvent _auditEvent(String id, DateTime occurredAt) => AdminAuditEvent(
  id: id,
  eventType: AdminAuditEventType.scheduleSaved,
  targetType: AdminAuditTargetType.reminderSchedule,
  targetId: 'morning',
  actorType: AdminAuditActorType.localAdmin,
  actorLabel: 'local admin',
  sourceDeviceRole: 'androidPersonal',
  summary: 'saved schedule',
  occurredAt: occurredAt,
);

SqliteException _sqliteError(int code) => SqliteException(
  extendedResultCode: code,
  message: 'injected sqlite failure',
);

class _WriterIntentLock {
  final firstWriterLocked = Completer<void>();
  final secondWriterBusy = Completer<void>();
  final releaseFirstWriter = Completer<void>();
}

class _WriterIntentInterceptor extends QueryInterceptor {
  _WriterIntentInterceptor(this._lock, {this.pauseAfterLock = false});

  final _WriterIntentLock _lock;
  final bool pauseAfterLock;
  var _handled = false;

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (_handled || !_isWriterIntent(statement)) {
      return executor.runUpdate(statement, args);
    }
    _handled = true;
    try {
      final result = await executor.runUpdate(statement, args);
      if (pauseAfterLock) {
        _lock.firstWriterLocked.complete();
        await _lock.releaseFirstWriter.future;
      }
      return result;
    } on SqliteException catch (error) {
      if (error.resultCode == SqlError.SQLITE_BUSY &&
          !_lock.secondWriterBusy.isCompleted) {
        _lock.secondWriterBusy.complete();
      }
      rethrow;
    }
  }
}

class _ThrowingWriterIntentInterceptor extends QueryInterceptor {
  _ThrowingWriterIntentInterceptor({required this.errors});

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

class _LateNonBusyFailureInterceptor extends QueryInterceptor {
  _LateNonBusyFailureInterceptor(this.auditId);

  final String auditId;
  var writerIntentAttempts = 0;

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (_isWriterIntent(statement)) writerIntentAttempts += 1;
    return executor.runUpdate(statement, args);
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (statement.contains('admin_audit_events') && args.contains(auditId)) {
      throw _sqliteError(SqlError.SQLITE_CONSTRAINT);
    }
    return executor.runInsert(statement, args);
  }
}

bool _isWriterIntent(String statement) =>
    statement ==
    'UPDATE reminder_schedules SET revision = revision WHERE id = ?';
