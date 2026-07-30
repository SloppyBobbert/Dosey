import 'package:drift/drift.dart';

import '../storage/dosey_database.dart';
import 'sync_outbox_scope.dart';

abstract interface class MedicationSyncOutboxDrain {
  Future<void> drain();
}

/// Used until the shared medication-sync contract and transport are integrated.
final class DisabledMedicationSyncOutboxDrain
    implements MedicationSyncOutboxDrain {
  const DisabledMedicationSyncOutboxDrain();

  @override
  Future<void> drain() async {}
}

final class DriftSyncOutboxRepository {
  DriftSyncOutboxRepository(this._database);

  static const int maxBatchSize = 100;

  final DoseyDatabase _database;

  Future<List<SyncOutboxMutationRow>> readEligible({
    required SyncOutboxScope scope,
    required DateTime now,
    required int limit,
  }) {
    _validateLimit(limit);
    final query = _database.select(_database.syncOutboxMutations)
      ..where(
        (row) =>
            row.state.equals('pending') &
            row.scopeState.equals('bound') &
            row.actorAccountId.equals(scope.actorAccountId) &
            row.robotId.equals(scope.robotId) &
            (row.nextAttemptAt.isNull() |
                row.nextAttemptAt.isSmallerOrEqualValue(now)),
      )
      ..orderBy([
        (row) => OrderingTerm.asc(row.createdAt),
        (row) => OrderingTerm.asc(row.mutationId),
      ])
      ..limit(limit);
    return query.get();
  }

  Future<List<SyncOutboxMutationRow>> claimEligible({
    required SyncOutboxScope scope,
    required DateTime now,
    required int limit,
  }) {
    _validateLimit(limit);
    return _database.transaction(() async {
      final eligible = await readEligible(scope: scope, now: now, limit: limit);
      final claimed = <SyncOutboxMutationRow>[];
      for (final candidate in eligible) {
        final update = _database.update(_database.syncOutboxMutations)
          ..where(
            (row) =>
                row.mutationId.equals(candidate.mutationId) &
                row.scopeState.equals('bound') &
                row.actorAccountId.equals(scope.actorAccountId) &
                row.robotId.equals(scope.robotId) &
                row.state.equals('pending') &
                row.attemptCount.equals(candidate.attemptCount) &
                (row.nextAttemptAt.isNull() |
                    row.nextAttemptAt.isSmallerOrEqualValue(now)),
          );
        final changed = await update.write(
          SyncOutboxMutationsCompanion(
            state: const Value('in_flight'),
            attemptCount: Value(candidate.attemptCount + 1),
            nextAttemptAt: const Value(null),
            lastAttemptAt: Value(now),
            lastErrorCode: const Value(null),
            updatedAt: Value(now),
          ),
        );
        if (changed == 1) {
          claimed.add(await _rowById(candidate.mutationId));
        }
      }
      return claimed;
    });
  }

  Future<bool> markRetry(
    String mutationId, {
    required SyncOutboxScope scope,
    required int expectedAttemptCount,
    required String errorCode,
    required DateTime nextAttemptAt,
    required DateTime updatedAt,
  }) {
    return _transitionCurrentAttempt(
      mutationId,
      scope: scope,
      expectedAttemptCount: expectedAttemptCount,
      companion: SyncOutboxMutationsCompanion(
        state: const Value('pending'),
        nextAttemptAt: Value(nextAttemptAt),
        lastErrorCode: Value(errorCode),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<bool> markSucceeded(
    String mutationId, {
    required SyncOutboxScope scope,
    required int expectedAttemptCount,
    required DateTime updatedAt,
  }) {
    return _transitionCurrentAttempt(
      mutationId,
      scope: scope,
      expectedAttemptCount: expectedAttemptCount,
      companion: SyncOutboxMutationsCompanion(
        state: const Value('succeeded'),
        nextAttemptAt: const Value(null),
        lastErrorCode: const Value(null),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<bool> markFailed(
    String mutationId, {
    required SyncOutboxScope scope,
    required int expectedAttemptCount,
    required String errorCode,
    required DateTime updatedAt,
  }) {
    return _transitionCurrentAttempt(
      mutationId,
      scope: scope,
      expectedAttemptCount: expectedAttemptCount,
      companion: SyncOutboxMutationsCompanion(
        state: const Value('permanent_failure'),
        nextAttemptAt: const Value(null),
        lastErrorCode: Value(errorCode),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<bool> recordAcknowledgement(
    String mutationId, {
    required SyncOutboxScope scope,
    required int expectedAttemptCount,
    required String outcome,
    required int? revision,
    required String? cursor,
    required String? errorCode,
    required String? conflictJson,
    required DateTime acknowledgedAt,
  }) {
    if (!const {
      'applied',
      'duplicate',
      'conflict',
      'rejected',
    }.contains(outcome)) {
      throw ArgumentError.value(outcome, 'outcome');
    }
    final succeeded = outcome == 'applied' || outcome == 'duplicate';
    final storedErrorCode = switch (outcome) {
      'conflict' => 'conflict',
      'rejected' => errorCode ?? 'rejected',
      _ => null,
    };
    return _database.transaction(() async {
      final transitioned = await _transitionCurrentAttempt(
        mutationId,
        scope: scope,
        expectedAttemptCount: expectedAttemptCount,
        companion: SyncOutboxMutationsCompanion(
          state: Value(succeeded ? 'succeeded' : 'permanent_failure'),
          nextAttemptAt: const Value(null),
          lastErrorCode: Value(storedErrorCode),
          updatedAt: Value(acknowledgedAt),
        ),
      );
      if (!transitioned) return false;
      await _database
          .into(_database.syncConflicts)
          .insertOnConflictUpdate(
            SyncConflictsCompanion.insert(
              mutationId: mutationId,
              outcome: outcome,
              revision: Value(revision),
              cursor: Value(cursor),
              errorCode: Value(errorCode),
              conflictJson: Value(conflictJson),
              createdAt: acknowledgedAt,
            ),
          );
      return true;
    });
  }

  Future<int> recoverStaleInFlight({
    required SyncOutboxScope scope,
    required DateTime staleBefore,
    required DateTime recoveredAt,
  }) {
    final update = _database.update(_database.syncOutboxMutations)
      ..where(
        (row) =>
            row.state.equals('in_flight') &
            row.scopeState.equals('bound') &
            row.actorAccountId.equals(scope.actorAccountId) &
            row.robotId.equals(scope.robotId) &
            (row.lastAttemptAt.isNull() |
                row.lastAttemptAt.isSmallerOrEqualValue(staleBefore)),
      );
    return update.write(
      SyncOutboxMutationsCompanion(
        state: const Value('pending'),
        nextAttemptAt: Value(recoveredAt),
        lastErrorCode: const Value('attempt_interrupted'),
        updatedAt: Value(recoveredAt),
      ),
    );
  }

  Future<bool> _transitionCurrentAttempt(
    String mutationId, {
    required SyncOutboxScope scope,
    required int expectedAttemptCount,
    required SyncOutboxMutationsCompanion companion,
  }) async {
    final update = _database.update(_database.syncOutboxMutations)
      ..where(
        (row) =>
            row.mutationId.equals(mutationId) &
            row.scopeState.equals('bound') &
            row.actorAccountId.equals(scope.actorAccountId) &
            row.robotId.equals(scope.robotId) &
            row.state.equals('in_flight') &
            row.attemptCount.equals(expectedAttemptCount),
      );
    return await update.write(companion) == 1;
  }

  Future<SyncOutboxMutationRow> _rowById(String mutationId) {
    final query = _database.select(_database.syncOutboxMutations)
      ..where((row) => row.mutationId.equals(mutationId));
    return query.getSingle();
  }

  void _validateLimit(int limit) {
    if (limit < 1 || limit > maxBatchSize) {
      throw RangeError.range(limit, 1, maxBatchSize, 'limit');
    }
  }
}
