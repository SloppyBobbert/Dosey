class CloudConfiguration {
  factory CloudConfiguration.fromValues({
    String? endpoint,
    String? projectId,
    String? databaseId,
    String? pairingClaimsTableId,
    String? pairingAttemptsTableId,
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
      databaseId: _normalize(databaseId),
      pairingClaimsTableId: _normalize(pairingClaimsTableId),
      pairingAttemptsTableId: _normalize(pairingAttemptsTableId),
      createPairingCodeFunctionId: _normalize(createPairingCodeFunctionId),
      claimRobotFunctionId: _normalize(claimRobotFunctionId),
    );
  }

  const CloudConfiguration._({
    this.endpoint,
    this.projectId,
    this.databaseId,
    this.pairingClaimsTableId,
    this.pairingAttemptsTableId,
    this.createPairingCodeFunctionId,
    this.claimRobotFunctionId,
  });

  static final fromEnvironment = CloudConfiguration.fromValues(
    endpoint: const String.fromEnvironment('APPWRITE_ENDPOINT'),
    projectId: const String.fromEnvironment('APPWRITE_PROJECT_ID'),
    databaseId: const String.fromEnvironment('APPWRITE_DATABASE_ID'),
    pairingClaimsTableId: const String.fromEnvironment(
      'APPWRITE_PAIRING_CLAIMS_TABLE_ID',
    ),
    pairingAttemptsTableId: const String.fromEnvironment(
      'APPWRITE_PAIRING_ATTEMPTS_TABLE_ID',
    ),
    createPairingCodeFunctionId: const String.fromEnvironment(
      'APPWRITE_CREATE_PAIRING_CODE_FUNCTION_ID',
    ),
    claimRobotFunctionId: const String.fromEnvironment(
      'APPWRITE_CLAIM_ROBOT_FUNCTION_ID',
    ),
  );

  final String? endpoint;
  final String? projectId;
  final String? databaseId;
  final String? pairingClaimsTableId;
  final String? pairingAttemptsTableId;
  final String? createPairingCodeFunctionId;
  final String? claimRobotFunctionId;

  bool get isEnabled => endpoint != null && projectId != null;
  bool get isPairingEnabled =>
      isEnabled &&
      databaseId != null &&
      pairingClaimsTableId != null &&
      pairingAttemptsTableId != null &&
      createPairingCodeFunctionId != null &&
      claimRobotFunctionId != null;

  static String? _normalize(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
