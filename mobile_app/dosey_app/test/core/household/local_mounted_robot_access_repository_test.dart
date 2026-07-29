import 'package:dosey_app/core/household/local_mounted_robot_access_repository.dart';
import 'package:dosey_app/core/household/mounted_robot_access_gateway.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'partitions minimal mounted access by account and restores it',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalMountedRobotAccessRepository(database);
      final confirmedAt = DateTime.utc(2026, 7, 28, 12);
      final robot = const MountedRobotInstallation(
        robotId: 'robot-1',
        displayName: 'Kitchen Dosey',
      );

      await repository.replaceForAccount(
        'account-1',
        robot,
        confirmedAt: confirmedAt,
      );

      final cached = await repository.readForAccount('account-1');
      expect(cached?.robot, robot);
      expect(cached?.confirmedAt.isAtSameMomentAs(confirmedAt), isTrue);
      expect(await repository.readForAccount('account-2'), isNull);
    },
  );

  test(
    'schema 16 migration creates mounted access without changing human cache',
    () async {
      final database = DoseyDatabase(
        NativeDatabase.memory(
          setup: (sqlite) {
            sqlite.execute('''
              CREATE TABLE cached_robot_installations (
                account_id TEXT NOT NULL PRIMARY KEY,
                robot_id TEXT NOT NULL,
                display_name TEXT NOT NULL,
                owner_account_id TEXT NOT NULL,
                current_role TEXT NOT NULL CHECK (current_role IN ('owner', 'member')),
                mounted_device_id TEXT NULL,
                confirmed_at INTEGER NOT NULL
              );
            ''');
            sqlite.execute('''
              INSERT INTO cached_robot_installations
                (account_id, robot_id, display_name, owner_account_id, current_role, confirmed_at)
              VALUES ('human-1', 'robot-1', 'Dosey', 'human-1', 'owner', 1785230400);
            ''');
            sqlite.execute('''
              CREATE TABLE cached_household_members (
                account_id TEXT NOT NULL,
                member_account_id TEXT NOT NULL,
                label TEXT NOT NULL,
                role TEXT NOT NULL CHECK (role IN ('owner', 'member')),
                position INTEGER NOT NULL,
                PRIMARY KEY (account_id, member_account_id)
              );
            ''');
            sqlite.execute('''
              INSERT INTO cached_household_members
                (account_id, member_account_id, label, role, position)
              VALUES
                ('human-1', 'human-1', 'Owner', 'owner', 0),
                ('human-1', 'member-1', 'Member', 'member', 1);
            ''');
            sqlite.execute('PRAGMA user_version = 16;');
          },
        ),
      );
      addTearDown(database.close);

      final columns = await database
          .customSelect('PRAGMA table_info(cached_mounted_robot_access)')
          .get();
      expect(columns.map((row) => row.read<String>('name')), [
        'account_id',
        'robot_id',
        'display_name',
        'confirmed_at',
      ]);
      final humanRows = await database
          .customSelect(
            'SELECT account_id, current_role FROM cached_robot_installations',
          )
          .get();
      expect(humanRows.single.read<String>('account_id'), 'human-1');
      expect(humanRows.single.read<String>('current_role'), 'owner');
      final memberRows = await database
          .customSelect(
            'SELECT member_account_id, role FROM cached_household_members ORDER BY position',
          )
          .get();
      expect(memberRows.map((row) => row.read<String>('member_account_id')), [
        'human-1',
        'member-1',
      ]);
      expect(memberRows.map((row) => row.read<String>('role')), [
        'owner',
        'member',
      ]);
    },
  );
}
