enum PairedRobotReadinessStatus {
  waitingForIdentity,
  identityMismatch,
  waitingForSync,
  ready,
}

class PairedRobotReadiness {
  const PairedRobotReadiness._({
    required this.status,
    required this.mountedDeviceId,
  });

  const PairedRobotReadiness.waitingForIdentity()
    : this._(
        status: PairedRobotReadinessStatus.waitingForIdentity,
        mountedDeviceId: null,
      );

  const PairedRobotReadiness.identityMismatch({required String mountedDeviceId})
    : this._(
        status: PairedRobotReadinessStatus.identityMismatch,
        mountedDeviceId: mountedDeviceId,
      );

  const PairedRobotReadiness.waitingForSync({required String mountedDeviceId})
    : this._(
        status: PairedRobotReadinessStatus.waitingForSync,
        mountedDeviceId: mountedDeviceId,
      );

  const PairedRobotReadiness.ready({required String mountedDeviceId})
    : this._(
        status: PairedRobotReadinessStatus.ready,
        mountedDeviceId: mountedDeviceId,
      );

  final PairedRobotReadinessStatus status;
  final String? mountedDeviceId;
}

abstract interface class PairedRobotReadinessGateway {
  bool get isAvailable;

  Future<PairedRobotReadiness> verify({
    required String robotId,
    required String localDeviceId,
  });
}

class DisabledPairedRobotReadinessGateway
    implements PairedRobotReadinessGateway {
  const DisabledPairedRobotReadinessGateway();

  @override
  bool get isAvailable => false;

  @override
  Future<PairedRobotReadiness> verify({
    required String robotId,
    required String localDeviceId,
  }) async => const PairedRobotReadiness.waitingForIdentity();
}
