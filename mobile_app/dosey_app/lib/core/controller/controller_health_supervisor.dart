import 'dart:async';

import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:dosey_app/core/controller/controller_diagnostics.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';

enum ControllerHealthEventType {
  heartbeatMissed,
  offline,
  reconnecting,
  error,
  recovered,
}

abstract interface class ControllerHealthEventSink {
  Future<void> recordControllerHealthEvent(
    ControllerHealthEventType type, {
    required DateTime occurredAt,
    String? details,
  });
}

abstract interface class ControllerHealthTimer {
  void cancel();
}

typedef ControllerHealthTimerFactory =
    ControllerHealthTimer Function(Duration delay, void Function() callback);

class ControllerHealthSupervisor
    implements
        StagedControllerGateway,
        ControllerBenchGateway,
        ControllerDiagnosticsGateway,
        ControllerEventGateway {
  ControllerHealthSupervisor({
    required StagedControllerGateway delegate,
    required Stream<BleAvailabilitySnapshot> availability,
    required ControllerHealthEventSink eventSink,
    DateTime Function()? now,
    ControllerHealthTimerFactory? timerFactory,
    this.heartbeatInterval = const Duration(seconds: 10),
    this.reconnectBackoff = const [
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 30),
      Duration(seconds: 60),
    ],
  }) : // Public parameter names are part of the supervisor's call-site API.
       // ignore: prefer_initializing_formals
       _delegate = delegate,
       // ignore: prefer_initializing_formals
       _eventSink = eventSink,
       _now = now ?? DateTime.now,
       _timerFactory = timerFactory ?? _scheduleTimer {
    _delegateSubscription = _delegate.watchController().listen(
      _handleDelegateSnapshot,
      onError: (Object error, StackTrace stackTrace) {
        unawaited(_markOffline(error.toString()));
      },
    );
    _availabilitySubscription = availability.listen(_handleAvailability);
    final eventDelegate = _delegate is ControllerEventGateway
        ? _delegate as ControllerEventGateway
        : null;
    _delegateEventSubscription = eventDelegate?.watchControllerEvents().listen(
      _controllerEvents.add,
    );
  }

  final StagedControllerGateway _delegate;
  final ControllerHealthEventSink _eventSink;
  final DateTime Function() _now;
  final ControllerHealthTimerFactory _timerFactory;
  final Duration heartbeatInterval;
  final List<Duration> reconnectBackoff;
  final _controller = StreamController<ControllerSnapshot>.broadcast();
  final _controllerEvents = StreamController<ControllerEvent>.broadcast();

  late final StreamSubscription<ControllerSnapshot> _delegateSubscription;
  late final StreamSubscription<BleAvailabilitySnapshot>
  _availabilitySubscription;
  StreamSubscription<ControllerEvent>? _delegateEventSubscription;
  ControllerSnapshot _snapshot = const ControllerSnapshot.disconnected();
  ControllerHealthTimer? _timer;
  Future<void>? _activeConnection;
  Future<void>? _activeDisconnect;
  Future<void>? _activeMaintenance;
  int? _activeMaintenanceGeneration;
  Future<void> _eventChain = Future<void>.value();
  BleAvailabilityState _availability = BleAvailabilityState.unknown;
  bool _eligible = false;
  bool _connectionWanted = false;
  bool _userCommandBusy = false;
  bool _cancelBusy = false;
  bool _heartbeatOverdue = false;
  bool _suppressDelegateDisconnect = false;
  bool _retrySuppressed = false;
  bool _availabilitySuppressed = false;
  bool _closed = false;
  bool _restartAfterActiveConnection = false;
  int _reconnectAttempt = 0;
  int _monitorGeneration = 0;
  DateTime? _lastSuccessfulHeartbeatAt;

  @override
  Stream<ControllerSnapshot> watchController() async* {
    yield _snapshot;
    yield* _controller.stream;
  }

  @override
  Stream<ControllerEvent> watchControllerEvents() => _controllerEvents.stream;

  Future<void> setMonitoringEligible(bool eligible) async {
    if (_closed || _eligible == eligible) return;
    _eligible = eligible;
    if (!eligible) {
      _monitorGeneration += 1;
      _cancelTimer();
      _setState(
        ControllerHealthState.disconnected,
        'Controller monitoring paused',
      );
      await _disconnectDelegate();
      return;
    }
    _cancelTimer();
    if (_connectionWanted) {
      unawaited(_startConnection(isReconnect: true));
    }
  }

  @override
  Future<void> connect() async {
    _ensureOpen();
    if (!_eligible) {
      throw const ControllerCommandPreconditionException(
        'Controller access is unavailable for this device role.',
      );
    }
    _connectionWanted = true;
    _retrySuppressed = false;
    _availabilitySuppressed = false;
    if (_availability == BleAvailabilityState.unavailable) {
      _setState(
        ControllerHealthState.error,
        'Bluetooth is unavailable',
        errorKind: ControllerErrorKind.bluetoothUnavailable,
      );
      throw const ControllerCommandPreconditionException(
        'Bluetooth is unavailable.',
      );
    }
    await _startConnection(isReconnect: false);
  }

  Future<void> _startConnection({required bool isReconnect}) {
    final active = _activeConnection;
    if (active != null) {
      if (isReconnect) _restartAfterActiveConnection = true;
      return active;
    }
    late final Future<void> attempt;
    final generation = _monitorGeneration;
    attempt =
        _connectAndVerify(
          isReconnect: isReconnect,
          generation: generation,
        ).whenComplete(() {
          if (identical(_activeConnection, attempt)) {
            _activeConnection = null;
            final restart = _restartAfterActiveConnection;
            _restartAfterActiveConnection = false;
            if (restart &&
                _canMonitor &&
                _snapshot.healthState != ControllerHealthState.online) {
              unawaited(_startConnection(isReconnect: true));
            }
          }
        });
    _activeConnection = attempt;
    return attempt;
  }

  Future<void> _connectAndVerify({
    required bool isReconnect,
    required int generation,
  }) async {
    if (!_canMonitor || _retrySuppressed || generation != _monitorGeneration) {
      return;
    }
    final disconnect = _activeDisconnect;
    if (disconnect != null) await disconnect;
    if (!_canMonitor || _retrySuppressed || generation != _monitorGeneration) {
      return;
    }
    _cancelTimer();
    _setState(
      isReconnect
          ? ControllerHealthState.reconnecting
          : ControllerHealthState.connecting,
      isReconnect ? 'Reconnecting to controller' : 'Connecting to controller',
    );
    if (isReconnect && _reconnectAttempt == 1) {
      _recordEvent(ControllerHealthEventType.reconnecting);
    }
    try {
      await _delegate.connect();
      if (!_canMonitor || generation != _monitorGeneration) return;
      _setState(
        ControllerHealthState.verifying,
        'Verifying controller heartbeat',
      );
      await _runAutomaticHeartbeat(generation: generation);
    } on ControllerCommandPreconditionException catch (error) {
      if (!_canMonitor || generation != _monitorGeneration) return;
      _retrySuppressed = true;
      _availabilitySuppressed = false;
      _setState(ControllerHealthState.error, error.message);
      _recordEvent(ControllerHealthEventType.error, details: error.message);
      rethrow;
    } on Object catch (error) {
      if (!_canMonitor || generation != _monitorGeneration) return;
      await _markOffline(error.toString());
      if (!isReconnect) rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _monitorGeneration += 1;
    _connectionWanted = false;
    _retrySuppressed = false;
    _availabilitySuppressed = false;
    _reconnectAttempt = 0;
    _cancelTimer();
    await _disconnectDelegate();
    _setState(ControllerHealthState.disconnected, 'Controller disconnected');
  }

  @override
  Future<void> requestDispense({required String doseId}) {
    return requestStagedDispense(doseId: doseId, onStage: (_) async {});
  }

  @override
  Future<void> requestStagedDispense({
    required String doseId,
    ControllerMovementCommand movement = ControllerMovementCommand.dispenseNext,
    required ControllerDispenseStageCallback onStage,
  }) {
    return _runUserCommand<void>(() {
      return _delegate.requestStagedDispense(
        doseId: doseId,
        movement: movement,
        onStage: onStage,
      );
    });
  }

  @override
  Future<String> runBenchCommand(ControllerBenchCommand command) async {
    final benchDelegate = _delegate is ControllerBenchGateway
        ? _delegate as ControllerBenchGateway
        : null;
    if (benchDelegate == null) {
      throw const ControllerCommandPreconditionException(
        'Controller does not support bench commands.',
      );
    }
    final generation = _monitorGeneration;
    try {
      final result = await _runUserCommand<String>(
        () => benchDelegate.runBenchCommand(command),
        markTransportFailures: false,
      );
      if (command == ControllerBenchCommand.heartbeat &&
          generation == _monitorGeneration &&
          _canMonitor) {
        _markOnline();
      }
      return result;
    } on Object catch (error) {
      if (generation == _monitorGeneration &&
          (command == ControllerBenchCommand.heartbeat ||
              _isTransportFailure(error))) {
        await _markOffline(
          error.toString(),
          heartbeatMissed: command == ControllerBenchCommand.heartbeat,
        );
      }
      rethrow;
    }
  }

  @override
  Future<ControllerDiagnosticReport> readControllerDiagnostics() {
    final diagnosticsDelegate = _delegate is ControllerDiagnosticsGateway
        ? _delegate as ControllerDiagnosticsGateway
        : null;
    if (diagnosticsDelegate == null) {
      throw const ControllerCommandPreconditionException(
        'Controller does not support diagnostics reports.',
      );
    }
    return _runUserCommand(diagnosticsDelegate.readControllerDiagnostics);
  }

  Future<T> _runUserCommand<T>(
    Future<T> Function() action, {
    bool markTransportFailures = true,
  }) async {
    final maintenance = _activeMaintenance;
    if (maintenance != null) await maintenance;
    _requireOnline();
    if (_userCommandBusy || _cancelBusy) {
      throw const ControllerCommandPreconditionException(
        'Another controller command is already active.',
      );
    }
    final generation = _monitorGeneration;
    _userCommandBusy = true;
    try {
      return await action();
    } on Object catch (error) {
      if (markTransportFailures &&
          generation == _monitorGeneration &&
          _isTransportFailure(error)) {
        await _markOffline(error.toString());
      }
      rethrow;
    } finally {
      _userCommandBusy = false;
      if (_heartbeatOverdue && _canMonitor) {
        _heartbeatOverdue = false;
        _scheduleHeartbeat(Duration.zero);
      }
    }
  }

  @override
  Future<void> cancelActiveCommand() async {
    final maintenance = _activeMaintenance;
    if (maintenance != null) await maintenance;
    _cancelBusy = true;
    try {
      await _delegate.cancelActiveCommand();
    } finally {
      _cancelBusy = false;
      if (_heartbeatOverdue && _canMonitor) {
        _heartbeatOverdue = false;
        _scheduleHeartbeat(Duration.zero);
      }
    }
  }

  void _scheduleHeartbeat([Duration? delay]) {
    _cancelTimer();
    if (!_canMonitor || _snapshot.healthState != ControllerHealthState.online) {
      return;
    }
    _timer = _timerFactory(delay ?? heartbeatInterval, () {
      _timer = null;
      unawaited(_heartbeatDue());
    });
  }

  Future<void> _heartbeatDue() async {
    if (!_canMonitor || _snapshot.healthState != ControllerHealthState.online) {
      return;
    }
    if (_userCommandBusy || _cancelBusy || _activeMaintenance != null) {
      _heartbeatOverdue = true;
      return;
    }
    try {
      await _runAutomaticHeartbeat();
    } on Object {
      // The health transition is handled by _runAutomaticHeartbeat.
    }
  }

  Future<void> _runAutomaticHeartbeat({int? generation}) {
    final targetGeneration = generation ?? _monitorGeneration;
    final active = _activeMaintenance;
    if (active != null) {
      if (_activeMaintenanceGeneration == targetGeneration) return active;
      return active.then(
        (_) => _runAutomaticHeartbeat(generation: targetGeneration),
        onError: (Object _, StackTrace _) =>
            _runAutomaticHeartbeat(generation: targetGeneration),
      );
    }
    late final Future<void> heartbeat;
    heartbeat = _performAutomaticHeartbeat(targetGeneration).whenComplete(() {
      if (identical(_activeMaintenance, heartbeat)) {
        _activeMaintenance = null;
        _activeMaintenanceGeneration = null;
      }
    });
    _activeMaintenance = heartbeat;
    _activeMaintenanceGeneration = targetGeneration;
    return heartbeat;
  }

  Future<void> _performAutomaticHeartbeat(int generation) async {
    final benchDelegate = _delegate is ControllerBenchGateway
        ? _delegate as ControllerBenchGateway
        : null;
    if (benchDelegate == null) {
      throw const ControllerCommandPreconditionException(
        'Controller does not support heartbeat verification.',
      );
    }
    try {
      await benchDelegate.runBenchCommand(ControllerBenchCommand.heartbeat);
      if (generation == _monitorGeneration && _canMonitor) _markOnline();
    } on Object catch (error) {
      if (generation == _monitorGeneration) {
        await _markOffline(error.toString(), heartbeatMissed: true);
      }
      rethrow;
    }
  }

  void _markOnline() {
    final recovered =
        _reconnectAttempt > 0 ||
        _snapshot.healthState == ControllerHealthState.offline ||
        _snapshot.healthState == ControllerHealthState.reconnecting;
    _lastSuccessfulHeartbeatAt = _current();
    _reconnectAttempt = 0;
    _retrySuppressed = false;
    _setState(ControllerHealthState.online, 'Controller online');
    if (recovered) _recordEvent(ControllerHealthEventType.recovered);
    _scheduleHeartbeat();
  }

  Future<void> _markOffline(
    String details, {
    bool heartbeatMissed = false,
  }) async {
    if (!_connectionWanted || !_eligible || _closed) return;
    _cancelTimer();
    if (heartbeatMissed) {
      _recordEvent(ControllerHealthEventType.heartbeatMissed, details: details);
    }
    final wasOffline =
        _snapshot.healthState == ControllerHealthState.offline ||
        _snapshot.healthState == ControllerHealthState.reconnecting;
    _setState(ControllerHealthState.offline, 'Controller offline');
    if (!wasOffline) {
      _recordEvent(ControllerHealthEventType.offline, details: details);
    }
    await _disconnectDelegate();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_canMonitor || _retrySuppressed || reconnectBackoff.isEmpty) return;
    final index = _reconnectAttempt.clamp(0, reconnectBackoff.length - 1);
    final delay = reconnectBackoff[index];
    _reconnectAttempt += 1;
    final nextReconnectAt = _current().add(delay);
    _setState(
      ControllerHealthState.offline,
      'Controller offline; retrying soon',
      nextReconnectAt: nextReconnectAt,
    );
    _timer = _timerFactory(delay, () {
      _timer = null;
      if (!_canMonitor || _retrySuppressed) return;
      unawaited(_startConnection(isReconnect: true));
    });
  }

  void _handleDelegateSnapshot(ControllerSnapshot snapshot) {
    if (_closed) return;
    switch (snapshot.connectionState) {
      case ControllerConnectionState.connected:
        if (_canMonitor &&
            _activeConnection == null &&
            _snapshot.healthState != ControllerHealthState.online &&
            _activeMaintenance == null) {
          _setState(
            ControllerHealthState.verifying,
            'Verifying controller heartbeat',
          );
          unawaited(_runAutomaticHeartbeat());
        }
      case ControllerConnectionState.disconnected:
        if (_suppressDelegateDisconnect) return;
        if (_canMonitor &&
            _snapshot.healthState != ControllerHealthState.connecting &&
            _snapshot.healthState != ControllerHealthState.reconnecting) {
          unawaited(_markOffline('Controller connection was lost.'));
        }
      case ControllerConnectionState.scanning:
      case ControllerConnectionState.error:
        break;
    }
  }

  void _handleAvailability(BleAvailabilitySnapshot snapshot) {
    _availability = snapshot.state;
    if (_closed || !_connectionWanted) return;
    if (snapshot.state == BleAvailabilityState.unavailable) {
      _monitorGeneration += 1;
      _retrySuppressed = true;
      _availabilitySuppressed = true;
      _cancelTimer();
      unawaited(_disconnectDelegate());
      _setState(
        ControllerHealthState.error,
        'Bluetooth is unavailable',
        errorKind: ControllerErrorKind.bluetoothUnavailable,
      );
      _recordEvent(
        ControllerHealthEventType.error,
        details: 'Bluetooth is unavailable.',
      );
      return;
    }
    if (snapshot.state == BleAvailabilityState.available &&
        _availabilitySuppressed) {
      _retrySuppressed = false;
      _availabilitySuppressed = false;
      _reconnectAttempt = 0;
      if (_eligible) unawaited(_startConnection(isReconnect: true));
    }
  }

  Future<void> _disconnectDelegate() {
    final active = _activeDisconnect;
    if (active != null) return active;

    late final Future<void> attempt;
    attempt = _performDelegateDisconnect().whenComplete(() {
      if (identical(_activeDisconnect, attempt)) _activeDisconnect = null;
    });
    _activeDisconnect = attempt;
    return attempt;
  }

  Future<void> _performDelegateDisconnect() async {
    _suppressDelegateDisconnect = true;
    try {
      try {
        await _delegate.disconnect();
      } on Object catch (error) {
        // Disconnect is best effort. Health is already fail-closed, and retry
        // policy must not be blocked by a transport cleanup failure.
        _recordEvent(
          ControllerHealthEventType.error,
          details: 'Controller disconnect cleanup failed: $error',
        );
      }
    } finally {
      await Future<void>.value();
      _suppressDelegateDisconnect = false;
    }
  }

  bool _isTransportFailure(Object error) {
    return error is ControllerTransportOfflineException ||
        error is ControllerCommandPreAcceptanceTimeoutException ||
        error is ControllerCommandTimeoutException ||
        error is ControllerCommandInterruptedException;
  }

  bool get _canMonitor =>
      !_closed &&
      _eligible &&
      _connectionWanted &&
      _availability != BleAvailabilityState.unavailable;

  void _requireOnline() {
    if (_snapshot.healthState != ControllerHealthState.online) {
      throw const ControllerTransportOfflineException(
        'Controller heartbeat is not verified.',
      );
    }
  }

  void _setState(
    ControllerHealthState state,
    String label, {
    DateTime? nextReconnectAt,
    ControllerErrorKind? errorKind,
  }) {
    if (_closed) return;
    final connectionState = switch (state) {
      ControllerHealthState.connecting ||
      ControllerHealthState.reconnecting => ControllerConnectionState.scanning,
      ControllerHealthState.verifying ||
      ControllerHealthState.online => ControllerConnectionState.connected,
      ControllerHealthState.error => ControllerConnectionState.error,
      ControllerHealthState.disconnected ||
      ControllerHealthState.offline => ControllerConnectionState.disconnected,
    };
    _snapshot = ControllerSnapshot(
      connectionState: connectionState,
      canRequestDispense: state == ControllerHealthState.online,
      statusLabel: label,
      healthState: state,
      errorKind: state == ControllerHealthState.error
          ? errorKind ?? ControllerErrorKind.other
          : null,
      lastSuccessfulHeartbeatAt: _lastSuccessfulHeartbeatAt,
      reconnectAttempt: _reconnectAttempt,
      nextReconnectAt: nextReconnectAt,
    );
    _controller.add(_snapshot);
  }

  void _recordEvent(ControllerHealthEventType type, {String? details}) {
    final occurredAt = _current();
    _eventChain = _eventChain
        .then(
          (_) => _eventSink.recordControllerHealthEvent(
            type,
            occurredAt: occurredAt,
            details: details,
          ),
        )
        .onError((_, _) {});
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  DateTime _current() => _now().toUtc();

  void _ensureOpen() {
    if (_closed) throw StateError('Controller health supervisor is closed.');
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _monitorGeneration += 1;
    _closed = true;
    _cancelTimer();
    await _disconnectDelegate();
    await _delegateSubscription.cancel();
    await _delegateEventSubscription?.cancel();
    await _availabilitySubscription.cancel();
    await _delegate.close();
    await _eventChain;
    await _controller.close();
    await _controllerEvents.close();
  }

  static ControllerHealthTimer _scheduleTimer(
    Duration delay,
    void Function() callback,
  ) {
    return _DartControllerHealthTimer(Timer(delay, callback));
  }
}

class _DartControllerHealthTimer implements ControllerHealthTimer {
  const _DartControllerHealthTimer(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}
