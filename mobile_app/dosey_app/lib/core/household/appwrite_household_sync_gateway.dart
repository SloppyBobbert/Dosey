import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:dosey_app/core/household/household_sync_gateway.dart';
import 'package:dosey_app/core/household/robot_installation.dart';

abstract interface class AppwriteTeamsApi {
  // This seam contains Appwrite's Team representation so household consumers
  // remain independent of the selected cloud provider.
  Future<List<RobotInstallation>> listRobotTeams();
}

class AppwriteTeamsApiAdapter implements AppwriteTeamsApi {
  AppwriteTeamsApiAdapter(this._teams, this._account);

  static const _robotMarkerKey = 'doseyRobot';
  static const _ownerAccountIdKey = 'ownerAccountId';
  static const _mountedDeviceIdKey = 'mountedDeviceId';

  final Teams _teams;
  final Account _account;

  @override
  Future<List<RobotInstallation>> listRobotTeams() async {
    final currentAccountId = (await _account.get()).$id;
    final result = await _teams.list();
    final robots = <RobotInstallation>[];
    for (final team in result.teams) {
      if (team.prefs.data[_robotMarkerKey] != true) continue;
      robots.add(await _toRobotInstallation(team, currentAccountId));
    }
    return robots;
  }

  Future<RobotInstallation> _toRobotInstallation(
    models.Team team,
    String currentAccountId,
  ) async {
    final ownerAccountId = team.prefs.data[_ownerAccountIdKey];
    final mountedDeviceId = team.prefs.data[_mountedDeviceIdKey];
    if (ownerAccountId is! String ||
        (mountedDeviceId != null && mountedDeviceId is! String)) {
      throw StateError('Dosey robot team ${team.$id} has invalid preferences.');
    }

    final memberships = await _teams.listMemberships(teamId: team.$id);
    final members = acceptedHouseholdMembers(
      memberships.memberships,
      mountedDeviceId: mountedDeviceId,
    );
    final currentMember = members
        .where((member) => member.accountId == currentAccountId)
        .firstOrNull;
    if (currentMember == null) {
      throw StateError('The current account is not an accepted human member.');
    }
    return RobotInstallation(
      id: team.$id,
      displayName: team.name,
      ownerAccountId: ownerAccountId,
      members: members,
      currentRole: currentMember.role,
      mountedDeviceId: mountedDeviceId,
    );
  }
}

Set<String> acceptedHumanAccountIds(
  Iterable<models.Membership> memberships, {
  required String? mountedDeviceId,
}) => acceptedHouseholdMembers(
  memberships,
  mountedDeviceId: mountedDeviceId,
).map((member) => member.accountId).toSet();

List<HouseholdMember> acceptedHouseholdMembers(
  Iterable<models.Membership> memberships, {
  required String? mountedDeviceId,
}) => memberships
    .where(
      (membership) =>
          membership.confirm &&
          membership.userId != mountedDeviceId &&
          !(membership.roles.length == 1 &&
              membership.roles.single == 'robot-device'),
    )
    .map((membership) {
      final role = membership.roles.contains('owner')
          ? HouseholdRole.owner
          : membership.roles.contains('member')
          ? HouseholdRole.member
          : null;
      if (role == null) return null;
      final name = membership.userName.trim();
      final email = membership.userEmail.trim();
      return HouseholdMember(
        accountId: membership.userId,
        label: name.isNotEmpty
            ? name
            : email.isNotEmpty
            ? email
            : membership.userId,
        role: role,
      );
    })
    .nonNulls
    .toList(growable: false);

class AppwriteHouseholdSyncGateway implements HouseholdSyncGateway {
  AppwriteHouseholdSyncGateway(this._teams);

  final AppwriteTeamsApi _teams;
  final StreamController<RobotInstallation?> _changes =
      StreamController<RobotInstallation?>.broadcast();
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

  Future<RobotInstallation?> _restoreRobot() async {
    final robots = await _teams.listRobotTeams();
    if (robots.length > 1) {
      throw StateError('This account belongs to multiple Dosey robots.');
    }
    return robots.firstOrNull;
  }
}
