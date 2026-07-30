import 'dart:convert';

import '../storage/dosey_database.dart';
import 'appwrite_medication_sync_gateway.dart';
import 'domain_contracts.dart';
import 'sync_outbox_repository.dart';
import 'sync_outbox_serializer.dart';
import 'sync_outbox_scope.dart';

final class AppwriteMedicationSyncOutboxDrain
    implements MedicationSyncOutboxDrain {
  AppwriteMedicationSyncOutboxDrain({
    required DriftSyncOutboxRepository repository,
    required MedicationSyncPushGateway gateway,
    required Future<SyncOutboxScope?> Function() scope,
    required DateTime Function() now,
    Duration Function(int attemptCount)? retryDelay,
    this.batchSize = DriftSyncOutboxRepository.maxBatchSize,
  }) : _outboxRepository = repository,
       _pushGateway = gateway,
       _scopeProvider = scope,
       _clock = now,
       _retryDelay = retryDelay ?? _defaultRetryDelay;

  final DriftSyncOutboxRepository _outboxRepository;
  final MedicationSyncPushGateway _pushGateway;
  final Future<SyncOutboxScope?> Function() _scopeProvider;
  final DateTime Function() _clock;
  final Duration Function(int attemptCount) _retryDelay;
  final int batchSize;

  @override
  Future<void> drain() async {
    final scope = await _scopeProvider();
    if (scope == null) return;

    final claimed = await _outboxRepository.claimEligible(
      now: _clock().toUtc(),
      limit: batchSize,
      scope: scope,
    );
    if (claimed.isEmpty) return;

    final rows = <SyncOutboxMutationRow>[];
    final operations = <MutationContract>[];
    for (final row in claimed) {
      try {
        operations.add(
          MutationContract.fromJson(SyncOutboxSerializer.toMutationJson(row)),
        );
        rows.add(row);
      } on Object {
        if (!await _scopeStillCurrent(scope)) return;
        await _outboxRepository.markFailed(
          row.mutationId,
          scope: scope,
          expectedAttemptCount: row.attemptCount,
          errorCode: 'invalid_local_mutation',
          updatedAt: _clock().toUtc(),
        );
      }
    }
    if (operations.isEmpty) return;

    final MedicationSyncPushResponse response;
    try {
      response = await _pushGateway.push(
        MedicationSyncPushRequest(
          robotId: scope.robotId,
          operations: operations,
        ),
      );
    } on MedicationSyncGatewayException catch (error) {
      await _handleGatewayFailure(scope, rows, error);
      return;
    } on Object {
      await _retry(scope, rows, 'transport_failure');
      return;
    }

    for (var index = 0; index < rows.length; index += 1) {
      final row = rows[index];
      final acknowledgement = response.acknowledgements[index];
      if (!await _scopeStillCurrent(scope)) return;
      await _outboxRepository.recordAcknowledgement(
        row.mutationId,
        scope: scope,
        expectedAttemptCount: row.attemptCount,
        outcome: acknowledgement.outcome.wireValue,
        revision: acknowledgement.revision,
        cursor: acknowledgement.cursor,
        errorCode: acknowledgement.errorCode,
        conflictJson: acknowledgement.conflict == null
            ? null
            : jsonEncode(acknowledgement.conflict!.toJson()),
        acknowledgedAt: _clock().toUtc(),
      );
    }
  }

  Future<void> _handleGatewayFailure(
    SyncOutboxScope scope,
    List<SyncOutboxMutationRow> rows,
    MedicationSyncGatewayException error,
  ) async {
    if (error.reason == MedicationSyncGatewayFailure.retryable) {
      await _retry(scope, rows, error.errorCode);
      return;
    }
    for (final row in rows) {
      if (!await _scopeStillCurrent(scope)) return;
      await _outboxRepository.markFailed(
        row.mutationId,
        scope: scope,
        expectedAttemptCount: row.attemptCount,
        errorCode: error.errorCode,
        updatedAt: _clock().toUtc(),
      );
    }
  }

  Future<void> _retry(
    SyncOutboxScope scope,
    List<SyncOutboxMutationRow> rows,
    String errorCode,
  ) async {
    for (final row in rows) {
      if (!await _scopeStillCurrent(scope)) return;
      final retryAt = _clock().toUtc().add(_retryDelay(row.attemptCount));
      await _outboxRepository.markRetry(
        row.mutationId,
        scope: scope,
        expectedAttemptCount: row.attemptCount,
        errorCode: errorCode,
        nextAttemptAt: retryAt,
        updatedAt: _clock().toUtc(),
      );
    }
  }

  Future<bool> _scopeStillCurrent(SyncOutboxScope expected) async {
    final current = await _scopeProvider();
    return current != null &&
        current.actorAccountId == expected.actorAccountId &&
        current.robotId == expected.robotId;
  }

  static Duration _defaultRetryDelay(int attemptCount) {
    final exponent = (attemptCount - 1).clamp(0, 6);
    return Duration(seconds: 5 * (1 << exponent));
  }
}
