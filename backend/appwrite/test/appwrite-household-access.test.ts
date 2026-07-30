import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import { AppwriteException } from 'node-appwrite';

import {
  AppwriteHouseholdAccessRowsApi,
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
      await new AppwriteHouseholdLinkLookup(rows).getLink('owner-1', 'robot-1'),
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
    assert.equal(await new AppwriteHouseholdLinkLookup(absent).getLink('member-1', 'robot-1'), null);

    for (const row of [
      { $id: 'member-1', robotId: '', role: 'member', status: 'active' },
      { $id: 'member-1', robotId: 'robot-1', role: 'admin', status: 'active' },
      { $id: 'member-1', robotId: 'robot-1', role: 'member', status: 'unknown' },
    ]) {
      const malformed: HouseholdAccessRowsApi = {
        getHumanRobotLink: async () => row,
      };
      await assert.rejects(
        new AppwriteHouseholdLinkLookup(malformed).getLink('member-1', 'robot-1'),
        /Invalid human robot link/,
      );
    }
  });

  test('returns null when the account row is inactive or belongs to another robot', async () => {
    for (const row of [
      { $id: 'member-1', robotId: 'robot-1', role: 'member', status: 'provisioning' },
      { $id: 'member-1', robotId: 'robot-2', role: 'member', status: 'active' },
    ]) {
      const lookup = new AppwriteHouseholdLinkLookup({ getHumanRobotLink: async () => row });
      assert.equal(await lookup.getLink('member-1', 'robot-1'), null);
    }
  });

  test('returns null only for Appwrite row-not-found errors', async () => {
    const rows = new AppwriteHouseholdAccessRowsApi({
      getRow: async () => {
        throw new AppwriteException('not found', 404, 'row_not_found');
      },
    } as never, 'database', 'human_robot_links');
    assert.equal(await rows.getHumanRobotLink('member-1'), null);

    for (const error of [
      new AppwriteException('table missing', 404, 'table_not_found'),
      { code: 404, type: 'row_not_found' },
    ]) {
      const failingRows = new AppwriteHouseholdAccessRowsApi({
        getRow: async () => { throw error; },
      } as never, 'database', 'human_robot_links');
      await assert.rejects(failingRows.getHumanRobotLink('member-1'));
    }
  });
});
