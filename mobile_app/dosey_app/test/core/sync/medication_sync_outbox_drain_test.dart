import 'dart:async';
import 'dart:convert';

import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/sync/appwrite_medication_sync_gateway.dart';
import 'package:dosey_app/core/sync/domain_contracts.dart';
import 'package:dosey_app/core/sync/medication_sync_outbox_drain.dart';
import 'package:dosey_app/core/sync/sync_outbox_scope.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:dosey_app/core/sync/sync_outbox_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DoseyDatabase database;
  late DriftSyncOutboxRepository repository;
  final now = DateTime.utc(2040, 1, 2, 12);

  setUp(() {
    database = DoseyDatabase.inMemory();
    repository = DriftSyncOutboxRepository(database);
  });

  tearDown(() => database.close());

  test(
    'applied acknowledgement durably completes the claimed mutation',
    () async {
      await _insertMutation(database, now);
      final gateway = _Gateway((request) async {
        expect(request.robotId, 'robot-1');
        expect(request.operations.single.mutationId, 'mutation-1');
        return MedicationSyncPushResponse(
          robotId: request.robotId,
          acknowledgements: const [
            MutationAckContract(
              mutationId: 'mutation-1',
              outcome: MutationOutcomeContract.applied,
              revision: null,
              cursor: '7',
              errorCode: null,
              conflict: null,
            ),
          ],
        );
      });

      await AppwriteMedicationSyncOutboxDrain(
        repository: repository,
        gateway: gateway,
        scope: () async =>
            SyncOutboxScope(actorAccountId: 'account-1', robotId: 'robot-1'),
        now: () => now,
      ).drain();

      final mutation = await _mutation(database);
      expect(mutation.state, 'succeeded');
      expect(mutation.attemptCount, 1);
      final acknowledgement = await database
          .select(database.syncConflicts)
          .getSingle();
      expect(acknowledgement.outcome, 'applied');
      expect(acknowledgement.cursor, '7');
    },
  );

  test('conflict is persisted and is not blindly retried', () async {
    await _insertMutation(database, now);
    final conflict = ConflictContract.fromJson({
      'contractVersion': 1,
      'entityType': 'medication',
      'entityId': 'medication-1',
      'expectedRevision': 1,
      'actualRevision': 2,
      'authoritativeRecord': {
        'contractVersion': 1,
        'id': 'medication-1',
        'householdId': 'robot-1',
        'name': 'Server name',
        'pillType': 'pill',
        'instructions': null,
        'revision': 2,
        'deletedAt': null,
        'updatedAt': '2040-01-02T12:00:00.000Z',
      },
    });
    final gateway = _Gateway(
      (request) async => MedicationSyncPushResponse(
        robotId: request.robotId,
        acknowledgements: [
          MutationAckContract(
            mutationId: 'mutation-1',
            outcome: MutationOutcomeContract.conflict,
            revision: null,
            cursor: null,
            errorCode: null,
            conflict: conflict,
          ),
        ],
      ),
    );

    await AppwriteMedicationSyncOutboxDrain(
      repository: repository,
      gateway: gateway,
      scope: () async =>
          SyncOutboxScope(actorAccountId: 'account-1', robotId: 'robot-1'),
      now: () => now,
    ).drain();

    expect((await _mutation(database)).state, 'permanent_failure');
    final acknowledgement = await database
        .select(database.syncConflicts)
        .getSingle();
    expect(acknowledgement.outcome, 'conflict');
    expect(jsonDecode(acknowledgement.conflictJson!), conflict.toJson());
  });

  test(
    'retryable failure schedules the same mutation for a later attempt',
    () async {
      await _insertMutation(database, now);
      final gateway = _Gateway(
        (_) => throw const MedicationSyncGatewayException(
          reason: MedicationSyncGatewayFailure.retryable,
          errorCode: 'rate_limited',
          statusCode: 429,
        ),
      );

      await AppwriteMedicationSyncOutboxDrain(
        repository: repository,
        gateway: gateway,
        scope: () async =>
            SyncOutboxScope(actorAccountId: 'account-1', robotId: 'robot-1'),
        now: () => now,
        retryDelay: (_) => const Duration(seconds: 30),
      ).drain();

      final mutation = await _mutation(database);
      expect(mutation.state, 'pending');
      expect(mutation.lastErrorCode, 'rate_limited');
      expect(
        mutation.nextAttemptAt?.toUtc(),
        now.add(const Duration(seconds: 30)),
      );
      expect(mutation.attemptCount, 1);
    },
  );

  test(
    'missing robot scope leaves offline work pending and unclaimed',
    () async {
      await _insertMutation(database, now);
      final gateway = _Gateway((_) => throw StateError('must not send'));

      await AppwriteMedicationSyncOutboxDrain(
        repository: repository,
        gateway: gateway,
        scope: () async => null,
        now: () => now,
      ).drain();

      final mutation = await _mutation(database);
      expect(mutation.state, 'pending');
      expect(mutation.attemptCount, 0);
      expect(gateway.calls, 0);
    },
  );

  test('concurrent drain attempts cannot send one mutation twice', () async {
    await _insertMutation(database, now);
    final response = Completer<MedicationSyncPushResponse>();
    final gateway = _Gateway((_) => response.future);
    final drain = AppwriteMedicationSyncOutboxDrain(
      repository: repository,
      gateway: gateway,
      scope: () async =>
          SyncOutboxScope(actorAccountId: 'account-1', robotId: 'robot-1'),
      now: () => now,
    );

    final first = drain.drain();
    await Future<void>.delayed(Duration.zero);
    final duplicate = drain.drain();
    response.complete(
      const MedicationSyncPushResponse(
        robotId: 'robot-1',
        acknowledgements: [
          MutationAckContract(
            mutationId: 'mutation-1',
            outcome: MutationOutcomeContract.duplicate,
            revision: null,
            cursor: '8',
            errorCode: null,
            conflict: null,
          ),
        ],
      ),
    );
    await Future.wait([first, duplicate]);

    expect(gateway.calls, 1);
    expect((await _mutation(database)).state, 'succeeded');
  });
}

Future<void> _insertMutation(DoseyDatabase database, DateTime createdAt) {
  final payload = {
    'medicationId': 'medication-1',
    'occurrence': {
      'contractVersion': 1,
      'occurrenceId': 'schedule-1:1:2040-01-02T08:00:00.000Z',
      'scheduleId': 'schedule-1',
      'scheduleRevision': 1,
      'scheduledAt': '2040-01-02T08:00:00.000Z',
      'localDate': '2040-01-02',
      'timezoneId': 'UTC',
    },
    'kind': 'taken_confirmed',
    'occurredAt': '2040-01-02T08:01:00.000Z',
  };
  return database
      .into(database.syncOutboxMutations)
      .insert(
        SyncOutboxMutationsCompanion.insert(
          mutationId: 'mutation-1',
          deviceId: 'phone-0123456789abcdef',
          actorAccountId: const Value('account-1'),
          robotId: const Value('robot-1'),
          scopeState: const Value('bound'),
          idempotencyKey: 'idempotency-1',
          entityType: 'dose_event',
          operation: 'append',
          entityId: 'event-1',
          payloadJson: jsonEncode(payload),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
}

Future<SyncOutboxMutationRow> _mutation(DoseyDatabase database) =>
    database.select(database.syncOutboxMutations).getSingle();

class _Gateway implements MedicationSyncPushGateway {
  _Gateway(this._push);

  final Future<MedicationSyncPushResponse> Function(
    MedicationSyncPushRequest request,
  )
  _push;
  int calls = 0;

  @override
  Future<MedicationSyncPushResponse> push(MedicationSyncPushRequest request) {
    calls += 1;
    return _push(request);
  }
}
