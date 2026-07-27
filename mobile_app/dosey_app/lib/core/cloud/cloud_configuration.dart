class CloudConfiguration {
  factory CloudConfiguration.fromValues({
    String? endpoint,
    String? projectId,
    String? createPairingCodeFunctionId,
    String? claimRobotFunctionId,
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
    );
  }

  const CloudConfiguration._({
    this.endpoint,
    this.projectId,
    this.createPairingCodeFunctionId,
    this.claimRobotFunctionId,
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
  );

  final String? endpoint;
  final String? projectId;
  final String? createPairingCodeFunctionId;
  final String? claimRobotFunctionId;

  bool get isEnabled => endpoint != null && projectId != null;
  bool get isPairingEnabled =>
      isEnabled &&
      createPairingCodeFunctionId != null &&
      claimRobotFunctionId != null;

  static String? _normalize(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
