import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  HouseholdAccessAuthorizer,
  MedicationSyncAccessAuthorizer,
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

describe('Mounted-device sync authorization', () => {
  test('authorizes only the claimed anonymous account for its exact robot', async () => {
    const mounted = {
      findByDevice: async () => [{
        robotId: 'robot-1', mountedDeviceAccountId: 'device-1', pairingClaimId: 'claim-1',
        createdAt: new Date('2026-07-29T10:00:00Z'), updatedAt: new Date('2026-07-29T10:00:00Z'),
      }],
    };
    const access = new MedicationSyncAccessAuthorizer(
      new HouseholdAccessAuthorizer({ getLink: async () => null }),
      mounted,
    );

    assert.deepEqual(await access.authorize({
      accountId: 'device-1', actorType: 'device', robotId: 'robot-1',
    }), { robotId: 'robot-1', role: 'device' });
    assert.equal(await access.authorize({
      accountId: 'device-1', actorType: 'device', robotId: 'other-robot',
    }), null);
  });

  test('denies revoked, duplicate, and human-link-only device accounts', async () => {
    for (const records of [[], [
      { robotId: 'robot-1', mountedDeviceAccountId: 'device-1' },
      { robotId: 'robot-2', mountedDeviceAccountId: 'device-1' },
    ]]) {
      const access = new MedicationSyncAccessAuthorizer(
        new HouseholdAccessAuthorizer({ getLink: async () => ({
          accountId: 'device-1', robotId: 'robot-1', role: 'owner', status: 'active',
        }) }),
        { findByDevice: async () => records },
      );
      assert.equal(await access.authorize({
        accountId: 'device-1', actorType: 'device', robotId: 'robot-1',
      }), null);
    }
  });
});
