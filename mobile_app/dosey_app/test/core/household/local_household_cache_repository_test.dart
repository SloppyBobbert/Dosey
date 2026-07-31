import 'package:dosey_app/core/household/local_household_cache_repository.dart';
import 'package:dosey_app/core/household/robot_installation.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const owner = HouseholdMember(
    accountId: 'owner-1',
    label: 'Owner',
    role: HouseholdRole.owner,
  );
  const member = HouseholdMember(
    accountId: 'member-1',
    label: 'Member',
    role: HouseholdRole.member,
  );
  final confirmedAt = DateTime.utc(2026, 7, 26, 12);

  RobotInstallation installation({
    String id = 'robot-1',
    List<HouseholdMember> members = const [owner, member],
    HouseholdRole currentRole = HouseholdRole.owner,
  }) {
    return RobotInstallation(
      id: id,
      displayName: 'Dosey',
      ownerAccountId: owner.accountId,
      members: members,
      currentRole: currentRole,
      mountedDeviceId: 'device-1',
    );
  }

  test('replaces and reconstructs an account household snapshot', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalHouseholdCacheRepository(database);

    await repository.replaceForAccount(
      owner.accountId,
      installation(),
      confirmedAt: confirmedAt,
    );

    final cached = await repository.readForAccount(owner.accountId);
    expect(cached, isNotNull);
    expect(cached!.confirmedAt.isAtSameMomentAs(confirmedAt), isTrue);
    expect(cached.installation.id, 'robot-1');
    expect(cached.installation.currentRole, HouseholdRole.owner);
    expect(cached.installation.mountedDeviceId, 'device-1');
    expect(cached.installation.members.map((item) => item.accountId), [
      owner.accountId,
      member.accountId,
    ]);
  });

  test('never returns another cloud account snapshot', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalHouseholdCacheRepository(database);

    await repository.replaceForAccount(
      owner.accountId,
      installation(),
      confirmedAt: confirmedAt,
    );

    expect(await repository.readForAccount('different-account'), isNull);
  });

  test('replacement removes members from the previous snapshot', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalHouseholdCacheRepository(database);

    await repository.replaceForAccount(
      owner.accountId,
      installation(),
      confirmedAt: confirmedAt,
    );
    await repository.replaceForAccount(
      owner.accountId,
      installation(members: const [owner]),
      confirmedAt: confirmedAt.add(const Duration(minutes: 1)),
    );

    final cached = await repository.readForAccount(owner.accountId);
    expect(cached!.installation.members, hasLength(1));
    expect(cached.installation.members.single.accountId, owner.accountId);
  });

  test('clear removes only the selected account snapshot', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalHouseholdCacheRepository(database);
    final memberInstallation = RobotInstallation(
      id: 'robot-2',
      displayName: 'Second Dosey',
      ownerAccountId: 'owner-2',
      members: const [
        HouseholdMember(
          accountId: 'owner-2',
          label: 'Second owner',
          role: HouseholdRole.owner,
        ),
        HouseholdMember(
          accountId: 'member-1',
          label: 'Member',
          role: HouseholdRole.member,
        ),
      ],
      currentRole: HouseholdRole.member,
      mountedDeviceId: null,
    );
    await repository.replaceForAccount(
      owner.accountId,
      installation(),
      confirmedAt: confirmedAt,
    );
    await repository.replaceForAccount(
      member.accountId,
      memberInstallation,
      confirmedAt: confirmedAt,
    );

    await repository.clearForAccount(owner.accountId);

    expect(await repository.readForAccount(owner.accountId), isNull);
    expect(await repository.readForAccount(member.accountId), isNotNull);
  });

  test('schema fifteen migration creates household cache tables', () async {
    final database = DoseyDatabase(
      NativeDatabase.memory(
        setup: (sqlite) {
          sqlite
            ..execute('''
              CREATE TABLE reminder_schedules (
                id TEXT NOT NULL PRIMARY KEY,
                label TEXT NOT NULL,
                prescription_id TEXT,
                profile_id TEXT NOT NULL DEFAULT 'schedule-1',
                hour INTEGER NOT NULL CHECK (hour >= 0 AND hour <= 23),
                minute INTEGER NOT NULL CHECK (minute >= 0 AND minute <= 59),
                is_enabled INTEGER NOT NULL CHECK (is_enabled IN (0, 1)),
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
              );
            ''')
            ..execute('PRAGMA user_version = 15;');
        },
      ),
    );
    addTearDown(database.close);
    final repository = LocalHouseholdCacheRepository(database);

    await repository.replaceForAccount(
      owner.accountId,
      installation(),
      confirmedAt: confirmedAt,
    );

    expect(await repository.readForAccount(owner.accountId), isNotNull);
  });
}
