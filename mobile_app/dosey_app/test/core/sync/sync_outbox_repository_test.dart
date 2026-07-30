import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/sync/sync_outbox_repository.dart';
import 'package:dosey_app/core/sync/sync_outbox_scope.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final scope = SyncOutboxScope(
    actorAccountId: 'account-1',
    robotId: 'robot-1',
  );
  late DoseyDatabase database;
  late DriftSyncOutboxRepository repository;

  setUp(() {
    database = DoseyDatabase.inMemory();
    repository = DriftSyncOutboxRepository(database);
  });

  tearDown(() => database.close());

  test('reads only eligible pending mutations in creation order', () async {
    final now = DateTime.utc(2026, 7, 30, 12);
    await _insert(
      database,
      id: 'later',
      createdAt: now.add(Duration(minutes: 2)),
    );
    await _insert(database, id: 'first', createdAt: now);
    await _insert(
      database,
      id: 'deferred',
      createdAt: now.add(Duration(minutes: 1)),
      nextAttemptAt: now.add(Duration(minutes: 5)),
    );

    final eligible = await repository.readEligible(
      scope: scope,
      now: now,
      limit: 10,
    );

    expect(eligible.map((row) => row.mutationId), ['first', 'later']);
  });

  test(
    'claim is bounded and duplicate drain attempts cannot reclaim',
    () async {
      final now = DateTime.utc(2026, 7, 30, 12);
      await _insert(database, id: 'mutation-1', createdAt: now);

      final claimed = await repository.claimEligible(
        scope: scope,
        now: now,
        limit: 1,
      );
      final duplicateClaim = await repository.claimEligible(
        scope: scope,
        now: now,
        limit: 1,
      );

      expect(claimed.map((row) => row.mutationId), ['mutation-1']);
      expect(duplicateClaim, isEmpty);
      var row = await _row(database, 'mutation-1');
      expect(row.state, 'in_flight');
      expect(row.attemptCount, 1);

      expect(
        () => repository.readEligible(scope: scope, now: now, limit: 101),
        throwsRangeError,
      );

      expect(
        await repository.markRetry(
          'mutation-1',
          scope: scope,
          expectedAttemptCount: 2,
          errorCode: 'stale',
          nextAttemptAt: now.add(Duration(minutes: 1)),
          updatedAt: now,
        ),
        isFalse,
      );
      expect(
        await repository.markRetry(
          'mutation-1',
          scope: scope,
          expectedAttemptCount: 1,
          errorCode: 'offline',
          nextAttemptAt: now.add(Duration(minutes: 1)),
          updatedAt: now,
        ),
        isTrue,
      );
      row = await _row(database, 'mutation-1');
      expect(row.state, 'pending');
      expect(row.lastErrorCode, 'offline');
      expect(
        await repository.readEligible(
          now: now.add(Duration(seconds: 30)),
          scope: scope,
          limit: 10,
        ),
        isEmpty,
      );

      await repository.claimEligible(
        scope: scope,
        now: now.add(Duration(minutes: 1)),
        limit: 1,
      );
      expect(
        await repository.markSucceeded(
          'mutation-1',
          scope: scope,
          expectedAttemptCount: 1,
          updatedAt: now,
        ),
        isFalse,
      );
      expect(
        await repository.markSucceeded(
          'mutation-1',
          scope: scope,
          expectedAttemptCount: 2,
          updatedAt: now,
        ),
        isTrue,
      );
      expect((await _row(database, 'mutation-1')).state, 'succeeded');
    },
  );

  test('restart recovery returns stale in-flight work to pending', () async {
    final now = DateTime.utc(2026, 7, 30, 12);
    await _insert(database, id: 'mutation-1', createdAt: now);
    await repository.claimEligible(scope: scope, now: now, limit: 1);

    final afterRestart = DriftSyncOutboxRepository(database);
    expect(
      await afterRestart.recoverStaleInFlight(
        staleBefore: now.add(Duration(minutes: 5)),
        recoveredAt: now.add(Duration(minutes: 10)),
        scope: scope,
      ),
      1,
    );

    final row = await _row(database, 'mutation-1');
    expect(row.state, 'pending');
    expect(row.attemptCount, 1);
    expect(row.lastErrorCode, 'attempt_interrupted');
    expect(
      await afterRestart.claimEligible(
        now: now.add(Duration(minutes: 10)),
        limit: 1,
        scope: scope,
      ),
      hasLength(1),
    );
  });

  test('permanent failure requires the current in-flight attempt', () async {
    final now = DateTime.utc(2026, 7, 30, 12);
    await _insert(database, id: 'mutation-1', createdAt: now);
    await repository.claimEligible(scope: scope, now: now, limit: 1);

    expect(
      await repository.markFailed(
        'mutation-1',
        scope: scope,
        expectedAttemptCount: 2,
        errorCode: 'stale',
        updatedAt: now,
      ),
      isFalse,
    );
    expect(
      await repository.markFailed(
        'mutation-1',
        scope: scope,
        expectedAttemptCount: 1,
        errorCode: 'invalid_payload',
        updatedAt: now,
      ),
      isTrue,
    );

    final row = await _row(database, 'mutation-1');
    expect(row.state, 'permanent_failure');
    expect(row.lastErrorCode, 'invalid_payload');
  });

  test('unconfigured drain leaves pending work unchanged', () async {
    final now = DateTime.utc(2026, 7, 30, 12);
    await _insert(database, id: 'mutation-1', createdAt: now);

    await const DisabledMedicationSyncOutboxDrain().drain();

    final row = await _row(database, 'mutation-1');
    expect(row.state, 'pending');
    expect(row.attemptCount, 0);
  });

  test('local-only and other account Robot scopes are never claimed', () async {
    final now = DateTime.utc(2026, 7, 30, 12);
    await _insert(database, id: 'bound', createdAt: now);
    await _insert(database, id: 'local', createdAt: now, localOnly: true);

    final wrongScope = SyncOutboxScope(
      actorAccountId: 'account-2',
      robotId: 'robot-2',
    );
    expect(
      await repository.claimEligible(scope: wrongScope, now: now, limit: 10),
      isEmpty,
    );
    final claimed = await repository.claimEligible(
      scope: scope,
      now: now,
      limit: 10,
    );
    expect(claimed.map((row) => row.mutationId), ['bound']);
    expect(
      await repository.markSucceeded(
        'bound',
        scope: wrongScope,
        expectedAttemptCount: 1,
        updatedAt: now,
      ),
      isFalse,
    );
    expect((await _row(database, 'bound')).state, 'in_flight');
    expect((await _row(database, 'local')).state, 'pending');
  });

  test('database rejects partial and rebound scopes', () async {
    final now = DateTime.utc(2026, 7, 30, 12);
    expect(
      () => database.customStatement(
        '''INSERT INTO sync_outbox_mutations
        (mutation_id, device_id, actor_account_id, robot_id, scope_state,
         idempotency_key, entity_type, operation, entity_id, payload_json,
         state, attempt_count, created_at, updated_at)
        VALUES (?, ?, ?, NULL, 'bound', ?, ?, ?, ?, ?, 'pending', 0, ?, ?)''',
        [
          'bad',
          'device',
          'account-1',
          'bad-key',
          'dose_event',
          'append',
          'event',
          '{}',
          now.millisecondsSinceEpoch ~/ 1000,
          now.millisecondsSinceEpoch ~/ 1000,
        ],
      ),
      throwsA(isA<Exception>()),
    );
    await _insert(database, id: 'immutable', createdAt: now);
    expect(
      () => database.customStatement(
        "UPDATE sync_outbox_mutations SET robot_id = 'robot-2' WHERE mutation_id = 'immutable'",
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('idempotency keys are unique within local or Robot scope', () async {
    final now = DateTime.utc(2026, 7, 30, 12);
    await _insert(
      database,
      id: 'local-1',
      createdAt: now,
      localOnly: true,
      idempotencyKey: 'shared-key',
    );
    await _insert(
      database,
      id: 'robot-1-account-1',
      createdAt: now,
      idempotencyKey: 'shared-key',
    );
    await _insert(
      database,
      id: 'robot-2-account-1',
      createdAt: now,
      robotId: 'robot-2',
      idempotencyKey: 'shared-key',
    );

    expect(
      () => _insert(
        database,
        id: 'local-duplicate',
        createdAt: now,
        localOnly: true,
        idempotencyKey: 'shared-key',
      ),
      throwsA(isA<Exception>()),
    );
    expect(
      () => _insert(
        database,
        id: 'robot-1-other-actor',
        createdAt: now,
        actorAccountId: 'account-2',
        idempotencyKey: 'shared-key',
      ),
      throwsA(isA<Exception>()),
    );
    expect(
      await database.select(database.syncOutboxMutations).get(),
      hasLength(3),
    );
  });
}

Future<void> _insert(
  DoseyDatabase database, {
  required String id,
  required DateTime createdAt,
  DateTime? nextAttemptAt,
  bool localOnly = false,
  String actorAccountId = 'account-1',
  String robotId = 'robot-1',
  String? idempotencyKey,
}) {
  return database
      .into(database.syncOutboxMutations)
      .insert(
        SyncOutboxMutationsCompanion.insert(
          mutationId: id,
          deviceId: 'device-1',
          actorAccountId: Value(localOnly ? null : actorAccountId),
          robotId: Value(localOnly ? null : robotId),
          scopeState: Value(localOnly ? 'local_only' : 'bound'),
          idempotencyKey: idempotencyKey ?? 'key-$id',
          entityType: 'dose_event',
          operation: 'append',
          entityId: 'event-$id',
          payloadJson: '{}',
          nextAttemptAt: Value(nextAttemptAt),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
}

Future<SyncOutboxMutationRow> _row(DoseyDatabase database, String id) {
  return (database.select(
    database.syncOutboxMutations,
  )..where((row) => row.mutationId.equals(id))).getSingle();
}
