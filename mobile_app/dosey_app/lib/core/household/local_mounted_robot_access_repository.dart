import 'package:dosey_app/core/household/mounted_robot_access_gateway.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';

class CachedMountedRobotAccess {
  const CachedMountedRobotAccess({
    required this.robot,
    required this.confirmedAt,
  });

  final MountedRobotInstallation robot;
  final DateTime confirmedAt;
}

class LocalMountedRobotAccessRepository {
  const LocalMountedRobotAccessRepository(this._database);

  final DoseyDatabase _database;

  Future<CachedMountedRobotAccess?> readForAccount(String accountId) async {
    final query = _database.select(_database.cachedMountedRobotAccess)
      ..where((row) => row.accountId.equals(accountId));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return CachedMountedRobotAccess(
      robot: MountedRobotInstallation(
        robotId: row.robotId,
        displayName: row.displayName,
      ),
      confirmedAt: row.confirmedAt,
    );
  }

  Future<void> replaceForAccount(
    String accountId,
    MountedRobotInstallation robot, {
    required DateTime confirmedAt,
  }) {
    final normalizedAccountId = accountId.trim();
    if (normalizedAccountId.isEmpty) {
      throw ArgumentError.value(accountId, 'accountId');
    }
    return _database
        .into(_database.cachedMountedRobotAccess)
        .insertOnConflictUpdate(
          CachedMountedRobotAccessCompanion.insert(
            accountId: normalizedAccountId,
            robotId: robot.robotId,
            displayName: robot.displayName,
            confirmedAt: confirmedAt.toUtc(),
          ),
        );
  }

  Future<void> clearForAccount(String accountId) => (_database.delete(
    _database.cachedMountedRobotAccess,
  )..where((row) => row.accountId.equals(accountId))).go();
}
