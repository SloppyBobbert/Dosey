import 'dart:async';

import 'package:appwrite/models.dart' as models;
import 'package:dosey_app/core/household/appwrite_household_sync_gateway.dart';
import 'package:dosey_app/core/household/robot_installation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restores a single-person robot from Appwrite Teams', () async {
    final api = _FakeAppwriteTeamsApi(robots: [_robot(id: 'robot-1')]);
    final gateway = AppwriteHouseholdSyncGateway(api);

    final robot = await gateway.watchRobot().first;

    expect(robot?.id, 'robot-1');
    expect(robot?.ownerAccountId, 'owner-1');
    expect(robot?.humanAccountIds, {'owner-1'});
    expect(robot?.isSinglePerson, isTrue);
  });

  test(
    'refresh publishes membership changes made by a cloud function',
    () async {
      final api = _FakeAppwriteTeamsApi();
      final gateway = AppwriteHouseholdSyncGateway(api);
      final changes = StreamIterator(gateway.watchRobot());
      addTearDown(() {
        changes.cancel();
      });
      expect(await changes.moveNext(), isTrue);
      expect(changes.current, isNull);
      api.robots.add(_robot(id: 'robot-1'));

      final refreshed = await gateway.refreshRobot();

      expect(refreshed?.id, 'robot-1');
      expect(await changes.moveNext(), isTrue);
      expect(changes.current?.id, 'robot-1');
    },
  );

  test('rejects ambiguous membership in multiple Dosey robots', () async {
    final api = _FakeAppwriteTeamsApi(
      robots: [
        _robot(id: 'robot-1'),
        _robot(id: 'robot-2'),
      ],
    );
    final gateway = AppwriteHouseholdSyncGateway(api);

    await expectLater(gateway.watchRobot().first, throwsStateError);
  });

  test('excludes a confirmed robot-device membership from human accounts', () {
    final humanIds = acceptedHumanAccountIds([
      _membership(userId: 'owner-1', roles: ['owner']),
      _membership(userId: 'device-1', roles: ['robot-device']),
    ], mountedDeviceId: 'device-1');

    expect(humanIds, {'owner-1'});
  });

  test('keeps mixed-role memberships in the human account set', () {
    final memberships = [
      _membership(userId: 'family-1', roles: const ['member', 'robot-device']),
    ];

    expect(acceptedHumanAccountIds(memberships, mountedDeviceId: 'device-1'), {
      'family-1',
    });
  });

  test('maps accepted member labels and roles with privacy fallbacks', () {
    final members = acceptedHouseholdMembers([
      _membership(
        userId: 'owner-1',
        roles: const ['owner'],
        userName: 'Owner Person',
      ),
      _membership(
        userId: 'member-1',
        roles: const ['member'],
        userEmail: 'member@example.com',
      ),
    ], mountedDeviceId: null);

    expect(members.first.label, 'Owner Person');
    expect(members.first.role, HouseholdRole.owner);
    expect(members.last.label, 'member@example.com');
    expect(members.last.role, HouseholdRole.member);
  });
}

models.Membership _membership({
  required String userId,
  required List<String> roles,
  String userName = '',
  String userEmail = '',
}) => models.Membership(
  $id: 'membership-$userId',
  $createdAt: '2026-07-26T12:00:00.000Z',
  $updatedAt: '2026-07-26T12:00:00.000Z',
  userId: userId,
  userName: userName,
  userEmail: userEmail,
  userPhone: '',
  teamId: 'robot-1',
  teamName: 'Kitchen Dosey',
  invited: '2026-07-26T12:00:00.000Z',
  joined: '2026-07-26T12:00:00.000Z',
  confirm: true,
  mfa: false,
  userAccessedAt: '2026-07-26T12:00:00.000Z',
  roles: roles,
);

RobotInstallation _robot({required String id}) => RobotInstallation(
  id: id,
  displayName: 'Kitchen Dosey',
  ownerAccountId: 'owner-1',
  members: const [
    HouseholdMember(
      accountId: 'owner-1',
      label: 'Owner Person',
      role: HouseholdRole.owner,
    ),
  ],
  currentRole: HouseholdRole.owner,
  mountedDeviceId: 'mounted-android-1',
);

class _FakeAppwriteTeamsApi implements AppwriteTeamsApi {
  _FakeAppwriteTeamsApi({List<RobotInstallation>? robots})
    : robots = robots ?? [];

  final List<RobotInstallation> robots;

  @override
  Future<List<RobotInstallation>> listRobotTeams() async => List.of(robots);
}
