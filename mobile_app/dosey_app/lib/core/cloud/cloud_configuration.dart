class CloudConfiguration {
  factory CloudConfiguration.fromValues({
    String? endpoint,
    String? projectId,
    String? createPairingCodeFunctionId,
    String? claimRobotFunctionId,
    String? createRobotFunctionId,
    String? createHouseholdInvitationFunctionId,
    String? acceptHouseholdInvitationFunctionId,
    String? removeHouseholdMemberFunctionId,
    String? getMountedRobotFunctionId,
  }) {
    final normalizedEndpoint = _normalize(endpoint);
    final normalizedProjectId = _normalize(projectId);
    if ((normalizedEndpoint == null) != (normalizedProjectId == null)) {
      throw ArgumentError(
        'Appwrite endpoint and project ID must be configured together.',
      );
    }
    return CloudConfiguration._(
      endpoint: normalizedEndpoint,
      projectId: normalizedProjectId,
      createPairingCodeFunctionId: _normalize(createPairingCodeFunctionId),
      claimRobotFunctionId: _normalize(claimRobotFunctionId),
      createRobotFunctionId: _normalize(createRobotFunctionId),
      createHouseholdInvitationFunctionId: _normalize(
        createHouseholdInvitationFunctionId,
      ),
      acceptHouseholdInvitationFunctionId: _normalize(
        acceptHouseholdInvitationFunctionId,
      ),
      removeHouseholdMemberFunctionId: _normalize(
        removeHouseholdMemberFunctionId,
      ),
      getMountedRobotFunctionId: _normalize(getMountedRobotFunctionId),
    );
  }

  const CloudConfiguration._({
    this.endpoint,
    this.projectId,
    this.createPairingCodeFunctionId,
    this.claimRobotFunctionId,
    this.createRobotFunctionId,
    this.createHouseholdInvitationFunctionId,
    this.acceptHouseholdInvitationFunctionId,
    this.removeHouseholdMemberFunctionId,
    this.getMountedRobotFunctionId,
  });

  static final fromEnvironment = CloudConfiguration.fromValues(
    endpoint: const String.fromEnvironment('APPWRITE_ENDPOINT'),
    projectId: const String.fromEnvironment('APPWRITE_PROJECT_ID'),
    createPairingCodeFunctionId: const String.fromEnvironment(
      'APPWRITE_CREATE_PAIRING_CODE_FUNCTION_ID',
    ),
    claimRobotFunctionId: const String.fromEnvironment(
      'APPWRITE_CLAIM_ROBOT_FUNCTION_ID',
    ),
    createRobotFunctionId: const String.fromEnvironment(
      'APPWRITE_CREATE_ROBOT_FUNCTION_ID',
    ),
    createHouseholdInvitationFunctionId: const String.fromEnvironment(
      'APPWRITE_CREATE_HOUSEHOLD_INVITATION_FUNCTION_ID',
    ),
    acceptHouseholdInvitationFunctionId: const String.fromEnvironment(
      'APPWRITE_ACCEPT_HOUSEHOLD_INVITATION_FUNCTION_ID',
    ),
    removeHouseholdMemberFunctionId: const String.fromEnvironment(
      'APPWRITE_REMOVE_HOUSEHOLD_MEMBER_FUNCTION_ID',
    ),
    getMountedRobotFunctionId: const String.fromEnvironment(
      'APPWRITE_GET_MOUNTED_ROBOT_FUNCTION_ID',
    ),
  );

  final String? endpoint;
  final String? projectId;
  final String? createPairingCodeFunctionId;
  final String? claimRobotFunctionId;
  final String? createRobotFunctionId;
  final String? createHouseholdInvitationFunctionId;
  final String? acceptHouseholdInvitationFunctionId;
  final String? removeHouseholdMemberFunctionId;
  final String? getMountedRobotFunctionId;

  bool get isEnabled => endpoint != null && projectId != null;
  bool get isPersonalPairingEnabled =>
      isEnabled &&
      createPairingCodeFunctionId != null &&
      claimRobotFunctionId != null;
  bool get isRobotClaimEnabled =>
      isEnabled &&
      claimRobotFunctionId != null &&
      getMountedRobotFunctionId != null;
  bool get isHouseholdManagementEnabled =>
      isEnabled &&
      createRobotFunctionId != null &&
      createHouseholdInvitationFunctionId != null &&
      acceptHouseholdInvitationFunctionId != null &&
      removeHouseholdMemberFunctionId != null;
  bool get isMountedRobotAccessEnabled =>
      isEnabled && getMountedRobotFunctionId != null;

  static String? _normalize(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
