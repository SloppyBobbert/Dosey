import 'package:dosey_app/core/household/robot_installation.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';

class CachedRobotInstallation {
  const CachedRobotInstallation({
    required this.installation,
    required this.confirmedAt,
  });

  final RobotInstallation installation;
  final DateTime confirmedAt;
}

class LocalHouseholdCacheRepository {
  const LocalHouseholdCacheRepository(this._database);

  final DoseyDatabase _database;

  Future<CachedRobotInstallation?> readForAccount(String accountId) async {
    final installationQuery = _database.select(
      _database.cachedRobotInstallations,
    )..where((row) => row.accountId.equals(accountId));
    final installationRow = await installationQuery.getSingleOrNull();
    if (installationRow == null) return null;

    final memberQuery = _database.select(_database.cachedHouseholdMembers)
      ..where((row) => row.accountId.equals(accountId))
      ..orderBy([(row) => OrderingTerm.asc(row.position)]);
    final memberRows = await memberQuery.get();

    return CachedRobotInstallation(
      installation: RobotInstallation(
        id: installationRow.robotId,
        displayName: installationRow.displayName,
        ownerAccountId: installationRow.ownerAccountId,
        members: [
          for (final row in memberRows)
            HouseholdMember(
              accountId: row.memberAccountId,
              label: row.label,
              role: HouseholdRole.values.byName(row.role),
            ),
        ],
        currentRole: HouseholdRole.values.byName(installationRow.currentRole),
        mountedDeviceId: installationRow.mountedDeviceId,
      ),
      confirmedAt: installationRow.confirmedAt,
    );
  }

  Future<void> replaceForAccount(
    String accountId,
    RobotInstallation installation, {
    required DateTime confirmedAt,
  }) {
    final normalizedAccountId = accountId.trim();
    final currentMember = installation.members
        .where((member) => member.accountId == normalizedAccountId)
        .firstOrNull;
    if (normalizedAccountId.isEmpty ||
        currentMember == null ||
        currentMember.role != installation.currentRole) {
      throw ArgumentError.value(
        accountId,
        'accountId',
        'The cached account must be an accepted member with its current role.',
      );
    }

    return _database.transaction(() async {
      await _database
          .into(_database.cachedRobotInstallations)
          .insertOnConflictUpdate(
            CachedRobotInstallationsCompanion.insert(
              accountId: normalizedAccountId,
              robotId: installation.id,
              displayName: installation.displayName,
              ownerAccountId: installation.ownerAccountId,
              currentRole: installation.currentRole.name,
              mountedDeviceId: Value(installation.mountedDeviceId),
              confirmedAt: confirmedAt.toUtc(),
            ),
          );
      await (_database.delete(
        _database.cachedHouseholdMembers,
      )..where((row) => row.accountId.equals(normalizedAccountId))).go();
      await _database.batch((batch) {
        batch.insertAll(_database.cachedHouseholdMembers, [
          for (final (position, member) in installation.members.indexed)
            CachedHouseholdMembersCompanion.insert(
              accountId: normalizedAccountId,
              memberAccountId: member.accountId,
              label: member.label,
              role: member.role.name,
              position: position,
            ),
        ]);
      });
    });
  }

  Future<void> clearForAccount(String accountId) {
    return _database.transaction(() async {
      await (_database.delete(
        _database.cachedHouseholdMembers,
      )..where((row) => row.accountId.equals(accountId))).go();
      await (_database.delete(
        _database.cachedRobotInstallations,
      )..where((row) => row.accountId.equals(accountId))).go();
    });
  }
}
