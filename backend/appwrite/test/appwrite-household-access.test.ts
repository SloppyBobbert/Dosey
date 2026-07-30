import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  AppwriteHouseholdLinkLookup,
  type HouseholdAccessRowsApi,
} from '../src/infrastructure/appwrite-household-access.js';

describe('Appwrite household access lookup', () => {
  test('maps an active human_robot_links row', async () => {
    const rows: HouseholdAccessRowsApi = {
      getHumanRobotLink: async (accountId) => ({
        $id: accountId,
        robotId: 'robot-1',
        role: 'owner',
        status: 'active',
      }),
    };

    assert.deepEqual(
      await new AppwriteHouseholdLinkLookup(rows).getLink('owner-1'),
      {
        accountId: 'owner-1',
        robotId: 'robot-1',
        role: 'owner',
        status: 'active',
      },
    );
  });

  test('returns null for an absent row and rejects malformed authority fields', async () => {
    const absent: HouseholdAccessRowsApi = { getHumanRobotLink: async () => null };
    assert.equal(await new AppwriteHouseholdLinkLookup(absent).getLink('member-1'), null);

    for (const row of [
      { $id: 'member-1', robotId: '', role: 'member', status: 'active' },
      { $id: 'member-1', robotId: 'robot-1', role: 'admin', status: 'active' },
      { $id: 'member-1', robotId: 'robot-1', role: 'member', status: 'unknown' },
    ]) {
      const malformed: HouseholdAccessRowsApi = {
        getHumanRobotLink: async () => row,
      };
      await assert.rejects(
        new AppwriteHouseholdLinkLookup(malformed).getLink('member-1'),
        /Invalid human robot link/,
      );
    }
  });
});
