import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/controller/controller_lifecycle_service.dart';
import 'package:dosey_app/core/controller/local_controller_command_repository.dart';

class ControllerBenchService {
  ControllerBenchService({
    required ControllerGateway controller,
    required ControllerLifecycleService lifecycle,
    required ControllerCommandRepository commandRepository,
    DateTime Function()? now,
  }) : // Public parameter names are part of the service's call-site API.
       // ignore: prefer_initializing_formals
       _controller = controller,
       // ignore: prefer_initializing_formals
       _lifecycle = lifecycle,
       // ignore: prefer_initializing_formals
       _commandRepository = commandRepository,
       _now = now ?? DateTime.now;

  final ControllerGateway _controller;
  final ControllerLifecycleService _lifecycle;
  final ControllerCommandRepository _commandRepository;
  final DateTime Function() _now;
  bool _wasOffline = false;

  Future<void> run(ControllerBenchCommand command) async {
    switch (command) {
      case ControllerBenchCommand.servoTest:
        return _lifecycle.requestManualServoTest();
      case ControllerBenchCommand.dispenseTest:
        return _lifecycle.requestManualDispenseTest();
      case ControllerBenchCommand.status:
      case ControllerBenchCommand.heartbeat:
      case ControllerBenchCommand.deviceInfo:
      case ControllerBenchCommand.configStatus:
      case ControllerBenchCommand.safetyStatus:
      case ControllerBenchCommand.debugOn:
      case ControllerBenchCommand.debugOff:
      case ControllerBenchCommand.pirStatus:
      case ControllerBenchCommand.ledTest:
        return _runDiagnostic(command);
    }
  }

  Future<void> _runDiagnostic(ControllerBenchCommand command) async {
    final commandType = switch (command) {
      ControllerBenchCommand.status => ControllerCommandType.status,
      ControllerBenchCommand.heartbeat => ControllerCommandType.heartbeat,
      ControllerBenchCommand.deviceInfo => ControllerCommandType.deviceInfo,
      ControllerBenchCommand.configStatus => ControllerCommandType.configStatus,
      ControllerBenchCommand.safetyStatus => ControllerCommandType.safetyStatus,
      ControllerBenchCommand.debugOn => ControllerCommandType.debugOn,
      ControllerBenchCommand.debugOff => ControllerCommandType.debugOff,
      ControllerBenchCommand.pirStatus => ControllerCommandType.pirStatus,
      ControllerBenchCommand.ledTest => ControllerCommandType.ledTest,
      ControllerBenchCommand.servoTest ||
      ControllerBenchCommand.dispenseTest => throw StateError(
        'Movement commands are handled by the lifecycle service.',
      ),
    };
    final sentAt = _current();
    final session = await _commandRepository.createSession(
      commandType: commandType,
      now: sentAt,
    );
    await _commandRepository.appendEvent(
      session.id,
      ControllerCommandEventType.commandSent,
      occurredAt: sentAt,
    );

    try {
      final benchController = _controller is ControllerBenchGateway
          ? _controller as ControllerBenchGateway
          : null;
      if (benchController == null) {
        throw const ControllerCommandPreconditionException(
          'Controller does not support bench commands.',
        );
      }
      final details = await benchController.runBenchCommand(command);
      final resolvedAt = _current();
      await _commandRepository.appendEvent(
        session.id,
        command == ControllerBenchCommand.heartbeat
            ? ControllerCommandEventType.heartbeatOk
            : ControllerCommandEventType.ack,
        occurredAt: resolvedAt,
        details: details,
      );
      if (_wasOffline) {
        await _commandRepository.appendEvent(
          session.id,
          ControllerCommandEventType.reconnected,
          occurredAt: resolvedAt,
        );
        _wasOffline = false;
      }
      await _commandRepository.updateSessionState(
        session.id,
        ControllerCommandSessionState.succeeded,
        acceptedAt: resolvedAt,
        resolvedAt: resolvedAt,
        updatedAt: resolvedAt,
      );
    } on Object catch (error) {
      final failedAt = _current();
      final offline = error is ControllerTransportOfflineException;
      _wasOffline = _wasOffline || offline;
      await _commandRepository.appendEvent(
        session.id,
        command == ControllerBenchCommand.heartbeat
            ? ControllerCommandEventType.heartbeatMissed
            : offline
            ? ControllerCommandEventType.offline
            : ControllerCommandEventType.controllerError,
        occurredAt: failedAt,
        details: error.toString(),
      );
      if (offline && command == ControllerBenchCommand.heartbeat) {
        await _commandRepository.appendEvent(
          session.id,
          ControllerCommandEventType.offline,
          occurredAt: failedAt,
          details: error.toString(),
        );
      }
      await _commandRepository.updateSessionState(
        session.id,
        ControllerCommandSessionState.failed,
        failureReason: offline ? ControllerCommandFailureReason.offline : null,
        updatedAt: failedAt,
      );
      rethrow;
    }
  }

  DateTime _current() => _now().toUtc();
}
