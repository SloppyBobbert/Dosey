enum HouseholdRole { owner, member }

class HouseholdMember {
  const HouseholdMember({
    required this.accountId,
    required this.label,
    required this.role,
  });

  final String accountId;
  final String label;
  final HouseholdRole role;
}

class RobotInstallation {
  factory RobotInstallation({
    required String id,
    required String displayName,
    required String ownerAccountId,
    required List<HouseholdMember> members,
    required HouseholdRole currentRole,
    required String? mountedDeviceId,
  }) {
    final memberIds = members.map((member) => member.accountId).toSet();
    final owners = members.where(
      (member) => member.role == HouseholdRole.owner,
    );
    if (members.isEmpty ||
        memberIds.length != members.length ||
        owners.length != 1 ||
        owners.single.accountId != ownerAccountId) {
      throw ArgumentError(
        'The robot owner must be an accepted human member.',
        'members',
      );
    }
    if (members.length > maxHumanAccounts) {
      throw ArgumentError(
        'A robot supports at most $maxHumanAccounts human accounts.',
        'members',
      );
    }
    if (mountedDeviceId != null && memberIds.contains(mountedDeviceId)) {
      throw ArgumentError(
        'The mounted robot identity cannot be a human member.',
        'mountedDeviceId',
      );
    }
    return RobotInstallation._(
      id: id,
      displayName: displayName,
      ownerAccountId: ownerAccountId,
      members: List.unmodifiable(members),
      currentRole: currentRole,
      mountedDeviceId: mountedDeviceId,
    );
  }

  const RobotInstallation._({
    required this.id,
    required this.displayName,
    required this.ownerAccountId,
    required this.members,
    required this.currentRole,
    required this.mountedDeviceId,
  });

  static const maxHumanAccounts = 7;

  final String id;
  final String displayName;
  final String ownerAccountId;
  final List<HouseholdMember> members;
  final HouseholdRole currentRole;
  final String? mountedDeviceId;

  Set<String> get humanAccountIds =>
      Set.unmodifiable(members.map((member) => member.accountId));
  int get humanAccountCount => members.length;
  bool get isSinglePerson => humanAccountCount == 1;
  bool get isCurrentAccountOwner => currentRole == HouseholdRole.owner;
}
