class CloudConfiguration {
  factory CloudConfiguration.fromValues({String? endpoint, String? projectId}) {
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
    );
  }

  const CloudConfiguration._({this.endpoint, this.projectId});

  static final fromEnvironment = CloudConfiguration.fromValues(
    endpoint: const String.fromEnvironment('APPWRITE_ENDPOINT'),
    projectId: const String.fromEnvironment('APPWRITE_PROJECT_ID'),
  );

  final String? endpoint;
  final String? projectId;

  bool get isEnabled => endpoint != null && projectId != null;

  static String? _normalize(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
