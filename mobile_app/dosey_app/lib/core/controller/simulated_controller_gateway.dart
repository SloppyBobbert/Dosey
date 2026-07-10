import 'dart:async';

import 'package:dosey_app/core/controller/controller_gateway.dart';

typedef RobotModeAccess = FutureOr<bool> Function();

enum SimulatedDispenseOutcome {
  success,
  rejected,
  offlineBeforeAcceptance,
  disconnectBeforeAcceptance,
  timeoutAfterAcceptance,
  jamAfterAcceptance,
  disconnectAfterAcceptance,
}

class SimulatedControllerGateway implements ControllerGateway {
  SimulatedControllerGateway({
    RobotModeAccess? canHostRobot,
    SimulatedDispenseOutcome nextDispenseOutcome =
        SimulatedDispenseOutcome.success,
  }) : _canHostRobot = canHostRobot ?? _denyRobotMode,
       _nextDispenseOutcome = nextDispenseOutcome;

  final RobotModeAccess _canHostRobot;
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
        return;
      case SimulatedDispenseOutcome.rejected:
        throw const ControllerCommandRejectedException();
      case SimulatedDispenseOutcome.offlineBeforeAcceptance:
      case SimulatedDispenseOutcome.disconnectBeforeAcceptance:
        throw const ControllerTransportOfflineException();
      case SimulatedDispenseOutcome.timeoutAfterAcceptance:
        throw const ControllerCommandTimeoutException();
      case SimulatedDispenseOutcome.jamAfterAcceptance:
        throw const ControllerCommandJamException();
      case SimulatedDispenseOutcome.disconnectAfterAcceptance:
        throw const ControllerCommandInterruptedException();
    }
  }

  void queueNextDispenseOutcome(SimulatedDispenseOutcome outcome) {
    _nextDispenseOutcome = outcome;
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
}
