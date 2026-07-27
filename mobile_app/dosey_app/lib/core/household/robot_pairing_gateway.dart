class RobotPairingCredential {
  const RobotPairingCredential({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;
}

enum RobotPairingFailureReason {
  invalidCode,
  missingSession,
  consumedCode,
  expiredCode,
  blockedDevice,
  functionFailure,
}

class RobotPairingException implements Exception {
  const RobotPairingException(this.reason);

  final RobotPairingFailureReason reason;
}

abstract interface class RobotPairingGateway {
  Future<RobotPairingCredential> createPairingCode({required String robotId});

  Future<String> claimRobot({required String code});
}

class DisabledRobotPairingGateway implements RobotPairingGateway {
  const DisabledRobotPairingGateway();

  @override
  Future<RobotPairingCredential> createPairingCode({required String robotId}) =>
      Future.error(
        const RobotPairingException(RobotPairingFailureReason.functionFailure),
      );

  @override
  Future<String> claimRobot({required String code}) => Future.error(
    const RobotPairingException(RobotPairingFailureReason.functionFailure),
  );
}
