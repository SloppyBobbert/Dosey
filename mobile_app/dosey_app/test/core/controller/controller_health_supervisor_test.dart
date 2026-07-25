import 'dart:async';

import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/controller/controller_health_supervisor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('connection stays verifying until its heartbeat succeeds', () async {
    final delegate = _FakeControllerGateway();
    final heartbeat = Completer<String>();
    delegate.heartbeatResults.add(heartbeat.future);
    final harness = _Harness(delegate);
    addTearDown(harness.close);
    await harness.supervisor.setMonitoringEligible(true);

    final connection = harness.supervisor.connect();
    await _flushEvents();

    expect(harness.latest.healthState, ControllerHealthState.verifying);
    expect(harness.latest.canRequestDispense, isFalse);

    heartbeat.complete('HEARTBEAT_OK');
    await connection;
    await _flushEvents();

    expect(harness.latest.healthState, ControllerHealthState.online);
    expect(harness.latest.canRequestDispense, isTrue);
    expect(harness.latest.lastSuccessfulHeartbeatAt, harness.now);
  });

  test(
    'a missed heartbeat fails closed and starts bounded reconnect',
    () async {
      final delegate = _FakeControllerGateway();
      final harness = _Harness(delegate);
      addTearDown(harness.close);
      await harness.supervisor.setMonitoringEligible(true);
      await harness.supervisor.connect();
      delegate.heartbeatResults.add(
        Future<String>.error(
          const ControllerCommandPreAcceptanceTimeoutException(),
        ),
      );

      await harness.scheduler.elapse(const Duration(seconds: 10));

      expect(harness.latest.healthState, ControllerHealthState.offline);
      expect(harness.latest.canRequestDispense, isFalse);
      expect(delegate.disconnectCount, 1);
      expect(harness.scheduler.nextDelay, const Duration(seconds: 2));
    },
  );

  test(
    'heartbeat due while a command is busy is deferred without a miss',
    () async {
      final delegate = _FakeControllerGateway();
      final movement = Completer<void>();
      delegate.movementResult = movement.future;
      final harness = _Harness(delegate);
      addTearDown(harness.close);
      await harness.supervisor.setMonitoringEligible(true);
      await harness.supervisor.connect();

      final request = harness.supervisor.requestDispense(doseId: 'dose-1');
      await _flushEvents();
      await harness.scheduler.elapse(const Duration(seconds: 10));

      expect(delegate.heartbeatCount, 1);
      expect(harness.latest.healthState, ControllerHealthState.online);

      movement.complete();
      await request;
      await harness.scheduler.elapse(Duration.zero);

      expect(delegate.heartbeatCount, 2);
      expect(
        harness.events,
        isNot(contains(ControllerHealthEventType.heartbeatMissed)),
      );
    },
  );

  test('heartbeat due while cancel is active waits for cancel', () async {
    final delegate = _FakeControllerGateway();
    final cancel = Completer<void>();
    delegate.cancelResult = cancel.future;
    final harness = _Harness(delegate);
    addTearDown(harness.close);
    await harness.supervisor.setMonitoringEligible(true);
    await harness.supervisor.connect();

    final cancellation = harness.supervisor.cancelActiveCommand();
    await _flushEvents();
    await harness.scheduler.elapse(const Duration(seconds: 10));

    expect(delegate.heartbeatCount, 1);
    cancel.complete();
    await cancellation;
    await harness.scheduler.elapse(Duration.zero);

    expect(delegate.heartbeatCount, 2);
  });

  test('recovery requires reconnect and a successful heartbeat', () async {
    final delegate = _FakeControllerGateway();
    final harness = _Harness(delegate);
    addTearDown(harness.close);
    await harness.supervisor.setMonitoringEligible(true);
    await harness.supervisor.connect();
    delegate.heartbeatResults.add(
      Future<String>.error(const ControllerTransportOfflineException()),
    );
    await harness.scheduler.elapse(const Duration(seconds: 10));
    final recoveryHeartbeat = Completer<String>();
    delegate.heartbeatResults.add(recoveryHeartbeat.future);

    await harness.scheduler.elapse(const Duration(seconds: 2));
    await _flushEvents();

    expect(harness.latest.healthState, ControllerHealthState.verifying);
    expect(harness.latest.canRequestDispense, isFalse);
    recoveryHeartbeat.complete('HEARTBEAT_OK');
    await _flushEvents();

    expect(harness.latest.healthState, ControllerHealthState.online);
    expect(harness.latest.reconnectAttempt, 0);
    expect(harness.events, contains(ControllerHealthEventType.recovered));
  });

  test('manual heartbeat failure schedules one reconnect attempt', () async {
    final delegate = _FakeControllerGateway();
    final harness = _Harness(delegate);
    addTearDown(harness.close);
    await harness.supervisor.setMonitoringEligible(true);
    await harness.supervisor.connect();
    delegate.nextBenchError =
        const ControllerCommandPreAcceptanceTimeoutException();

    await expectLater(
      harness.supervisor.runBenchCommand(ControllerBenchCommand.heartbeat),
      throwsA(isA<ControllerCommandPreAcceptanceTimeoutException>()),
    );
    await _flushEvents();

    expect(harness.latest.reconnectAttempt, 1);
    expect(harness.scheduler.pendingTimerCount, 1);
    expect(
      harness.events.where(
        (event) => event == ControllerHealthEventType.heartbeatMissed,
      ),
      hasLength(1),
    );
  });

  test('non-heartbeat command failure is not a missed heartbeat', () async {
    final delegate = _FakeControllerGateway();
    final harness = _Harness(delegate);
    addTearDown(harness.close);
    await harness.supervisor.setMonitoringEligible(true);
    await harness.supervisor.connect();
    delegate.nextBenchError = const ControllerTransportOfflineException();

    await expectLater(
      harness.supervisor.runBenchCommand(ControllerBenchCommand.status),
      throwsA(isA<ControllerTransportOfflineException>()),
    );
    await _flushEvents();

    expect(
      harness.events,
      isNot(contains(ControllerHealthEventType.heartbeatMissed)),
    );
    expect(harness.latest.reconnectAttempt, 1);
  });

  test(
    'background pause cancels retries and preserves connection intent',
    () async {
      final delegate = _FakeControllerGateway();
      final harness = _Harness(delegate);
      addTearDown(harness.close);
      await harness.supervisor.setMonitoringEligible(true);
      await harness.supervisor.connect();
      delegate.emitDisconnected();
      await _flushEvents();

      await harness.supervisor.setMonitoringEligible(false);
      await _flushEvents();

      expect(harness.latest.healthState, ControllerHealthState.disconnected);
      expect(harness.scheduler.hasPendingTimer, isFalse);

      await harness.supervisor.setMonitoringEligible(true);
      await _flushEvents();

      expect(delegate.connectCount, 2);
      expect(harness.latest.healthState, ControllerHealthState.online);
    },
  );

  test(
    'pause and resume during verification ignores stale heartbeat',
    () async {
      final firstHeartbeat = Completer<String>();
      final delegate = _FakeControllerGateway()
        ..heartbeatResults.addAll([
          firstHeartbeat.future,
          Future<String>.value('HEARTBEAT_OK'),
        ]);
      final harness = _Harness(delegate);
      addTearDown(harness.close);
      await harness.supervisor.setMonitoringEligible(true);

      final initialConnection = harness.supervisor.connect();
      await _flushEvents();
      expect(harness.latest.healthState, ControllerHealthState.verifying);

      await harness.supervisor.setMonitoringEligible(false);
      await harness.supervisor.setMonitoringEligible(true);
      firstHeartbeat.complete('HEARTBEAT_OK');
      await initialConnection;
      await _flushEvents();

      expect(delegate.connectCount, 2);
      expect(delegate.heartbeatCount, 2);
      expect(harness.latest.healthState, ControllerHealthState.online);
    },
  );

  test('resume waits for the paused transport to disconnect', () async {
    final disconnect = Completer<void>();
    final delegate = _FakeControllerGateway();
    final harness = _Harness(delegate);
    addTearDown(harness.close);
    await harness.supervisor.setMonitoringEligible(true);
    await harness.supervisor.connect();
    delegate.disconnectResult = disconnect.future;

    final pause = harness.supervisor.setMonitoringEligible(false);
    await _flushEvents();
    await harness.supervisor.setMonitoringEligible(true);
    await _flushEvents();

    expect(delegate.connectCount, 1);

    disconnect.complete();
    await pause;
    await _flushEvents();

    expect(delegate.connectCount, 2);
    expect(harness.latest.healthState, ControllerHealthState.online);
  });

  test(
    'resume performs fresh verification after a stale periodic heartbeat',
    () async {
      final delegate = _FakeControllerGateway();
      final harness = _Harness(delegate);
      addTearDown(harness.close);
      await harness.supervisor.setMonitoringEligible(true);
      await harness.supervisor.connect();
      final staleHeartbeat = Completer<String>();
      delegate.heartbeatResults.add(staleHeartbeat.future);

      await harness.scheduler.elapse(const Duration(seconds: 10));
      await harness.supervisor.setMonitoringEligible(false);
      await harness.supervisor.setMonitoringEligible(true);
      staleHeartbeat.complete('HEARTBEAT_OK');
      await _flushEvents();

      expect(delegate.connectCount, 2);
      expect(delegate.heartbeatCount, 3);
      expect(harness.latest.healthState, ControllerHealthState.online);
    },
  );

  test(
    'Bluetooth unavailable suppresses reconnect until availability returns',
    () async {
      final delegate = _FakeControllerGateway();
      final harness = _Harness(delegate);
      addTearDown(harness.close);
      await harness.supervisor.setMonitoringEligible(true);
      await harness.supervisor.connect();

      harness.availability.add(const BleAvailabilitySnapshot.unavailable());
      await _flushEvents();

      expect(harness.latest.healthState, ControllerHealthState.error);
      expect(harness.latest.canRequestDispense, isFalse);
      expect(harness.scheduler.hasPendingTimer, isFalse);

      harness.availability.add(const BleAvailabilitySnapshot.available());
      await _flushEvents();

      expect(delegate.connectCount, 2);
      expect(harness.latest.healthState, ControllerHealthState.online);
    },
  );

  test(
    'Bluetooth recovery in background reconnects after monitoring resumes',
    () async {
      final delegate = _FakeControllerGateway();
      final harness = _Harness(delegate);
      addTearDown(harness.close);
      await harness.supervisor.setMonitoringEligible(true);
      await harness.supervisor.connect();

      await harness.supervisor.setMonitoringEligible(false);
      harness.availability.add(const BleAvailabilitySnapshot.unavailable());
      harness.availability.add(const BleAvailabilitySnapshot.available());
      await _flushEvents();

      await harness.supervisor.setMonitoringEligible(true);
      await _flushEvents();

      expect(delegate.connectCount, 2);
      expect(harness.latest.healthState, ControllerHealthState.online);
    },
  );

  test(
    'permission denial stays suppressed until another manual connect',
    () async {
      final delegate = _FakeControllerGateway();
      delegate.connectErrors.add(
        const ControllerCommandPreconditionException('Permission denied.'),
      );
      final harness = _Harness(delegate);
      addTearDown(harness.close);
      await harness.supervisor.setMonitoringEligible(true);

      await expectLater(
        harness.supervisor.connect(),
        throwsA(isA<ControllerCommandPreconditionException>()),
      );
      harness.availability.add(const BleAvailabilitySnapshot.available());
      await _flushEvents();

      expect(delegate.connectCount, 1);
      expect(harness.latest.healthState, ControllerHealthState.error);

      await harness.supervisor.connect();
      await _flushEvents();

      expect(delegate.connectCount, 2);
      expect(harness.latest.healthState, ControllerHealthState.online);
    },
  );

  test('deliberate disconnect clears intent and never reconnects', () async {
    final delegate = _FakeControllerGateway();
    final harness = _Harness(delegate);
    addTearDown(harness.close);
    await harness.supervisor.setMonitoringEligible(true);
    await harness.supervisor.connect();

    await harness.supervisor.disconnect();
    delegate.emitDisconnected();
    await _flushEvents();

    expect(harness.latest.healthState, ControllerHealthState.disconnected);
    expect(harness.scheduler.hasPendingTimer, isFalse);
    expect(delegate.connectCount, 1);
  });

  test('duplicate disconnect signals schedule only one reconnect', () async {
    final delegate = _FakeControllerGateway();
    final harness = _Harness(delegate);
    addTearDown(harness.close);
    await harness.supervisor.setMonitoringEligible(true);
    await harness.supervisor.connect();

    delegate.emitDisconnected();
    delegate.emitDisconnected();
    await _flushEvents();

    expect(harness.scheduler.pendingTimerCount, 1);
  });

  test('concurrent failure signals share one transport disconnect', () async {
    final disconnect = Completer<void>();
    final delegate = _FakeControllerGateway();
    final harness = _Harness(delegate);
    addTearDown(harness.close);
    await harness.supervisor.setMonitoringEligible(true);
    await harness.supervisor.connect();
    delegate
      ..disconnectResult = disconnect.future
      ..heartbeatResults.add(
        Future<String>.error(const ControllerTransportOfflineException()),
      );

    await harness.scheduler.elapse(const Duration(seconds: 10));
    harness.availability.add(const BleAvailabilitySnapshot.unavailable());
    await _flushEvents();

    expect(delegate.disconnectCount, 1);

    disconnect.complete();
    await _flushEvents();
  });

  test('close disconnects transport and cancels all timers', () async {
    final delegate = _FakeControllerGateway();
    final harness = _Harness(delegate);
    await harness.supervisor.setMonitoringEligible(true);
    await harness.supervisor.connect();

    await harness.subscription.cancel();
    await harness.supervisor.close();

    expect(delegate.disconnectCount, 1);
    expect(delegate.closeCount, 1);
    expect(harness.scheduler.hasPendingTimer, isFalse);
    await harness.availability.close();
  });
}

Future<void> _flushEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _Harness {
  _Harness(this.delegate) {
    supervisor = ControllerHealthSupervisor(
      delegate: delegate,
      availability: availability.stream,
      eventSink: _EventSink(events),
      now: () => now,
      timerFactory: scheduler.schedule,
      heartbeatInterval: const Duration(seconds: 10),
      reconnectBackoff: const [Duration(seconds: 2), Duration(seconds: 5)],
    );
    subscription = supervisor.watchController().listen(
      (value) => latest = value,
    );
  }

  final _FakeControllerGateway delegate;
  final availability = StreamController<BleAvailabilitySnapshot>.broadcast();
  final scheduler = _ManualScheduler();
  final events = <ControllerHealthEventType>[];
  final now = DateTime.utc(2040, 1, 2, 8);
  late final ControllerHealthSupervisor supervisor;
  late final StreamSubscription<ControllerSnapshot> subscription;
  ControllerSnapshot latest = const ControllerSnapshot.disconnected();

  Future<void> close() async {
    await subscription.cancel();
    await supervisor.close();
    await availability.close();
  }
}

class _EventSink implements ControllerHealthEventSink {
  const _EventSink(this.events);

  final List<ControllerHealthEventType> events;

  @override
  Future<void> recordControllerHealthEvent(
    ControllerHealthEventType type, {
    required DateTime occurredAt,
    String? details,
  }) async {
    events.add(type);
  }
}

class _FakeControllerGateway
    implements StagedControllerGateway, ControllerBenchGateway {
  final _snapshots = StreamController<ControllerSnapshot>.broadcast();
  final heartbeatResults = <Future<String>>[];
  final connectErrors = <Object>[];
  Future<void> movementResult = Future<void>.value();
  Future<void> cancelResult = Future<void>.value();
  Future<void> disconnectResult = Future<void>.value();
  ControllerSnapshot snapshot = const ControllerSnapshot.disconnected();
  int connectCount = 0;
  int disconnectCount = 0;
  int heartbeatCount = 0;
  int closeCount = 0;
  Object? nextBenchError;

  @override
  Stream<ControllerSnapshot> watchController() async* {
    yield snapshot;
    yield* _snapshots.stream;
  }

  @override
  Future<void> connect() async {
    connectCount += 1;
    if (connectErrors.isNotEmpty) {
      throw connectErrors.removeAt(0);
    }
    snapshot = const ControllerSnapshot.connected();
    _snapshots.add(snapshot);
  }

  @override
  Future<void> disconnect() async {
    disconnectCount += 1;
    await disconnectResult;
    emitDisconnected();
  }

  void emitDisconnected() {
    snapshot = const ControllerSnapshot.disconnected();
    _snapshots.add(snapshot);
  }

  @override
  Future<String> runBenchCommand(ControllerBenchCommand command) {
    final error = nextBenchError;
    if (error != null) {
      nextBenchError = null;
      return Future<String>.error(error);
    }
    if (command != ControllerBenchCommand.heartbeat) {
      return Future<String>.value('OK');
    }
    heartbeatCount += 1;
    if (heartbeatResults.isEmpty) {
      return Future<String>.value('HEARTBEAT_OK');
    }
    return heartbeatResults.removeAt(0);
  }

  @override
  Future<void> requestDispense({required String doseId}) => movementResult;

  @override
  Future<void> requestStagedDispense({
    required String doseId,
    ControllerMovementCommand movement = ControllerMovementCommand.dispenseNext,
    required ControllerDispenseStageCallback onStage,
  }) => movementResult;

  @override
  Future<void> cancelActiveCommand() => cancelResult;

  @override
  Future<void> close() async {
    closeCount += 1;
    await _snapshots.close();
  }
}

class _ManualScheduler {
  final _timers = <_ManualTimer>[];

  ControllerHealthTimer schedule(Duration delay, void Function() callback) {
    final timer = _ManualTimer(delay, callback);
    _timers.add(timer);
    return timer;
  }

  bool get hasPendingTimer => _timers.any((timer) => !timer.isCancelled);

  int get pendingTimerCount =>
      _timers.where((timer) => !timer.isCancelled).length;

  Duration? get nextDelay {
    for (final timer in _timers) {
      if (!timer.isCancelled) return timer.delay;
    }
    return null;
  }

  Future<void> elapse(Duration delay) async {
    final timers = _timers
        .where((timer) => !timer.isCancelled && timer.delay == delay)
        .toList();
    for (final timer in timers) {
      timer.fire();
    }
    await _flushEvents();
  }
}

class _ManualTimer implements ControllerHealthTimer {
  _ManualTimer(this.delay, this._callback);

  final Duration delay;
  final void Function() _callback;
  bool isCancelled = false;

  void fire() {
    if (isCancelled) return;
    isCancelled = true;
    _callback();
  }

  @override
  void cancel() => isCancelled = true;
}
