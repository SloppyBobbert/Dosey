enum ControllerConnectionState { disconnected, scanning, connected, error }

class ControllerCommandRejectedException implements Exception {
  const ControllerCommandRejectedException([
    this.message = 'Controller rejected command.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class ControllerCommandPreconditionException implements Exception {
  const ControllerCommandPreconditionException([
    this.message = 'Controller cannot accept this command yet.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class ControllerTransportOfflineException implements Exception {
  const ControllerTransportOfflineException([
    this.message = 'Controller transport is offline.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class ControllerCommandTimeoutException implements Exception {
  const ControllerCommandTimeoutException([
    this.message = 'Controller command timed out after acceptance.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class ControllerCommandJamException implements Exception {
  const ControllerCommandJamException([
    this.message = 'Controller reported a jam after acceptance.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class ControllerCommandInterruptedException implements Exception {
  const ControllerCommandInterruptedException([
    this.message =
        'Controller connection was lost after the command may have been accepted.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class ControllerSnapshot {
  const ControllerSnapshot({
    required this.connectionState,
    required this.canRequestDispense,
    required this.statusLabel,
  });

  const ControllerSnapshot.disconnected()
    : connectionState = ControllerConnectionState.disconnected,
      canRequestDispense = false,
      statusLabel = 'Controller disconnected';

  const ControllerSnapshot.connected()
    : connectionState = ControllerConnectionState.connected,
      canRequestDispense = true,
      statusLabel = 'Controller connected';

  final ControllerConnectionState connectionState;
  final bool canRequestDispense;
  final String statusLabel;
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
