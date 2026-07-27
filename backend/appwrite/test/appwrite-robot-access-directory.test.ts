import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  AppwriteRobotAccessDirectory,
  isRevocableRobotDeviceMembership,
  type RobotTeam,
  type RobotTeamsApi,
} from '../src/infrastructure/appwrite-robot-access-directory.js';

class FakeRobotTeamsApi implements RobotTeamsApi {
  teams = new Map<string, RobotTeam>();
  replacements: Array<{ robotId: string; deviceId: string }> = [];

  getRobot(robotId: string) {
    return Promise.resolve(this.teams.get(robotId) ?? null);
  }

  replaceMountedDevice(robotId: string, mountedDeviceAccountId: string) {
    this.replacements.push({ robotId, deviceId: mountedDeviceAccountId });
    return Promise.resolve();
  }
}

describe('Appwrite robot access directory', () => {
  test('recognizes only the owner stored on a marked robot team', async () => {
    const api = new FakeRobotTeamsApi();
    api.teams.set('robot-1', {
      id: 'robot-1',
      isDoseyRobot: true,
      ownerAccountId: 'owner-1',
      mountedDeviceAccountId: null,
      humanAccountIds: ['owner-1'],
    });
    const directory = new AppwriteRobotAccessDirectory(api);

    assert.equal(
      await directory.isOwner({ robotId: 'robot-1', accountId: 'owner-1' }),
      true,
    );
    assert.equal(
      await directory.isOwner({ robotId: 'robot-1', accountId: 'other' }),
      false,
    );
  });

  test('rejects access to an unmarked team', async () => {
    const api = new FakeRobotTeamsApi();
    api.teams.set('team-1', {
      id: 'team-1',
      isDoseyRobot: false,
      ownerAccountId: 'owner-1',
      mountedDeviceAccountId: null,
      humanAccountIds: ['owner-1'],
    });
    const directory = new AppwriteRobotAccessDirectory(api);

    assert.equal(
      await directory.isOwner({ robotId: 'team-1', accountId: 'owner-1' }),
      false,
    );
    await assert.rejects(
      directory.mountDevice({
        robotId: 'team-1',
        mountedDeviceAccountId: 'device-1',
      }),
      /Dosey robot not found/,
    );
  });

  test('delegates mounted-device replacement for a marked robot', async () => {
    const api = new FakeRobotTeamsApi();
    api.teams.set('robot-1', {
      id: 'robot-1',
      isDoseyRobot: true,
      ownerAccountId: 'owner-1',
      mountedDeviceAccountId: 'old-device',
      humanAccountIds: ['owner-1'],
    });
    const directory = new AppwriteRobotAccessDirectory(api);

    await directory.mountDevice({
      robotId: 'robot-1',
      mountedDeviceAccountId: 'new-device',
    });

    assert.deepEqual(api.replacements, [
      { robotId: 'robot-1', deviceId: 'new-device' },
    ]);
  });

  test('does not allow an owner or accepted human to mount as the robot device', async () => {
    const api = new FakeRobotTeamsApi();
    api.teams.set('robot-1', {
      id: 'robot-1',
      isDoseyRobot: true,
      ownerAccountId: 'owner-1',
      mountedDeviceAccountId: null,
      humanAccountIds: ['owner-1', 'family-1'],
    });
    const directory = new AppwriteRobotAccessDirectory(api);

    assert.equal(
      await directory.canMountDevice({ robotId: 'robot-1', accountId: 'owner-1' }),
      false,
    );
    assert.equal(
      await directory.canMountDevice({ robotId: 'robot-1', accountId: 'family-1' }),
      false,
    );
    assert.equal(
      await directory.canMountDevice({ robotId: 'robot-1', accountId: 'device-1' }),
      true,
    );
  });

  test('never selects a human membership for mounted-device revocation', () => {
    assert.equal(
      isRevocableRobotDeviceMembership(
        { userId: 'owner-1', roles: ['owner'] },
        'owner-1',
      ),
      false,
    );
    assert.equal(
      isRevocableRobotDeviceMembership(
        { userId: 'old-device', roles: ['robot-device'] },
        'old-device',
      ),
      true,
    );
    assert.equal(
      isRevocableRobotDeviceMembership(
        { userId: 'old-device', roles: ['robot-device', 'owner'] },
        'old-device',
      ),
      false,
    );
  });
});
