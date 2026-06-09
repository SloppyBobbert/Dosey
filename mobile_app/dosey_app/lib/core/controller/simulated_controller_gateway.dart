import 'dart:async';

import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';

class SimulatedControllerGateway implements ControllerGateway {
  SimulatedControllerGateway(this._doseLog);

  final DoseLogRepository _doseLog;
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

    await _doseLog.addEvent(
      DoseLogEvent.controllerDispenseSucceeded(
        doseId: doseId,
        occurredAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Future<void> cancelActiveCommand() async {}

  Future<void> close() => _controller.close();

  void _setSnapshot(ControllerSnapshot snapshot) {
    _snapshot = snapshot;
    _controller.add(snapshot);
  }
}
