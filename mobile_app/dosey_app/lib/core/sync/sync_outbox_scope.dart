final class SyncOutboxScope {
  SyncOutboxScope({required String actorAccountId, required String robotId})
    : actorAccountId = _validate(actorAccountId, 'actorAccountId'),
      robotId = _validate(robotId, 'robotId');

  final String actorAccountId;
  final String robotId;

  static String _validate(String value, String name) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > 128) {
      throw ArgumentError.value(value, name);
    }
    return normalized;
  }
}
