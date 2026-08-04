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
      getLink: async (accountId, robotId) => ({
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

  test('passes both account and robot to the lookup', async () => {
    let received: unknown;
    const links: HouseholdLinkLookup = {
      getLink: async (accountId, robotId) => {
        received = { accountId, robotId };
        return null;
      },
    };

    await new HouseholdAccessAuthorizer(links).authorize({
      accountId: 'member-1', robotId: 'robot-1',
    });

    assert.deepEqual(received, { accountId: 'member-1', robotId: 'robot-1' });
  });
});

describe('Mounted-device sync authorization', () => {
  test('authorizes only the claimed anonymous account for its exact robot', async () => {
    const mounted = {
      findByDevice: async () => [{
        robotId: 'robot-1', mountedDeviceAccountId: 'device-1', pairingClaimId: 'claim-1',
        registeredPatientDeviceId: 'patient-device-1',
        createdAt: new Date('2026-07-29T10:00:00Z'), updatedAt: new Date('2026-07-29T10:00:00Z'),
      }],
      getRobotInstallation: async () => ({
        robotId: 'robot-1', displayName: 'Dosey', status: 'active' as const,
      }),
    };
    const access = new MedicationSyncAccessAuthorizer(
      new HouseholdAccessAuthorizer({ getLink: async () => null }),
      mounted,
    );

    assert.deepEqual(await access.authorize({
      accountId: 'device-1', actorType: 'device', robotId: 'robot-1',
    }), {
      robotId: 'robot-1',
      role: 'device',
      authority: 'patient_device',
      registeredPatientDeviceId: 'patient-device-1',
    });
    assert.equal(await access.authorize({
      accountId: 'device-1', actorType: 'device', robotId: 'other-robot',
    }), null);
  });

  test('denies revoked, duplicate, and mismatched device access rows', async () => {
    for (const records of [[], [
      { robotId: 'robot-1', mountedDeviceAccountId: 'device-1' },
      { robotId: 'robot-2', mountedDeviceAccountId: 'device-1' },
    ], [{ robotId: 'robot-1', mountedDeviceAccountId: 'other-device' }]]) {
      const access = new MedicationSyncAccessAuthorizer(
        new HouseholdAccessAuthorizer({ getLink: async () => ({
          accountId: 'device-1', robotId: 'robot-1', role: 'owner', status: 'active',
        }) }),
        {
          findByDevice: async () => records,
          getRobotInstallation: async () => ({
            robotId: 'robot-1', displayName: 'Dosey', status: 'active',
          }),
        },
      );
      assert.equal(await access.authorize({
        accountId: 'device-1', actorType: 'device', robotId: 'robot-1',
      }), null);
    }
  });

  test('requires an active, safely mapped robot installation for a device', async () => {
    for (const installation of [
      null,
      { robotId: 'robot-1', displayName: 'Dosey', status: 'provisioning' as const },
      { robotId: 'other-robot', displayName: 'Dosey', status: 'active' as const },
    ]) {
      const access = new MedicationSyncAccessAuthorizer(
        new HouseholdAccessAuthorizer({ getLink: async () => null }),
        {
          findByDevice: async () => [{ robotId: 'robot-1', mountedDeviceAccountId: 'device-1' }],
          getRobotInstallation: async () => installation,
        },
      );
      assert.equal(await access.authorize({
        accountId: 'device-1', actorType: 'device', robotId: 'robot-1',
      }), null);
    }

    const malformed = new MedicationSyncAccessAuthorizer(
      new HouseholdAccessAuthorizer({ getLink: async () => null }),
      {
        findByDevice: async () => [{ robotId: 'robot-1', mountedDeviceAccountId: 'device-1' }],
        getRobotInstallation: async () => { throw new Error('malformed installation'); },
      },
    );
    assert.equal(await malformed.authorize({
      accountId: 'device-1', actorType: 'device', robotId: 'robot-1',
    }), null);
  });
});
