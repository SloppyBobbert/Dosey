class RobotInstallation {
  factory RobotInstallation({
    required String id,
    required String displayName,
    required String ownerAccountId,
    required Set<String> humanAccountIds,
    required String mountedDeviceId,
  }) {
    if (humanAccountIds.isEmpty || !humanAccountIds.contains(ownerAccountId)) {
      throw ArgumentError(
        'The robot owner must be an accepted human member.',
        'humanAccountIds',
      );
    }
    if (humanAccountIds.length > maxHumanAccounts) {
      throw ArgumentError(
        'A robot supports at most $maxHumanAccounts human accounts.',
        'humanAccountIds',
      );
    }
    if (humanAccountIds.contains(mountedDeviceId)) {
      throw ArgumentError(
        'The mounted robot identity cannot be a human member.',
        'mountedDeviceId',
      );
    }
    return RobotInstallation._(
      id: id,
      displayName: displayName,
      ownerAccountId: ownerAccountId,
      humanAccountIds: Set.unmodifiable(humanAccountIds),
      mountedDeviceId: mountedDeviceId,
    );
  }

  const RobotInstallation._({
    required this.id,
    required this.displayName,
    required this.ownerAccountId,
    required this.humanAccountIds,
    required this.mountedDeviceId,
  });

  static const maxHumanAccounts = 7;

  final String id;
  final String displayName;
  final String ownerAccountId;
  final Set<String> humanAccountIds;
  final String mountedDeviceId;

  int get humanAccountCount => humanAccountIds.length;
  bool get isSinglePerson => humanAccountCount == 1;
}
