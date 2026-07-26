enum ControllerConnectionState { disconnected, scanning, connected, error }

enum ControllerHealthState {
  disconnected,
  connecting,
  verifying,
  online,
  offline,
  reconnecting,
  error,
}

enum ControllerErrorKind { bluetoothUnavailable, other }

abstract class ControllerGatewayException implements Exception {
  const ControllerGatewayException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ControllerCommandRejectedException extends ControllerGatewayException {
  const ControllerCommandRejectedException([
    super.message = 'Controller rejected command.',
  ]);
}

class ControllerCommandPreconditionException
    extends ControllerGatewayException {
  const ControllerCommandPreconditionException([
    super.message = 'Controller cannot accept this command yet.',
  ]);
}

class ControllerTransportOfflineException extends ControllerGatewayException {
  const ControllerTransportOfflineException([
    super.message = 'Controller transport is offline.',
  ]);
}

class ControllerCommandTimeoutException extends ControllerGatewayException {
  const ControllerCommandTimeoutException([
    super.message = 'Controller command timed out after acceptance.',
  ]);
}

class ControllerCommandPreAcceptanceTimeoutException
    extends ControllerGatewayException {
  const ControllerCommandPreAcceptanceTimeoutException([
    super.message = 'Controller did not respond before command acceptance.',
  ]);
}

class ControllerCommandJamException extends ControllerGatewayException {
  const ControllerCommandJamException([
    super.message = 'Controller reported a jam after acceptance.',
  ]);
}

class ControllerCommandInterruptedException extends ControllerGatewayException {
  const ControllerCommandInterruptedException([
    super.message =
        'Controller connection was lost after the command may have been accepted.',
  ]);
}

class ControllerSnapshot {
  const ControllerSnapshot({
    required this.connectionState,
    required this.canRequestDispense,
    required this.statusLabel,
    this.healthState = ControllerHealthState.disconnected,
    this.errorKind,
    this.lastSuccessfulHeartbeatAt,
    this.reconnectAttempt = 0,
    this.nextReconnectAt,
  });

  const ControllerSnapshot.disconnected()
    : connectionState = ControllerConnectionState.disconnected,
      canRequestDispense = false,
      statusLabel = 'Controller disconnected',
      healthState = ControllerHealthState.disconnected,
      errorKind = null,
      lastSuccessfulHeartbeatAt = null,
      reconnectAttempt = 0,
      nextReconnectAt = null;

  const ControllerSnapshot.connected()
    : connectionState = ControllerConnectionState.connected,
      canRequestDispense = false,
      statusLabel = 'Controller connected; heartbeat not verified',
      healthState = ControllerHealthState.verifying,
      errorKind = null,
      lastSuccessfulHeartbeatAt = null,
      reconnectAttempt = 0,
      nextReconnectAt = null;

  const ControllerSnapshot.online()
    : connectionState = ControllerConnectionState.connected,
      canRequestDispense = true,
      statusLabel = 'Controller online',
      healthState = ControllerHealthState.online,
      errorKind = null,
      lastSuccessfulHeartbeatAt = null,
      reconnectAttempt = 0,
      nextReconnectAt = null;

  final ControllerConnectionState connectionState;
  final bool canRequestDispense;
  final String statusLabel;
  final ControllerHealthState healthState;
  final ControllerErrorKind? errorKind;
  final DateTime? lastSuccessfulHeartbeatAt;
  final int reconnectAttempt;
  final DateTime? nextReconnectAt;
}

abstract interface class ControllerGateway {
  Stream<ControllerSnapshot> watchController();

  Future<void> connect();

  Future<void> disconnect();

  /// Throws a typed exception so lifecycle code can distinguish between:
  /// - definite pre-accept failures (`ControllerCommandPreconditionException`,
  ///   `ControllerCommandRejectedException`, `ControllerTransportOfflineException`)
  /// - accepted or acceptance-ambiguous failures (`ControllerCommandTimeoutException`,
  ///   `ControllerCommandJamException`, `ControllerCommandInterruptedException`)
  Future<void> requestDispense({required String doseId});

  Future<void> cancelActiveCommand();

  Future<void> close();
}

enum ControllerDispenseStage { accepted, movementStarted }

enum ControllerMovementCommand { servoTest, dispenseTest, dispenseNext }

typedef ControllerDispenseStageCallback =
    Future<void> Function(ControllerDispenseStage stage);

abstract interface class StagedControllerGateway implements ControllerGateway {
  Future<void> requestStagedDispense({
    required String doseId,
    ControllerMovementCommand movement = ControllerMovementCommand.dispenseNext,
    required ControllerDispenseStageCallback onStage,
  });
}

enum ControllerBenchCommand {
  status,
  heartbeat,
  servoTest,
  dispenseTest,
  pirStatus,
  ledTest,
}

abstract interface class ControllerBenchGateway {
  Future<String> runBenchCommand(ControllerBenchCommand command);
}
