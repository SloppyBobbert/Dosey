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
    String? medicationSyncPushFunctionId,
    String? medicationSyncPullFunctionId,
    String? getMountedRobotFunctionId,
    bool caregiverSyncEnabled = false,
  }) {
    final normalizedEndpoint = _normalize(endpoint);
    final normalizedProjectId = _normalize(projectId);
    if ((normalizedEndpoint == null) != (normalizedProjectId == null)) {
      throw ArgumentError(
        'Appwrite endpoint and project ID must be configured together.',
      );
    }
    final functionIds = [
      createPairingCodeFunctionId,
      claimRobotFunctionId,
      createRobotFunctionId,
      createHouseholdInvitationFunctionId,
      acceptHouseholdInvitationFunctionId,
      removeHouseholdMemberFunctionId,
      medicationSyncPushFunctionId,
      medicationSyncPullFunctionId,
      getMountedRobotFunctionId,
    ];
    if (normalizedEndpoint == null &&
        functionIds.any((value) => _normalize(value) != null)) {
      throw ArgumentError(
        'Appwrite Function IDs require endpoint and project ID.',
      );
    }
    if (normalizedEndpoint != null && !_isValidEndpoint(normalizedEndpoint)) {
      throw ArgumentError('Appwrite endpoint must be a valid HTTPS /v1 URL.');
    }
    if (normalizedProjectId != null &&
        !_projectId.hasMatch(normalizedProjectId)) {
      throw ArgumentError('Appwrite project ID is invalid.');
    }
    for (final value in [
      normalizedProjectId,
      _normalize(createPairingCodeFunctionId),
      _normalize(claimRobotFunctionId),
      _normalize(createRobotFunctionId),
      _normalize(createHouseholdInvitationFunctionId),
      _normalize(acceptHouseholdInvitationFunctionId),
      _normalize(removeHouseholdMemberFunctionId),
      _normalize(medicationSyncPushFunctionId),
      _normalize(medicationSyncPullFunctionId),
      _normalize(getMountedRobotFunctionId),
    ]) {
      if (value != null && !_identifier.hasMatch(value)) {
        throw ArgumentError('Appwrite public identifiers are invalid.');
      }
    }
    _requireCompleteGroup([createPairingCodeFunctionId, claimRobotFunctionId]);
    _requireCompleteGroup([
      createRobotFunctionId,
      createHouseholdInvitationFunctionId,
      acceptHouseholdInvitationFunctionId,
      removeHouseholdMemberFunctionId,
    ]);
    _requireCompleteGroup([
      medicationSyncPushFunctionId,
      medicationSyncPullFunctionId,
    ]);
    if (caregiverSyncEnabled &&
        (_normalize(medicationSyncPushFunctionId) == null ||
            _normalize(medicationSyncPullFunctionId) == null)) {
      throw ArgumentError(
        'Caregiver sync requires both medication sync Function IDs.',
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
      medicationSyncPushFunctionId: _normalize(medicationSyncPushFunctionId),
      medicationSyncPullFunctionId: _normalize(medicationSyncPullFunctionId),
      getMountedRobotFunctionId: _normalize(getMountedRobotFunctionId),
      caregiverSyncEnabled: caregiverSyncEnabled,
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
    this.medicationSyncPushFunctionId,
    this.medicationSyncPullFunctionId,
    this.getMountedRobotFunctionId,
    this.caregiverSyncEnabled = false,
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
    medicationSyncPushFunctionId: const String.fromEnvironment(
      'APPWRITE_MEDICATION_SYNC_PUSH_FUNCTION_ID',
    ),
    medicationSyncPullFunctionId: const String.fromEnvironment(
      'APPWRITE_MEDICATION_SYNC_PULL_FUNCTION_ID',
    ),
    getMountedRobotFunctionId: const String.fromEnvironment(
      'APPWRITE_GET_MOUNTED_ROBOT_FUNCTION_ID',
    ),
    caregiverSyncEnabled: const bool.fromEnvironment('CAREGIVER_SYNC_ENABLED'),
  );

  final String? endpoint;
  final String? projectId;
  final String? createPairingCodeFunctionId;
  final String? claimRobotFunctionId;
  final String? createRobotFunctionId;
  final String? createHouseholdInvitationFunctionId;
  final String? acceptHouseholdInvitationFunctionId;
  final String? removeHouseholdMemberFunctionId;
  final String? medicationSyncPushFunctionId;
  final String? medicationSyncPullFunctionId;
  final String? getMountedRobotFunctionId;
  final bool caregiverSyncEnabled;

  bool get isEnabled => endpoint != null && projectId != null;
  bool get isPairingEnabled =>
      isEnabled &&
      createPairingCodeFunctionId != null &&
      claimRobotFunctionId != null;
  bool get isHouseholdManagementEnabled =>
      isEnabled &&
      createRobotFunctionId != null &&
      createHouseholdInvitationFunctionId != null &&
      acceptHouseholdInvitationFunctionId != null &&
      removeHouseholdMemberFunctionId != null;
  bool get isMedicationSyncEnabled =>
      caregiverSyncEnabled &&
      isEnabled &&
      medicationSyncPushFunctionId != null &&
      medicationSyncPullFunctionId != null;

  static String? _normalize(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value.trim() != value) {
      throw ArgumentError('Appwrite values cannot contain whitespace.');
    }
    return value;
  }

  static void _requireCompleteGroup(List<String?> group) {
    final values = group.map(_normalize).toList();
    final present = values.whereType<String>().length;
    if (present != 0 && present != values.length) {
      throw ArgumentError(
        'Appwrite Function groups must be configured completely.',
      );
    }
  }

  static final _identifier = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$');
  static final _projectId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9.-]{0,63}$');

  static bool _isValidEndpoint(String endpoint) {
    if (RegExp(r'^https://[^/?#]*(@|:[0-9]+/)').hasMatch(endpoint)) {
      return false;
    }
    final uri = Uri.tryParse(endpoint);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasPort &&
        !uri.authority.split('@').last.contains(':') &&
        uri.host == uri.host.toLowerCase() &&
        uri.path == '/v1' &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }
}
