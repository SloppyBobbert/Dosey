import 'dart:async';

import 'package:dosey_app/core/controller/controller_diagnostics.dart';
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

enum SimulatedDiagnosticsScenario { healthy, missingHardware, abnormalSignals }

class SimulatedControllerGateway
    implements
        StagedControllerGateway,
        ControllerBenchGateway,
        ControllerDiagnosticsGateway,
        ControllerEventGateway {
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
  SimulatedDiagnosticsScenario _nextDiagnosticsScenario =
      SimulatedDiagnosticsScenario.healthy;
  final _controller = StreamController<ControllerSnapshot>.broadcast();
  final _controllerEvents = StreamController<ControllerEvent>.broadcast();

  ControllerSnapshot _snapshot = const ControllerSnapshot.disconnected();

  @override
  Stream<ControllerSnapshot> watchController() async* {
    yield _snapshot;
    yield* _controller.stream;
  }

  @override
  Stream<ControllerEvent> watchControllerEvents() => _controllerEvents.stream;

  void emitWakeFace() => _controllerEvents.add(ControllerEvent.wakeFace);

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

  void queueNextDiagnosticsScenario(SimulatedDiagnosticsScenario scenario) {
    _nextDiagnosticsScenario = scenario;
  }

  @override
  Future<ControllerDiagnosticReport> readControllerDiagnostics() async {
    if (!_snapshot.canRequestDispense) {
      throw const ControllerTransportOfflineException();
    }
    await _benchDelay(const Duration(milliseconds: 150));
    final scenario = _nextDiagnosticsScenario;
    _nextDiagnosticsScenario = SimulatedDiagnosticsScenario.healthy;
    final signalCodes = switch (scenario) {
      SimulatedDiagnosticsScenario.healthy => const [
        'PIR_RAW_0',
        'LIGHT_RAW_2048',
        'BUTTON_1A_RAW_0',
        'BUTTON_1B_RAW_0',
        'BUTTON_2A_RAW_0',
        'BUTTON_2B_RAW_0',
        'DHT20_PRESENT',
        'PIR_WAKE_ENABLED',
        'SERVO_ENABLED',
        'MOVEMENT_IDLE',
      ],
      SimulatedDiagnosticsScenario.missingHardware => const [
        'PIR_RAW_0',
        'LIGHT_RAW_0',
        'BUTTON_1A_RAW_0',
        'BUTTON_1B_RAW_0',
        'BUTTON_2A_RAW_0',
        'BUTTON_2B_RAW_0',
        'DHT20_NOT_FOUND',
        'PIR_WAKE_DISABLED',
        'SERVO_DISABLED',
        'MOVEMENT_IDLE',
      ],
      SimulatedDiagnosticsScenario.abnormalSignals => const [
        'PIR_RAW_1',
        'LIGHT_RAW_4095',
        'BUTTON_1A_RAW_1',
        'BUTTON_1B_RAW_1',
        'BUTTON_2A_RAW_1',
        'BUTTON_2B_RAW_1',
        'DHT20_NOT_FOUND',
        'PIR_WAKE_DISABLED',
        'SERVO_DISABLED',
        'MOVEMENT_ACTIVE',
      ],
    };
    return ControllerDiagnosticsRegistry.standard.parse([
      'DIAGNOSTICS_BEGIN',
      'FIRMWARE_DOSEY_CONTROLLER',
      'PROTOCOL_D1',
      'BOARD_XIAO_ESP32_C6_GROVE_BASE',
      'BUILD_BASELINE',
      'MOVEMENT_TIMEOUT_MS_2500',
      'SERVO_PULSE_US_1000_2000',
      'SERVO_ANGLES_DEG_90_100',
      'DISPENSE_NEXT_DISABLED',
      'GROVE_BASE_D8_SERVO_PROFILE',
      ...signalCodes,
      'DHT20_READING_AWAITING_VALIDATION',
      'BUTTON_EVENTS_AWAITING_VALIDATION',
      'PIR_CALIBRATION_REQUIRED',
      'BUZZER_TEST_DISABLED',
      'LED_TEST_AVAILABLE',
      'RELIABILITY_SESSION_NOT_STARTED',
      'DIAGNOSTICS_DONE',
    ]);
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
        'FIRMWARE_DOSEY_CONTROLLER, BOARD_XIAO_ESP32_C6_GROVE_BASE, BUILD_BASELINE',
      ControllerBenchCommand.configStatus =>
        'SERVO_DISABLED, PIR_DISABLED, GROVE_BASE_D8_SERVO_PROFILE',
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
  Future<void> close() async {
    await _controller.close();
    await _controllerEvents.close();
  }

  void _setSnapshot(ControllerSnapshot snapshot) {
    _snapshot = snapshot;
    _controller.add(snapshot);
  }

  static bool _denyRobotMode() => false;

  static Future<void> _noDelay(Duration _) async {}
}
