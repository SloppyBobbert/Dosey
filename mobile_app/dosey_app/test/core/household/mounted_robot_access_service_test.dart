import 'package:dosey_app/core/household/local_mounted_robot_access_repository.dart';
import 'package:dosey_app/core/household/mounted_robot_access_gateway.dart';
import 'package:dosey_app/core/household/mounted_robot_access_service.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('claim followed by restore requires the claimed robot', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final gateway = _FakeGateway(
      const MountedRobotInstallation(robotId: 'robot-1', displayName: 'Dosey'),
    );
    final service = MountedRobotAccessService(
      gateway,
      LocalMountedRobotAccessRepository(database),
    );

    final result = await service.restoreForAccount('anonymous-1');
    expect(result.isVerified, isTrue);
    expect(result.robot?.robotId, 'robot-1');
    await expectLater(
      service.requireClaimedRobot('anonymous-1', 'robot-2'),
      throwsA(isA<MountedRobotAccessException>()),
    );
  });

  test(
    'claim mismatch does not overwrite cache or publish verified state',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalMountedRobotAccessRepository(database);
      const cachedRobot = MountedRobotInstallation(
        robotId: 'cached-robot',
        displayName: 'Cached Dosey',
      );
      await repository.replaceForAccount(
        'anonymous-1',
        cachedRobot,
        confirmedAt: DateTime.utc(2026, 7, 28),
      );
      final service = MountedRobotAccessService(
        _FakeGateway(
          const MountedRobotInstallation(
            robotId: 'different-robot',
            displayName: 'Different Dosey',
          ),
        ),
        repository,
      );
      final states = service.watchState();

      await expectLater(
        service.requireClaimedRobot('anonymous-1', 'claimed-robot'),
        throwsA(isA<MountedRobotAccessException>()),
      );
      expect(
        (await repository.readForAccount('anonymous-1'))?.robot,
        cachedRobot,
      );
      expect(service.currentState.status, MountedRobotAccessStatus.error);
      await states.take(1).drain<void>();
    },
  );

  test(
    'authoritative null clears cache and network failure returns unverified cache',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalMountedRobotAccessRepository(database);
      final gateway = _FakeGateway(
        const MountedRobotInstallation(
          robotId: 'robot-1',
          displayName: 'Dosey',
        ),
      );
      final service = MountedRobotAccessService(gateway, repository);
      final changes = service.watch();

      await service.restoreForAccount('anonymous-1');
      gateway.value = null;
      final unmountedChange = changes.first;
      final unmounted = await service.restoreForAccount('anonymous-1');
      expect(unmounted.robot, isNull);
      expect(unmounted.isVerified, isTrue);
      expect((await unmountedChange).robot, isNull);
      expect(await repository.readForAccount('anonymous-1'), isNull);

      gateway.value = const MountedRobotInstallation(
        robotId: 'robot-1',
        displayName: 'Dosey',
      );
      await service.restoreForAccount('anonymous-1');
      gateway.error = const MountedRobotAccessTransportException('offline');
      final restarted = MountedRobotAccessService(gateway, repository);
      final offline = await restarted.restoreForAccount('anonymous-1');
      expect(offline.robot?.robotId, 'robot-1');
      expect(offline.isVerified, isFalse);
    },
  );

  test(
    'cache write failure does not fail verified claim confirmation',
    () async {
      final database = DoseyDatabase.inMemory();
      final service = MountedRobotAccessService(
        _FakeGateway(
          const MountedRobotInstallation(
            robotId: 'robot-1',
            displayName: 'Dosey',
          ),
        ),
        LocalMountedRobotAccessRepository(database),
      );
      await database.close();

      final result = await service.requireClaimedRobot(
        'anonymous-1',
        'robot-1',
      );

      expect(result.isVerified, isTrue);
      expect(
        service.currentState.status,
        MountedRobotAccessStatus.verifiedMounted,
      );
      await service.close();
    },
  );
}

class _FakeGateway implements MountedRobotAccessGateway {
  _FakeGateway(this.value);

  MountedRobotInstallation? value;
  Object? error;

  @override
  bool get isAvailable => true;

  @override
  Future<MountedRobotInstallation?> restore() async {
    if (error case final error?) throw error;
    return value;
  }
}
