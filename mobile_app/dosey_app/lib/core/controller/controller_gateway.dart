enum ControllerConnectionState { disconnected, scanning, connected, error }

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

  final ControllerConnectionState connectionState;
  final bool canRequestDispense;
  final String statusLabel;
}

abstract interface class ControllerGateway {
  Stream<ControllerSnapshot> watchController();

  Future<void> connect();

  Future<void> cancelActiveCommand();
}
