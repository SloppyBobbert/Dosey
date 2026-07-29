import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  AppwriteRobotAccessDirectory,
  AppwriteRobotTeamsApi,
  type RobotTeam,
  type RobotTeamsApi,
} from '../src/infrastructure/appwrite-robot-access-directory.js';
import type { Teams } from 'node-appwrite';

class FakeRobotTeamsApi implements RobotTeamsApi {
  teams = new Map<string, RobotTeam>();

  getRobot(robotId: string) {
    return Promise.resolve(this.teams.get(robotId) ?? null);
  }
}

describe('Appwrite robot access directory', () => {
  test('recognizes only the owner stored on a marked robot team', async () => {
    const api = new FakeRobotTeamsApi();
    api.teams.set('robot-1', {
      id: 'robot-1',
      isDoseyRobot: true,
      ownerAccountId: 'owner-1',
      teamMemberAccountIds: ['owner-1'],
    });
    const directory = new AppwriteRobotAccessDirectory(api);

    assert.equal(await directory.isOwner({ robotId: 'robot-1', accountId: 'owner-1' }), true);
    assert.equal(await directory.isOwner({ robotId: 'robot-1', accountId: 'other' }), false);
  });

  test('rejects owners and any accepted human Team membership as device candidates', async () => {
    const api = new FakeRobotTeamsApi();
    api.teams.set('robot-1', {
      id: 'robot-1',
      isDoseyRobot: true,
      ownerAccountId: 'owner-1',
      teamMemberAccountIds: ['owner-1', 'family-1'],
    });
    const directory = new AppwriteRobotAccessDirectory(api);

    assert.equal(await directory.canMountDevice({ robotId: 'robot-1', accountId: 'owner-1' }), false);
    assert.equal(await directory.canMountDevice({ robotId: 'robot-1', accountId: 'family-1' }), false);
    assert.equal(await directory.canMountDevice({ robotId: 'robot-1', accountId: 'device-1' }), true);
  });

  test('does not expose a Team write path for mounted robot access', () => {
    assert.equal('replaceMountedDevice' in AppwriteRobotTeamsApi.prototype, false);
    assert.equal('mountDevice' in AppwriteRobotAccessDirectory.prototype, false);
  });

  test('reads robot eligibility without writing Team preferences or memberships', async () => {
    const calls: string[] = [];
    const teams = {
      get: async () => ({
        $id: 'robot-1',
        prefs: { doseyRobot: true, ownerAccountId: 'owner-1', mountedDeviceId: 'legacy-value' },
      }),
      listMemberships: async () => ({ memberships: [] }),
      updatePrefs: async () => calls.push('updatePrefs'),
      createMembership: async () => calls.push('createMembership'),
      deleteMembership: async () => calls.push('deleteMembership'),
    } as unknown as Teams;

    const robot = await new AppwriteRobotTeamsApi(teams).getRobot('robot-1');
    assert.equal(robot?.isDoseyRobot, true);
    assert.deepEqual(calls, []);
  });

  test('rejects access to an unmarked team', async () => {
    const api = new FakeRobotTeamsApi();
    api.teams.set('team-1', {
      id: 'team-1',
      isDoseyRobot: false,
      ownerAccountId: 'owner-1',
      teamMemberAccountIds: ['owner-1'],
    });
    const directory = new AppwriteRobotAccessDirectory(api);

    assert.equal(await directory.isOwner({ robotId: 'team-1', accountId: 'owner-1' }), false);
    assert.equal(await directory.canMountDevice({ robotId: 'team-1', accountId: 'device-1' }), false);
  });

  test('rejects every existing Team membership regardless of confirmation or roles', async () => {
    for (const membership of [
      { userId: 'device-1', confirm: true, roles: ['owner'] },
      { userId: 'device-1', confirm: true, roles: ['member'] },
      { userId: 'device-1', confirm: true, roles: ['robot-device'] },
      { userId: 'device-1', confirm: true, roles: ['unknown'] },
      { userId: 'device-1', confirm: true, roles: [] },
      { userId: 'device-1', confirm: true, roles: ['robot-device', 'member'] },
      { userId: 'device-1', confirm: false, roles: ['member'] },
    ]) {
      const teams = {
        get: async () => ({ $id: 'robot-1', prefs: {
          doseyRobot: true, ownerAccountId: 'owner-1',
        } }),
        listMemberships: async () => ({ memberships: [membership] }),
      } as unknown as Teams;
      const directory = new AppwriteRobotAccessDirectory(new AppwriteRobotTeamsApi(teams));
      assert.equal(
        await directory.canMountDevice({ robotId: 'robot-1', accountId: 'device-1' }),
        false,
      );
    }
  });
});
