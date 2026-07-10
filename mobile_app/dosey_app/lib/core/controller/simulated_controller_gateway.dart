import 'dart:async';

import 'package:dosey_app/core/controller/controller_gateway.dart';

typedef RobotModeAccess = FutureOr<bool> Function();

class SimulatedControllerGateway implements ControllerGateway {
  SimulatedControllerGateway({RobotModeAccess? canHostRobot})
    : _canHostRobot = canHostRobot ?? _denyRobotMode;

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
