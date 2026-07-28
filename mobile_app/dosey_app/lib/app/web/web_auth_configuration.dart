class WebAuthConfiguration {
  const WebAuthConfiguration._({
    required this.enabled,
    required this.isStaging,
    this.appOrigin,
    this.endpoint,
    this.projectId,
  });

  factory WebAuthConfiguration.fromValues({
    required bool enabled,
    String? appOrigin,
    String? endpoint,
    String? projectId,
  }) {
    if (!enabled) {
      return const WebAuthConfiguration._(enabled: false, isStaging: false);
    }

    final origin = _normalizeOrigin(appOrigin);
    final normalizedEndpoint = _normalizeEndpoint(endpoint);
    final normalizedProjectId = projectId?.trim();
    if (origin == null ||
        normalizedEndpoint == null ||
        normalizedProjectId == null ||
        normalizedProjectId.isEmpty) {
      throw ArgumentError(
        'Enabled web auth needs a valid origin, endpoint, and project ID.',
      );
    }
    return WebAuthConfiguration._(
      enabled: true,
      isStaging: origin == 'https://staging.dosey.dev',
      appOrigin: origin,
      endpoint: normalizedEndpoint,
      projectId: normalizedProjectId,
    );
  }

  static WebAuthConfiguration get fromEnvironment =>
      WebAuthConfiguration.fromValues(
        enabled: parseAuthEnabled(
          const String.fromEnvironment('WEB_AUTH_ENABLED'),
        ),
        appOrigin: const String.fromEnvironment('WEB_APP_ORIGIN'),
        endpoint: const String.fromEnvironment('APPWRITE_ENDPOINT'),
        projectId: const String.fromEnvironment('APPWRITE_PROJECT_ID'),
      );

  final bool enabled;
  final bool isStaging;
  final String? appOrigin;
  final String? endpoint;
  final String? projectId;

  Uri get oauthSuccess => _callback('success');
  Uri get oauthFailure => _callback('failure');

  Uri _callback(String result) => Uri.parse(appOrigin!).replace(
    path: '/auth.html',
    queryParameters: <String, String>{'result': result},
  );

  static bool parseAuthEnabled(String value) {
    if (value.isEmpty || value == 'false') return false;
    if (value == 'true') return true;
    throw ArgumentError(
      'WEB_AUTH_ENABLED must be exactly true or false when provided.',
    );
  }

  static String? _normalizeOrigin(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        uri.path.isNotEmpty && uri.path != '/') {
      return null;
    }
    final isLocalhost =
        uri.scheme == 'http' &&
        (uri.host == 'localhost' ||
            uri.host == '127.0.0.1' ||
            uri.host == '::1');
    if (uri.scheme != 'https' && !isLocalhost ||
        uri.host.isEmpty ||
        uri.hasPort && uri.port == 0) {
      return null;
    }
    final port = uri.hasPort ? ':${uri.port}' : '';
    final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
    return '${uri.scheme}://$host$port';
  }

  static String? _normalizeEndpoint(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    final isLocalhost =
        uri != null &&
        uri.scheme == 'http' &&
        (uri.host == 'localhost' ||
            uri.host == '127.0.0.1' ||
            uri.host == '::1');
    if (uri == null ||
        uri.scheme != 'https' && !isLocalhost ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      return null;
    }
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }
}
