import 'package:dosey_app/core/household/robot_installation.dart';

class HouseholdInvitationCredential {
  const HouseholdInvitationCredential({
    required this.code,
    required this.expiresAt,
  });

  final String code;
  final DateTime expiresAt;
}

enum HouseholdManagementFailureReason {
  alreadyLinked,
  householdFull,
  invalidInvitation,
  invitationExpired,
  emailMismatch,
  ownerRequired,
  ownerCannotLeave,
  memberNotFound,
  authenticationRequired,
  invalidRequest,
  cloudNotConfigured,
  functionFailure,
}

class HouseholdManagementException implements Exception {
  const HouseholdManagementException(this.reason);

  final HouseholdManagementFailureReason reason;
}

abstract interface class HouseholdManagementGateway {
  bool get isAvailable;

  Future<RobotInstallation> createRobot(String displayName);

  Future<HouseholdInvitationCredential> createInvitation(
    String robotId,
    String email,
  );

  Future<RobotInstallation> acceptInvitation(String code);

  Future<RobotInstallation> removeMember(String robotId, String accountId);

  Future<void> leaveRobot(String robotId);
}

class DisabledHouseholdManagementGateway implements HouseholdManagementGateway {
  const DisabledHouseholdManagementGateway();

  @override
  bool get isAvailable => false;

  @override
  Future<RobotInstallation> createRobot(String displayName) => _unavailable();

  @override
  Future<HouseholdInvitationCredential> createInvitation(
    String robotId,
    String email,
  ) => _unavailable();

  @override
  Future<RobotInstallation> acceptInvitation(String code) => _unavailable();

  @override
  Future<RobotInstallation> removeMember(String robotId, String accountId) =>
      _unavailable();

  @override
  Future<void> leaveRobot(String robotId) => _unavailable();

  Future<T> _unavailable<T>() => Future.error(
    const HouseholdManagementException(
      HouseholdManagementFailureReason.cloudNotConfigured,
    ),
  );
}
