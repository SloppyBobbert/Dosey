import 'dart:async';

import 'package:dosey_app/core/caregiver/caregiver_snapshot.dart';
import 'package:dosey_app/core/caregiver/caregiver_snapshot_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initial failure is unavailable and retry can become fresh', () async {
    final gateway = _FakeGateway()
      ..pullError = const CaregiverSyncException('Cloud unavailable');
    final controller = CaregiverSnapshotController(
      householdId: 'household-1',
      gateway: gateway,
      now: () => DateTime(2026, 7, 29, 10),
    );

    await controller.load();
    expect(controller.state, isA<CaregiverUnavailable>());

    gateway
      ..pullError = null
      ..snapshot = _snapshot('revision-1');
    await controller.refresh();
    expect(controller.state, isA<CaregiverFresh>());
  });

  test('refresh failure retains data with a stale label', () async {
    final gateway = _FakeGateway()..snapshot = _snapshot('revision-1');
    var now = DateTime(2026, 7, 29, 10);
    final controller = CaregiverSnapshotController(
      householdId: 'household-1',
      gateway: gateway,
      now: () => now,
    );

    await controller.load();
    now = DateTime(2026, 7, 29, 10, 5);
    gateway.pullError = const CaregiverSyncException('Offline');
    await controller.refresh();

    final state = controller.state as CaregiverStale;
    expect(state.snapshot.revision, 'revision-1');
    expect(state.lastUpdatedAt, DateTime(2026, 7, 29, 10));
    expect(state.message, 'Offline');
  });

  test('older refresh cannot replace a newer result', () async {
    final first = Completer<CaregiverSnapshot>();
    final second = Completer<CaregiverSnapshot>();
    final gateway = _FakeGateway()..pulls.addAll([first.future, second.future]);
    final controller = CaregiverSnapshotController(
      householdId: 'household-1',
      gateway: gateway,
    );

    final firstLoad = controller.load();
    final secondLoad = controller.refresh();
    second.complete(_snapshot('revision-2'));
    await secondLoad;
    first.complete(_snapshot('revision-1'));
    await firstLoad;

    expect(
      (controller.state as CaregiverFresh).snapshot.revision,
      'revision-2',
    );
  });

  test('mutation conflict keeps data and exposes conflict label', () async {
    final gateway = _FakeGateway()
      ..snapshot = _snapshot('revision-1')
      ..pushError = const CaregiverConflictException();
    final controller = CaregiverSnapshotController(
      householdId: 'household-1',
      gateway: gateway,
    );
    await controller.load();

    await controller.push(
      CaregiverMutation.recordDose(
        scheduleId: 'schedule-1',
        scheduledForIso: '2026-07-29T09:00:00.000',
        action: CaregiverDoseAction.taken,
      ),
    );

    final state = controller.state as CaregiverStale;
    expect(state.isConflict, isTrue);
    expect(state.snapshot.revision, 'revision-1');
  });

  test(
    'refresh starts a new traversal to capture a fresh checkpoint',
    () async {
      final gateway = _FakeGateway()
        ..snapshot = _snapshot('revision-5')
        ..resultCursor = '5'
        ..resultCheckpoint = '5';
      final controller = CaregiverSnapshotController(
        householdId: 'household-1',
        gateway: gateway,
      );

      await controller.load();
      await controller.refresh();

      expect(gateway.pullRequests, [
        (cursor: null, checkpoint: null),
        (cursor: null, checkpoint: null),
      ]);
    },
  );
}

class _FakeGateway implements CaregiverSyncGateway {
  CaregiverSnapshot snapshot = _snapshot('default');
  Object? pullError;
  Object? pushError;
  String? resultCursor;
  String? resultCheckpoint;
  final List<Future<CaregiverSnapshot>> pulls = [];
  final List<({String? cursor, String? checkpoint})> pullRequests = [];

  @override
  Future<CaregiverPullResult> pull(
    String householdId, {
    String? cursor,
    String? checkpoint,
    int limit = 100,
  }) async {
    pullRequests.add((cursor: cursor, checkpoint: checkpoint));
    if (pulls.isNotEmpty) {
      return CaregiverPullResult(
        snapshot: await pulls.removeAt(0),
        cursor: resultCursor,
        checkpoint: resultCheckpoint,
      );
    }
    if (pullError case final error?) throw error;
    return CaregiverPullResult(
      snapshot: snapshot,
      cursor: resultCursor,
      checkpoint: resultCheckpoint,
    );
  }

  @override
  Future<void> push(
    String householdId,
    List<CaregiverMutation> operations,
  ) async {
    if (pushError case final error?) throw error;
  }
}

CaregiverSnapshot _snapshot(String revision) => CaregiverSnapshot(
  householdId: 'household-1',
  revision: revision,
  generatedAt: DateTime(2026, 7, 29, 10),
  medications: const [],
  schedules: const [],
  events: const [],
);
