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

  test('publishes a newly created single-person robot', () async {
    final api = _FakeAppwriteTeamsApi();
    final gateway = AppwriteHouseholdSyncGateway(api);
    final changes = StreamIterator(gateway.watchRobot());
    addTearDown(() {
      changes.cancel();
    });
    expect(await changes.moveNext(), isTrue);
    expect(changes.current, isNull);

    final created = await gateway.createRobot(
      displayName: 'Kitchen Dosey',
      ownerAccountId: 'owner-1',
      mountedDeviceId: 'mounted-android-1',
    );

    expect(created.isSinglePerson, isTrue);
    expect(await changes.moveNext(), isTrue);
    expect(changes.current?.id, created.id);
    expect(api.createCalls, 1);
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

  test('rejects creating a second robot for the account', () async {
    final api = _FakeAppwriteTeamsApi(robots: [_robot(id: 'robot-1')]);
    final gateway = AppwriteHouseholdSyncGateway(api);

    await expectLater(
      gateway.createRobot(
        displayName: 'Second Dosey',
        ownerAccountId: 'owner-1',
        mountedDeviceId: 'mounted-android-2',
      ),
      throwsA(isA<RobotAlreadyExistsException>()),
    );
    expect(api.createCalls, 0);
  });

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
}

models.Membership _membership({
  required String userId,
  required List<String> roles,
}) => models.Membership(
  $id: 'membership-$userId',
  $createdAt: '2026-07-26T12:00:00.000Z',
  $updatedAt: '2026-07-26T12:00:00.000Z',
  userId: userId,
  userName: userId,
  userEmail: '',
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
  humanAccountIds: {'owner-1'},
  mountedDeviceId: 'mounted-android-1',
);

class _FakeAppwriteTeamsApi implements AppwriteTeamsApi {
  _FakeAppwriteTeamsApi({List<RobotInstallation>? robots})
    : robots = robots ?? [];

  final List<RobotInstallation> robots;
  var createCalls = 0;

  @override
  Future<RobotInstallation> createRobotTeam({
    required String displayName,
    required String ownerAccountId,
    required String mountedDeviceId,
  }) async {
    createCalls += 1;
    final robot = RobotInstallation(
      id: 'robot-created',
      displayName: displayName,
      ownerAccountId: ownerAccountId,
      humanAccountIds: {ownerAccountId},
      mountedDeviceId: mountedDeviceId,
    );
    robots.add(robot);
    return robot;
  }

  @override
  Future<List<RobotInstallation>> listRobotTeams() async => List.of(robots);
}
