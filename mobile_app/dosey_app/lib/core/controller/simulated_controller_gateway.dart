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

class SimulatedControllerGateway
    implements StagedControllerGateway, ControllerBenchGateway {
  SimulatedControllerGateway({
    RobotModeAccess? canHostRobot,
    SimulatedDispenseOutcome nextDispenseOutcome =
        SimulatedDispenseOutcome.success,
    SimulatorDelay? delay,
    SimulatorDelay? benchDelay,
  }) : this._internal(
         canHostRobot: canHostRobot,
         nextDispenseOutcome: nextDispenseOutcome,
         delay: delay,
         benchDelay: benchDelay,
       );

  SimulatedControllerGateway._internal({
    RobotModeAccess? canHostRobot,
    required this._nextDispenseOutcome,
    SimulatorDelay? delay,
    SimulatorDelay? benchDelay,
  }) : _canHostRobot = canHostRobot ?? _denyRobotMode,
       _delay = delay ?? _noDelay,
       _benchDelay = benchDelay ?? _noDelay;

  final RobotModeAccess _canHostRobot;
  final SimulatorDelay _delay;
  final SimulatorDelay _benchDelay;
  SimulatedDispenseOutcome _nextDispenseOutcome;
  final _controller = StreamController<ControllerSnapshot>.broadcast();

  ControllerSnapshot _snapshot = const ControllerSnapshot.disconnected();

  @override
  Stream<ControllerSnapshot> watchController() async* {
    yield _snapshot;
    yield* _controller.stream;
  }

  @override
  Future<void> connect() async {
    _setSnapshot(const ControllerSnapshot.connected());
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

  @override
  Future<String> runBenchCommand(ControllerBenchCommand command) async {
    if (!_snapshot.canRequestDispense) {
      throw const ControllerTransportOfflineException();
    }
    await _benchDelay(const Duration(milliseconds: 150));
    return switch (command) {
      ControllerBenchCommand.status => 'Simulator connected',
      ControllerBenchCommand.heartbeat => 'Heartbeat OK',
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
