import 'package:dosey_app/core/household/household_management_gateway.dart';
import 'package:dosey_app/core/household/household_sync_gateway.dart';
import 'package:dosey_app/core/household/local_household_cache_repository.dart';
import 'package:dosey_app/core/household/robot_installation.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/onboarding/household_membership_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const accountId = 'owner-1';
  final robot = RobotInstallation(
    id: 'robot-1',
    displayName: 'Kitchen Dosey',
    ownerAccountId: accountId,
    members: const [
      HouseholdMember(
        accountId: accountId,
        label: 'Owner',
        role: HouseholdRole.owner,
      ),
    ],
    currentRole: HouseholdRole.owner,
    mountedDeviceId: null,
  );
  final now = DateTime.utc(2026, 7, 26, 12);

  Future<void> pumpGate(
    WidgetTester tester, {
    required DoseyDatabase database,
    required HouseholdSyncGateway sync,
    HouseholdManagementGateway management =
        const DisabledHouseholdManagementGateway(),
    Future<void> Function(RobotInstallation robot)? onHouseholdCreated,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: HouseholdMembershipGate(
          accountId: accountId,
          sync: sync,
          management: management,
          cache: LocalHouseholdCacheRepository(database),
          onHouseholdCreated: onHouseholdCreated,
          now: () => now,
          child: const Text('Dosey shell'),
        ),
      ),
    );
  }

  testWidgets('live linked refresh caches membership and enters app', (
    tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    await pumpGate(
      tester,
      database: database,
      sync: _FakeSyncGateway(result: robot),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dosey shell'), findsOneWidget);
    expect(find.textContaining('offline'), findsNothing);
    final cached = await LocalHouseholdCacheRepository(
      database,
    ).readForAccount(accountId);
    expect(cached?.installation.id, robot.id);
  });

  testWidgets('failed refresh enters app from matching account cache', (
    tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await LocalHouseholdCacheRepository(
      database,
    ).replaceForAccount(accountId, robot, confirmedAt: now);

    await pumpGate(
      tester,
      database: database,
      sync: _FakeSyncGateway(error: Exception('offline')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dosey shell'), findsOneWidget);
    expect(find.text('Household status is offline'), findsOneWidget);
  });

  testWidgets('failed refresh without cache remains gated and can retry', (
    tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final sync = _FakeSyncGateway(error: Exception('offline'));

    await pumpGate(tester, database: database, sync: sync);
    await tester.pumpAndSettle();

    expect(find.text('Dosey shell'), findsNothing);
    expect(find.text('Household could not load'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('confirmed unlinked refresh clears stale cache', (tester) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final cache = LocalHouseholdCacheRepository(database);
    await cache.replaceForAccount(accountId, robot, confirmedAt: now);

    await pumpGate(
      tester,
      database: database,
      sync: _FakeSyncGateway(result: null),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create a household'), findsOneWidget);
    expect(find.text('Join with a code'), findsOneWidget);
    expect(await cache.readForAccount(accountId), isNull);
  });

  testWidgets('successful create caches result and enters app', (tester) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final management = _FakeManagementGateway(createdRobot: robot);
    RobotInstallation? auditedRobot;

    await pumpGate(
      tester,
      database: database,
      sync: _FakeSyncGateway(result: null),
      management: management,
      onHouseholdCreated: (robot) async => auditedRobot = robot,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('household-name-field')),
      'Kitchen Dosey',
    );
    await tester.tap(find.text('Create a household'));
    await tester.pumpAndSettle();

    expect(management.createdName, 'Kitchen Dosey');
    expect(auditedRobot, robot);
    expect(find.text('Dosey shell'), findsOneWidget);
    expect(
      await LocalHouseholdCacheRepository(database).readForAccount(accountId),
      isNotNull,
    );
  });
}

class _FakeSyncGateway implements HouseholdSyncGateway {
  _FakeSyncGateway({this.result, this.error});

  final RobotInstallation? result;
  final Object? error;

  @override
  Future<RobotInstallation?> refreshRobot() async {
    if (error case final error?) throw error;
    return result;
  }

  @override
  Stream<RobotInstallation?> watchRobot() => Stream.value(result);
}

class _FakeManagementGateway implements HouseholdManagementGateway {
  _FakeManagementGateway({required this.createdRobot});

  final RobotInstallation createdRobot;
  String? createdName;

  @override
  bool get isAvailable => true;

  @override
  Future<RobotInstallation> acceptInvitation(String code) async => createdRobot;

  @override
  Future<RobotInstallation> createRobot(String displayName) async {
    createdName = displayName;
    return createdRobot;
  }

  @override
  Future<HouseholdInvitationCredential> createInvitation(
    String robotId,
    String email,
  ) => throw UnimplementedError();

  @override
  Future<void> leaveRobot(String robotId) => throw UnimplementedError();

  @override
  Future<RobotInstallation> removeMember(String robotId, String accountId) =>
      throw UnimplementedError();
}
