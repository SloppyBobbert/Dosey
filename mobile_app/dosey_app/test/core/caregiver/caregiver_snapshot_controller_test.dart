import 'dart:async';

import 'package:dosey_app/core/caregiver/caregiver_snapshot.dart';
import 'package:dosey_app/core/caregiver/caregiver_snapshot_controller.dart';
import 'package:dosey_app/core/caregiver/caregiver_status_projection.dart';
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

  test(
    'nonterminal mutation conflict keeps data and exposes conflict label',
    () async {
      final gateway = _FakeGateway()
        ..snapshot = _snapshot('revision-1')
        ..pushError = const CaregiverConflictException();
      final controller = CaregiverSnapshotController(
        householdId: 'household-1',
        gateway: gateway,
      );
      await controller.load();

      await controller.push(CaregiverMutation.upsertMedication(_medication()));

      final state = controller.state as CaregiverStale;
      expect(state.isConflict, isTrue);
      expect(state.snapshot.revision, 'revision-1');
    },
  );

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

  test(
    'terminal write refreshes and preserves the original occurrence',
    () async {
      final snapshot = _doseSnapshot('revision-1');
      final gateway = _FakeGateway()..snapshot = snapshot;
      final controller = CaregiverSnapshotController(
        householdId: 'household-1',
        gateway: gateway,
        now: () => DateTime.utc(2026, 7, 29, 9),
      );
      await controller.load();
      final occurrence = projectCaregiverDay(
        snapshot: snapshot,
        now: DateTime.utc(2026, 7, 29, 9),
      ).single.occurrence;

      await controller.recordTerminalDose(
        occurrence: occurrence,
        action: CaregiverDoseAction.skipped,
      );

      expect(gateway.pullRequests, hasLength(3));
      expect(gateway.pushedOperations, hasLength(1));
      expect(
        gateway.pushedOperations.single.values['occurrence'],
        same(occurrence),
      );
      expect(gateway.pushedOperations.single.values['action'], 'skipped');
    },
  );

  test(
    'terminal write fails closed when refresh resolves the occurrence',
    () async {
      final gateway = _FakeGateway()
        ..pulls.addAll([
          Future.value(_doseSnapshot('revision-1')),
          Future.value(_doseSnapshot('revision-2', terminal: true)),
        ]);
      final controller = CaregiverSnapshotController(
        householdId: 'household-1',
        gateway: gateway,
        now: () => DateTime.utc(2026, 7, 29, 9),
      );
      await controller.load();

      await controller.recordTerminalDose(
        occurrence: _occurrence(),
        action: CaregiverDoseAction.taken,
      );

      expect(gateway.pushedOperations, isEmpty);
      expect((controller.state as CaregiverStale).isConflict, isTrue);
    },
  );

  test(
    'terminal write fails closed when refresh changes or removes occurrence',
    () async {
      for (final snapshot in [
        _doseSnapshot('changed', scheduleRevision: 2),
        _snapshot('missing'),
      ]) {
        final gateway = _FakeGateway()
          ..pulls.addAll([
            Future.value(_doseSnapshot('revision-1')),
            Future.value(snapshot),
          ]);
        final controller = CaregiverSnapshotController(
          householdId: 'household-1',
          gateway: gateway,
          now: () => DateTime.utc(2026, 7, 29, 9),
        );
        await controller.load();

        await controller.recordTerminalDose(
          occurrence: _occurrence(),
          action: CaregiverDoseAction.taken,
        );

        expect(gateway.pushedOperations, isEmpty);
        expect(controller.state, isA<CaregiverStale>());
      }
    },
  );

  test('only one terminal write can be pending', () async {
    final gateway = _FakeGateway()..snapshot = _doseSnapshot('revision-1');
    final controller = CaregiverSnapshotController(
      householdId: 'household-1',
      gateway: gateway,
      now: () => DateTime.utc(2026, 7, 29, 9),
    );
    await controller.load();
    final refresh = Completer<CaregiverSnapshot>();
    gateway.pulls.add(refresh.future);

    final first = controller.recordTerminalDose(
      occurrence: _occurrence(),
      action: CaregiverDoseAction.taken,
    );
    final second = controller.recordTerminalDose(
      occurrence: _occurrence(),
      action: CaregiverDoseAction.taken,
    );
    expect(controller.isTerminalMutationPending, isTrue);
    expect(gateway.pullRequests, hasLength(2));
    refresh.complete(_doseSnapshot('revision-2'));
    await Future.wait([first, second]);

    expect(gateway.pushedOperations, hasLength(1));
    expect(gateway.pullRequests, hasLength(3));
    expect(controller.isTerminalMutationPending, isFalse);
  });

  test(
    'generic terminal mutations are rejected while help is accepted during a terminal refresh',
    () async {
      final terminalRefresh = Completer<CaregiverSnapshot>();
      final helpRefresh = Completer<CaregiverSnapshot>();
      final gateway = _FakeGateway()..snapshot = _doseSnapshot('revision-1');
      final controller = CaregiverSnapshotController(
        householdId: 'household-1',
        gateway: gateway,
        now: () => DateTime.utc(2026, 7, 29, 9),
      );
      await controller.load();

      await controller.push(
        CaregiverMutation.recordDose(
          occurrence: _occurrence(),
          action: CaregiverDoseAction.taken,
        ),
      );
      await controller.push(
        CaregiverMutation.recordDose(
          occurrence: _occurrence(),
          action: CaregiverDoseAction.skipped,
        ),
      );
      expect(gateway.pushedOperations, isEmpty);
      await controller.recordTerminalDose(
        occurrence: _occurrence(),
        action: CaregiverDoseAction.helpRequested,
      );
      expect(gateway.pullRequests, hasLength(1));

      gateway.pulls.addAll([terminalRefresh.future, helpRefresh.future]);
      final terminal = controller.recordTerminalDose(
        occurrence: _occurrence(),
        action: CaregiverDoseAction.taken,
      );
      expect(controller.isTerminalMutationPending, isTrue);

      final help = controller.push(
        CaregiverMutation.recordDose(
          occurrence: _occurrence(),
          action: CaregiverDoseAction.helpRequested,
        ),
      );
      expect(gateway.pushedOperations, hasLength(1));
      expect(gateway.pushedOperations.single.values['action'], 'helpRequested');

      helpRefresh.complete(_doseSnapshot('revision-3', terminal: true));
      terminalRefresh.complete(_doseSnapshot('revision-2'));
      await Future.wait([terminal, help]);

      expect(gateway.pushedOperations, hasLength(1));
      expect(controller.isTerminalMutationPending, isFalse);
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
  final List<CaregiverMutation> pushedOperations = [];

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
    pushedOperations.addAll(operations);
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

CaregiverOccurrence _occurrence() => CaregiverOccurrence(
  occurrenceId: 'schedule-1:1:2026-07-29T09:00:00.000Z',
  scheduleId: 'schedule-1',
  scheduleRevision: 1,
  scheduledFor: DateTime.utc(2026, 7, 29, 9),
  timezoneId: 'UTC',
  localDate: '2026-07-29',
);

CaregiverMedication _medication() => CaregiverMedication(
  id: 'medication-1',
  name: 'Morning medicine',
  instructions: '',
  active: true,
  version: 1,
);

CaregiverSnapshot _doseSnapshot(
  String revision, {
  int scheduleRevision = 1,
  bool terminal = false,
}) {
  final occurrence = _occurrence();
  return CaregiverSnapshot(
    householdId: 'household-1',
    revision: revision,
    generatedAt: DateTime.utc(2026, 7, 29, 9),
    medications: [_medication()],
    schedules: [
      CaregiverSchedule(
        id: 'schedule-1',
        medicationId: 'medication-1',
        label: 'Breakfast',
        hour: 9,
        minute: 0,
        enabled: true,
        version: scheduleRevision,
      ),
    ],
    events: terminal
        ? [
            CaregiverDoseEvent(
              id: 'event-1',
              occurrenceId: occurrence.occurrenceId,
              scheduleId: occurrence.scheduleId,
              scheduleRevision: occurrence.scheduleRevision,
              scheduledFor: occurrence.scheduledFor,
              timezoneId: occurrence.timezoneId,
              localDate: occurrence.localDate,
              occurredAt: DateTime.utc(2026, 7, 29, 9, 1),
              action: CaregiverDoseAction.taken,
            ),
          ]
        : const [],
  );
}
