import 'dart:async';

import 'package:dosey_app/core/connectivity/connectivity_gateway.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/sync/medication_sync_outbox_coordinator.dart';
import 'package:dosey_app/core/sync/sync_outbox_repository.dart';
import 'package:dosey_app/core/sync/sync_outbox_scope.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'startup recovers interrupted work and waits for connectivity',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = DriftSyncOutboxRepository(database);
      final now = DateTime.utc(2040, 1, 2, 12);
      await database
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
              payloadJson: '{}',
              state: const Value('in_flight'),
              attemptCount: const Value(1),
              lastAttemptAt: Value(now.subtract(const Duration(hours: 1))),
              createdAt: now.subtract(const Duration(hours: 1)),
              updatedAt: now.subtract(const Duration(hours: 1)),
            ),
          );
      final connectivity = _Connectivity(ConnectivityState.offline);
      final drain = _Drain();
      final coordinator = MedicationSyncOutboxCoordinator(
        repository: repository,
        drain: drain,
        connectivity: connectivity,
        now: () => now,
        scope: () async =>
            SyncOutboxScope(actorAccountId: 'account-1', robotId: 'robot-1'),
      );
      addTearDown(coordinator.dispose);

      await coordinator.start();

      final recovered = await database
          .select(database.syncOutboxMutations)
          .getSingle();
      expect(recovered.state, 'pending');
      expect(recovered.lastErrorCode, 'attempt_interrupted');
      expect(drain.calls, 0);

      connectivity.emit(ConnectivityState.wifi);
      await _settle();
      expect(drain.calls, 1);
    },
  );

  test('overlapping online signals do not overlap drain attempts', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final connectivity = _Connectivity(ConnectivityState.wifi);
    final firstDrain = Completer<void>();
    final drain = _Drain(first: firstDrain.future);
    final coordinator = MedicationSyncOutboxCoordinator(
      repository: DriftSyncOutboxRepository(database),
      drain: drain,
      connectivity: connectivity,
      now: () => DateTime.utc(2040, 1, 2, 12),
    );
    addTearDown(coordinator.dispose);

    final started = coordinator.start();
    await _settle();
    connectivity.emit(ConnectivityState.cellular);
    connectivity.emit(ConnectivityState.wifi);
    await _settle();
    expect(drain.calls, 1);
    expect(drain.maxConcurrent, 1);

    firstDrain.complete();
    await started;
    await _settle();
    expect(drain.maxConcurrent, 1);
  });
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _Connectivity implements ConnectivityGateway {
  _Connectivity(this.current);

  final StreamController<ConnectivityState> _changes =
      StreamController<ConnectivityState>.broadcast();
  ConnectivityState current;

  void emit(ConnectivityState value) {
    current = value;
    _changes.add(value);
  }

  @override
  Future<ConnectivityState> currentConnectivity() async => current;

  @override
  Stream<ConnectivityState> watchConnectivity() => _changes.stream;
}

class _Drain implements MedicationSyncOutboxDrain {
  _Drain({this.first});

  final Future<void>? first;
  int calls = 0;
  int concurrent = 0;
  int maxConcurrent = 0;

  @override
  Future<void> drain() async {
    calls += 1;
    concurrent += 1;
    if (concurrent > maxConcurrent) maxConcurrent = concurrent;
    if (calls == 1 && first != null) await first;
    concurrent -= 1;
  }
}
