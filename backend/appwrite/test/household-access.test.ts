import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  HouseholdAccessAuthorizer,
  type HouseholdLinkLookup,
} from '../src/application/household-access.js';

describe('Household sync authorization', () => {
  test('returns the stored role for an active link to the requested robot', async () => {
    const links: HouseholdLinkLookup = {
      getLink: async () => ({
        accountId: 'member-1',
        robotId: 'robot-1',
        role: 'member',
        status: 'active',
      }),
    };

    const access = await new HouseholdAccessAuthorizer(links).authorize({
      accountId: 'member-1',
      robotId: 'robot-1',
    });

    assert.deepEqual(access, { robotId: 'robot-1', role: 'member' });
  });

  test('denies missing, inactive, and cross-robot links', async () => {
    for (const link of [
      null,
      {
        accountId: 'member-1',
        robotId: 'robot-1',
        role: 'member' as const,
        status: 'provisioning' as const,
      },
      {
        accountId: 'member-1',
        robotId: 'other-robot',
        role: 'member' as const,
        status: 'active' as const,
      },
    ]) {
      const links: HouseholdLinkLookup = { getLink: async () => link };

      assert.equal(
        await new HouseholdAccessAuthorizer(links).authorize({
          accountId: 'member-1',
          robotId: 'robot-1',
        }),
        null,
      );
    }
  });
});
