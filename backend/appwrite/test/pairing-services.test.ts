import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  ClaimRobotApplicationService,
  CreatePairingCodeApplicationService,
  PairingCodeConflictError,
  type PairingClaimStore,
  type PairingCredentialStore,
  type RobotAccessDirectory,
} from '../src/application/pairing-services.js';

describe('pairing application services', () => {
  test('only an owner can replace the active pairing credential', async () => {
    const saved: unknown[] = [];
    const store: PairingCredentialStore = {
      replaceActive: async (record) => {
        saved.push(record);
      },
    };
    const robots: RobotAccessDirectory = {
      isOwner: async ({ accountId }) => accountId === 'owner-1',
      canMountDevice: async () => true,
    };
    const service = new CreatePairingCodeApplicationService({
      store,
      robots,
      secret: 'server-only-secret-at-least-32-bytes',
      createId: () => 'claim-1',
      now: () => new Date('2026-07-26T12:00:00.000Z'),
      selectIndex: () => 0,
    });

    await assert.rejects(
      service.create({ robotId: 'robot-1', ownerAccountId: 'not-owner' }),
      { name: 'RobotOwnerRequiredError' },
    );
    assert.equal(saved.length, 0);

    const issued = await service.create({
      robotId: 'robot-1',
      ownerAccountId: 'owner-1',
    });
    assert.equal(issued.code, 'AAAAAAAAAA');
    assert.equal(saved.length, 1);
  });

  test('regenerates a pairing code after a digest conflict', async () => {
    let saveCount = 0;
    const service = new CreatePairingCodeApplicationService({
      store: {
        replaceActive: async () => {
          saveCount += 1;
          if (saveCount === 1) throw new PairingCodeConflictError();
        },
      },
      robots: {
        isOwner: async () => true,
        canMountDevice: async () => true,
      },
      secret: 'server-only-secret-at-least-32-bytes',
      createId: () => `claim-${saveCount + 1}`,
      now: () => new Date('2026-07-26T12:00:00.000Z'),
      selectIndex: () => saveCount,
    });

    const issued = await service.create({
      robotId: 'robot-1',
      ownerAccountId: 'owner-1',
    });

    assert.equal(saveCount, 2);
    assert.equal(issued.code, 'BBBBBBBBBB');
  });

  test('delegates claim eligibility to the atomic claim store', async () => {
    const store: PairingClaimStore = {
      claimAtomically: async (input) => {
        assert.equal(await input.canClaim('robot-1'), true);
        return { status: 'accepted', robotId: 'robot-1' };
      },
    };
    const robots: RobotAccessDirectory = {
      isOwner: async () => false,
      canMountDevice: async () => true,
    };
    const service = new ClaimRobotApplicationService({
      store,
      robots,
      secret: 'server-only-secret-at-least-32-bytes',
      now: () => new Date('2026-07-26T12:00:00.000Z'),
    });

    const result = await service.claimRobot({
      code: 'ABCD2EFGH3',
      mountedDeviceAccountId: 'device-1',
    });

    assert.deepEqual(result, { status: 'accepted', robotId: 'robot-1' });
  });

  test('does not invoke eligibility when the claim is rejected', async () => {
    let checked = false;
    const store: PairingClaimStore = {
      claimAtomically: async () => ({ status: 'rejected', reason: 'expired' }),
    };
    const service = new ClaimRobotApplicationService({
      store,
      robots: {
        isOwner: async () => false,
        canMountDevice: async () => { checked = true; return true; },
      },
      secret: 'server-only-secret-at-least-32-bytes',
      now: () => new Date('2026-07-26T12:00:00.000Z'),
    });

    const result = await service.claimRobot({
      code: 'ABCD2EFGH3',
      mountedDeviceAccountId: 'device-1',
    });

    assert.deepEqual(result, { status: 'rejected', reason: 'expired' });
    assert.equal(checked, false);
  });

  test('rejects an owner before consuming the claim', async () => {
    const store: PairingClaimStore = {
      claimAtomically: async (input) => {
        const allowed = await input.canClaim('robot-1');
        return allowed
          ? { status: 'accepted', robotId: 'robot-1' }
          : { status: 'rejected', reason: 'invalid' };
      },
    };
    const service = new ClaimRobotApplicationService({
      store,
      robots: {
        isOwner: async () => false,
        canMountDevice: async ({ accountId }) => accountId !== 'owner-1',
      },
      secret: 'server-only-secret-at-least-32-bytes',
      now: () => new Date('2026-07-26T12:00:00.000Z'),
    });

    const result = await service.claimRobot({
      code: 'ABCD2EFGH3',
      mountedDeviceAccountId: 'owner-1',
    });

    assert.deepEqual(result, { status: 'rejected', reason: 'invalid' });
  });
});
