import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:dosey_app/core/household/household_sync_gateway.dart';
import 'package:dosey_app/core/household/robot_installation.dart';

abstract interface class AppwriteTeamsApi {
  // This seam contains Appwrite's Team representation so household consumers
  // remain independent of the selected cloud provider.
  Future<List<RobotInstallation>> listRobotTeams();

  Future<RobotInstallation> createRobotTeam({
    required String displayName,
    required String ownerAccountId,
    required String mountedDeviceId,
  });
}

class AppwriteTeamsApiAdapter implements AppwriteTeamsApi {
  AppwriteTeamsApiAdapter(this._teams);

  static const _schemaVersion = 1;
  static const _robotMarkerKey = 'doseyRobot';
  static const _schemaVersionKey = 'doseySchemaVersion';
  static const _ownerAccountIdKey = 'ownerAccountId';
  static const _mountedDeviceIdKey = 'mountedDeviceId';

  final Teams _teams;

  @override
  Future<List<RobotInstallation>> listRobotTeams() async {
    final result = await _teams.list();
    final robots = <RobotInstallation>[];
    for (final team in result.teams) {
      if (team.prefs.data[_robotMarkerKey] != true) continue;
      robots.add(await _toRobotInstallation(team));
    }
    return robots;
  }

  @override
  Future<RobotInstallation> createRobotTeam({
    required String displayName,
    required String ownerAccountId,
    required String mountedDeviceId,
  }) async {
    final team = await _teams.create(teamId: ID.unique(), name: displayName);
    try {
      await _teams.updatePrefs(
        teamId: team.$id,
        prefs: {
          _robotMarkerKey: true,
          _schemaVersionKey: _schemaVersion,
          _ownerAccountIdKey: ownerAccountId,
          _mountedDeviceIdKey: mountedDeviceId,
        },
      );
    } catch (_) {
      try {
        await _teams.delete(teamId: team.$id);
      } catch (_) {
        // Preserve the setup failure; a later restore ignores an unmarked team.
      }
      rethrow;
    }

    return RobotInstallation(
      id: team.$id,
      displayName: team.name,
      ownerAccountId: ownerAccountId,
      humanAccountIds: {ownerAccountId},
      mountedDeviceId: mountedDeviceId,
    );
  }

  Future<RobotInstallation> _toRobotInstallation(models.Team team) async {
    final ownerAccountId = team.prefs.data[_ownerAccountIdKey];
    final mountedDeviceId = team.prefs.data[_mountedDeviceIdKey];
    if (ownerAccountId is! String || mountedDeviceId is! String) {
      throw StateError('Dosey robot team ${team.$id} has invalid preferences.');
    }

    final memberships = await _teams.listMemberships(teamId: team.$id);
    final acceptedHumanIds = acceptedHumanAccountIds(
      memberships.memberships,
      mountedDeviceId: mountedDeviceId,
    );
    return RobotInstallation(
      id: team.$id,
      displayName: team.name,
      ownerAccountId: ownerAccountId,
      humanAccountIds: acceptedHumanIds,
      mountedDeviceId: mountedDeviceId,
    );
  }
}

Set<String> acceptedHumanAccountIds(
  Iterable<models.Membership> memberships, {
  required String mountedDeviceId,
}) => memberships
    .where(
      (membership) =>
          membership.confirm &&
          membership.userId != mountedDeviceId &&
          !(membership.roles.length == 1 &&
              membership.roles.single == 'robot-device'),
    )
    .map((membership) => membership.userId)
    .toSet();

class AppwriteHouseholdSyncGateway implements HouseholdSyncGateway {
  AppwriteHouseholdSyncGateway(this._teams);

  final AppwriteTeamsApi _teams;
  final StreamController<RobotInstallation?> _changes =
      StreamController<RobotInstallation?>.broadcast();
  Future<RobotInstallation>? _createInFlight;
  var _revision = 0;

  @override
  Stream<RobotInstallation?> watchRobot() {
    return Stream.multi((listener) {
      final startingRevision = _revision;
      final subscription = _changes.stream.listen(
        listener.add,
        onError: listener.addError,
      );
      listener.onCancel = subscription.cancel;

      unawaited(() async {
        try {
          final robot = await _restoreRobot();
          if (_revision == startingRevision) listener.add(robot);
        } catch (error, stackTrace) {
          if (_revision == startingRevision) {
            listener.addError(error, stackTrace);
          }
        }
      }());
    });
  }

  @override
  Future<RobotInstallation?> refreshRobot() async {
    final robot = await _restoreRobot();
    _revision += 1;
    _changes.add(robot);
    return robot;
  }

  @override
  Future<RobotInstallation> createRobot({
    required String displayName,
    required String ownerAccountId,
    required String mountedDeviceId,
  }) {
    return _createInFlight ??= _createRobot(
      displayName: displayName,
      ownerAccountId: ownerAccountId,
      mountedDeviceId: mountedDeviceId,
    ).whenComplete(() => _createInFlight = null);
  }

  Future<RobotInstallation> _createRobot({
    required String displayName,
    required String ownerAccountId,
    required String mountedDeviceId,
  }) async {
    if (await _restoreRobot() != null) {
      throw const RobotAlreadyExistsException();
    }
    final robot = await _teams.createRobotTeam(
      displayName: displayName,
      ownerAccountId: ownerAccountId,
      mountedDeviceId: mountedDeviceId,
    );
    _revision += 1;
    _changes.add(robot);
    return robot;
  }

  Future<RobotInstallation?> _restoreRobot() async {
    final robots = await _teams.listRobotTeams();
    if (robots.length > 1) {
      throw StateError('This account belongs to multiple Dosey robots.');
    }
    return robots.firstOrNull;
  }
}

class RobotAlreadyExistsException implements Exception {
  const RobotAlreadyExistsException();

  @override
  String toString() => 'This account already belongs to a Dosey robot.';
}
