import 'dart:async';

import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';

typedef RobotModeAccess = FutureOr<bool> Function();

class SimulatedControllerGateway implements ControllerGateway {
  SimulatedControllerGateway(this._doseLog, {RobotModeAccess? canHostRobot})
    : _canHostRobot = canHostRobot ?? _denyRobotMode;

  final DoseLogRepository _doseLog;
  final RobotModeAccess _canHostRobot;
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
      throw StateError('Controller must be connected before dispense.');
    }
    if (!await Future<bool>.value(_canHostRobot())) {
      throw StateError('Robot Mode must be active before dispense.');
    }

    // The simulator records movement only. Taken/skipped/help outcomes must be
    // logged by the human follow-up flow.
    await _doseLog.addEvent(
      DoseLogEvent.controllerDispenseSucceeded(
        doseId: doseId,
        occurredAt: DateTime.now().toUtc(),
      ),
    );
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
