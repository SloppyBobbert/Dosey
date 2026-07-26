import 'dart:async';

import 'package:dosey_app/core/controller/controller_gateway.dart';

typedef RobotModeAccess = FutureOr<bool> Function();
typedef SimulatorDelay = Future<void> Function(Duration duration);

enum SimulatedDispenseOutcome {
  success,
  rejected,
  offlineBeforeAcceptance,
  disconnectBeforeAcceptance,
  timeoutBeforeAcceptance,
  timeoutAfterAcceptance,
  jamAfterAcceptance,
  disconnectAfterAcceptance,
}

enum SimulatedHeartbeatOutcome { success, missed, disconnect }

enum SimulatedConnectOutcome { success, failure }

class SimulatedControllerGateway
    implements StagedControllerGateway, ControllerBenchGateway {
  SimulatedControllerGateway({
    RobotModeAccess? canHostRobot,
    SimulatedDispenseOutcome nextDispenseOutcome =
        SimulatedDispenseOutcome.success,
    bool debugAvailable = false,
    SimulatorDelay? delay,
    SimulatorDelay? benchDelay,
  }) : this._internal(
         canHostRobot: canHostRobot,
         nextDispenseOutcome: nextDispenseOutcome,
         debugAvailable: debugAvailable,
         delay: delay,
         benchDelay: benchDelay,
       );

  SimulatedControllerGateway._internal({
    RobotModeAccess? canHostRobot,
    required this._nextDispenseOutcome,
    required this._debugAvailable,
    SimulatorDelay? delay,
    SimulatorDelay? benchDelay,
  }) : _canHostRobot = canHostRobot ?? _denyRobotMode,
       _delay = delay ?? _noDelay,
       _benchDelay = benchDelay ?? _noDelay;

  final RobotModeAccess _canHostRobot;
  final SimulatorDelay _delay;
  final SimulatorDelay _benchDelay;
  final bool _debugAvailable;
  SimulatedDispenseOutcome _nextDispenseOutcome;
  SimulatedHeartbeatOutcome _nextHeartbeatOutcome =
      SimulatedHeartbeatOutcome.success;
  SimulatedConnectOutcome _nextConnectOutcome = SimulatedConnectOutcome.success;
  final _controller = StreamController<ControllerSnapshot>.broadcast();

  ControllerSnapshot _snapshot = const ControllerSnapshot.disconnected();

  @override
  Stream<ControllerSnapshot> watchController() async* {
    yield _snapshot;
    yield* _controller.stream;
  }

  @override
  Future<void> connect() async {
    final outcome = _nextConnectOutcome;
    _nextConnectOutcome = SimulatedConnectOutcome.success;
    if (outcome == SimulatedConnectOutcome.failure) {
      _setSnapshot(const ControllerSnapshot.disconnected());
      throw const ControllerTransportOfflineException(
        'Simulator connection failed.',
      );
    }
    _setSnapshot(const ControllerSnapshot.online());
  }

  @override
  Future<void> disconnect() async {
    _setSnapshot(const ControllerSnapshot.disconnected());
  }

  @override
  Future<void> requestDispense({required String doseId}) async {
    await requestStagedDispense(doseId: doseId, onStage: (_) async {});
  }

  @override
  Future<void> requestStagedDispense({
    required String doseId,
    ControllerMovementCommand movement = ControllerMovementCommand.dispenseNext,
    required ControllerDispenseStageCallback onStage,
  }) async {
    if (!_snapshot.canRequestDispense) {
      throw const ControllerCommandPreconditionException(
        'Controller must be connected before dispense.',
      );
    }
    if (!await Future<bool>.value(_canHostRobot())) {
      throw const ControllerCommandPreconditionException(
        'Robot Mode must be active before dispense.',
      );
    }

    final outcome = _nextDispenseOutcome;
    _nextDispenseOutcome = SimulatedDispenseOutcome.success;
    switch (outcome) {
      case SimulatedDispenseOutcome.success:
        break;
      case SimulatedDispenseOutcome.rejected:
        throw const ControllerCommandRejectedException();
      case SimulatedDispenseOutcome.offlineBeforeAcceptance:
      case SimulatedDispenseOutcome.disconnectBeforeAcceptance:
        throw const ControllerTransportOfflineException();
      case SimulatedDispenseOutcome.timeoutBeforeAcceptance:
        throw const ControllerCommandPreAcceptanceTimeoutException();
      case SimulatedDispenseOutcome.timeoutAfterAcceptance:
      case SimulatedDispenseOutcome.jamAfterAcceptance:
      case SimulatedDispenseOutcome.disconnectAfterAcceptance:
        break;
    }

    await _delay(const Duration(milliseconds: 250));
    await onStage(ControllerDispenseStage.accepted);
    await _delay(const Duration(milliseconds: 250));
    await onStage(ControllerDispenseStage.movementStarted);
    await _delay(const Duration(milliseconds: 500));

    switch (outcome) {
      case SimulatedDispenseOutcome.success:
        return;
      case SimulatedDispenseOutcome.timeoutAfterAcceptance:
        throw const ControllerCommandTimeoutException();
      case SimulatedDispenseOutcome.jamAfterAcceptance:
        throw const ControllerCommandJamException();
      case SimulatedDispenseOutcome.disconnectAfterAcceptance:
        throw const ControllerCommandInterruptedException();
      case SimulatedDispenseOutcome.rejected:
      case SimulatedDispenseOutcome.offlineBeforeAcceptance:
      case SimulatedDispenseOutcome.disconnectBeforeAcceptance:
      case SimulatedDispenseOutcome.timeoutBeforeAcceptance:
        throw StateError('Pre-acceptance outcome passed acceptance handling.');
    }
  }

  void queueNextDispenseOutcome(SimulatedDispenseOutcome outcome) {
    _nextDispenseOutcome = outcome;
  }

  void queueNextHeartbeatOutcome(SimulatedHeartbeatOutcome outcome) {
    _nextHeartbeatOutcome = outcome;
  }

  void queueNextConnectOutcome(SimulatedConnectOutcome outcome) {
    _nextConnectOutcome = outcome;
  }

  @override
  Future<String> runBenchCommand(ControllerBenchCommand command) async {
    if (!_snapshot.canRequestDispense) {
      throw const ControllerTransportOfflineException();
    }
    await _benchDelay(const Duration(milliseconds: 150));
    if (command == ControllerBenchCommand.heartbeat) {
      final outcome = _nextHeartbeatOutcome;
      _nextHeartbeatOutcome = SimulatedHeartbeatOutcome.success;
      switch (outcome) {
        case SimulatedHeartbeatOutcome.success:
          break;
        case SimulatedHeartbeatOutcome.missed:
          throw const ControllerCommandPreAcceptanceTimeoutException(
            'Simulator heartbeat timed out.',
          );
        case SimulatedHeartbeatOutcome.disconnect:
          _setSnapshot(const ControllerSnapshot.disconnected());
          throw const ControllerTransportOfflineException(
            'Simulator disconnected during heartbeat.',
          );
      }
    }
    return switch (command) {
      ControllerBenchCommand.status => 'Simulator connected',
      ControllerBenchCommand.heartbeat => 'Heartbeat OK',
      ControllerBenchCommand.deviceInfo =>
        'FIRMWARE_DOSEY_CONTROLLER, BUILD_BASELINE',
      ControllerBenchCommand.configStatus =>
        'SERVO_DISABLED, PIR_DISABLED, UART_RESERVED_SERVO_D6_PROFILE',
      ControllerBenchCommand.safetyStatus =>
        'MOVEMENT_TIMEOUT_MS_2500, DISPENSE_NEXT_DISABLED',
      ControllerBenchCommand.debugOn =>
        _debugAvailable
            ? 'DEBUG_ON'
            : throw const ControllerCommandRejectedException(
                'COMMAND_DISABLED',
              ),
      ControllerBenchCommand.debugOff =>
        _debugAvailable
            ? 'DEBUG_OFF'
            : throw const ControllerCommandRejectedException(
                'COMMAND_DISABLED',
              ),
      ControllerBenchCommand.pirStatus => 'PIR idle',
      ControllerBenchCommand.ledTest => 'LED test complete',
      ControllerBenchCommand.servoTest ||
      ControllerBenchCommand.dispenseTest => throw ArgumentError(
        'Movement bench commands must use the dispense lifecycle.',
      ),
    };
  }

  @override
  Future<void> cancelActiveCommand() async {}

  @override
  Future<void> close() => _controller.close();

  void _setSnapshot(ControllerSnapshot snapshot) {
    _snapshot = snapshot;
    _controller.add(snapshot);
  }

  static bool _denyRobotMode() => false;

  static Future<void> _noDelay(Duration _) async {}
}
