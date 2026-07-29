import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import type { PairingClaimRecord } from '../src/domain/pairing-claim.js';
import {
  TransactionalPairingStore,
  type PairingAttemptRecord,
  type PairingPersistence,
  type PairingTransaction,
} from '../src/infrastructure/transactional-pairing-store.js';
import { PairingTransactionConflictError } from '../src/infrastructure/appwrite-pairing-persistence.js';
import type { MountedRobotAccessRecord } from '../src/domain/mounted-robot-access.js';

class MemoryPairingPersistence implements PairingPersistence, PairingTransaction {
  claims = new Map<string, PairingClaimRecord>();
  activeClaimIds = new Set<string>();
  attempts = new Map<string, PairingAttemptRecord>();
  mountedAccess = new Map<string, MountedRobotAccessRecord>();

  async transaction<T>(operation: (transaction: PairingTransaction) => Promise<T>) {
    const claims = new Map(this.claims);
    const activeClaimIds = new Set(this.activeClaimIds);
    const attempts = new Map(this.attempts);
    const mountedAccess = new Map(this.mountedAccess);
    try {
      return await operation(this);
    } catch (error) {
      this.claims = claims;
      this.activeClaimIds = activeClaimIds;
      this.attempts = attempts;
      this.mountedAccess = mountedAccess;
      throw error;
    }
  }

  async deactivateRobotClaims(robotId: string) {
    for (const id of this.activeClaimIds) {
      if (this.claims.get(id)?.robotId === robotId) this.activeClaimIds.delete(id);
    }
  }

  async createClaim(record: PairingClaimRecord) {
    this.claims.set(record.id, record);
    this.activeClaimIds.add(record.id);
  }

  async findActiveClaimByDigest(codeDigest: string) {
    return (
      [...this.activeClaimIds]
        .map((id) => this.claims.get(id))
        .find((record) => record?.codeDigest === codeDigest) ?? null
    );
  }

  async saveClaim(record: PairingClaimRecord) {
    this.claims.set(record.id, record);
  }

  async getAttempt(deviceAccountId: string) {
    return this.attempts.get(deviceAccountId) ?? null;
  }

  async saveAttempt(record: PairingAttemptRecord) {
    this.attempts.set(record.deviceAccountId, record);
  }

  async findMountedAccessByDevice(deviceAccountId: string) {
    return [...this.mountedAccess.values()].filter(
      (record) => record.mountedDeviceAccountId === deviceAccountId,
    );
  }

  async getMountedAccessByRobot(robotId: string) {
    return this.mountedAccess.get(robotId) ?? null;
  }

  async createMountedAccess(record: MountedRobotAccessRecord) {
    this.mountedAccess.set(record.robotId, record);
  }

  async updateMountedAccess(record: MountedRobotAccessRecord) {
    this.mountedAccess.set(record.robotId, record);
  }
}

function claim(id: string, robotId: string, digest: string): PairingClaimRecord {
  return {
    id,
    robotId,
    codeDigest: digest,
    expiresAt: new Date('2026-07-26T12:10:00.000Z'),
    consumedAt: null,
  };
}

describe('transactional pairing store', () => {
  test('maps a concurrent claim transaction conflict to consumed', async () => {
    const store = new TransactionalPairingStore({
      transaction: async () => {
        throw new PairingTransactionConflictError();
      },
      resolveClaimConflict: async () => 'consumed',
    });

    const result = await store.claimAtomically({
      codeDigest: 'digest',
      mountedDeviceAccountId: 'device-1',
      now: new Date('2026-07-26T12:00:00.000Z'),
      canClaim: async () => true,
    });

    assert.deepEqual(result, { status: 'rejected', reason: 'consumed' });
  });

  test('does not classify an unresolved conflict as a safe rejection', async () => {
    const store = new TransactionalPairingStore({
      transaction: async () => { throw new PairingTransactionConflictError(); },
    });

    await assert.rejects(
      store.claimAtomically({
        codeDigest: 'digest', mountedDeviceAccountId: 'device-1',
        now: new Date('2026-07-26T12:00:00.000Z'), canClaim: async () => true,
      }),
      PairingTransactionConflictError,
    );
  });

  test('classifies a unique mounted-device race from authoritative conflict checks', async () => {
    const store = new TransactionalPairingStore({
      transaction: async () => { throw new PairingTransactionConflictError(); },
      resolveClaimConflict: async () => 'device_already_mounted',
    });

    assert.deepEqual(await store.claimAtomically({
      codeDigest: 'digest', mountedDeviceAccountId: 'device-1',
      now: new Date('2026-07-26T12:00:00.000Z'), canClaim: async () => true,
    }), { status: 'rejected', reason: 'device_already_mounted' });
  });
  test('replacing a credential invalidates the previous robot credential', async () => {
    const persistence = new MemoryPairingPersistence();
    const store = new TransactionalPairingStore(persistence);
    await store.replaceActive(claim('old', 'robot-1', 'old-digest'));

    await store.replaceActive(claim('new', 'robot-1', 'new-digest'));

    assert.deepEqual([...persistence.activeClaimIds], ['new']);
  });

  test('consumes a matching credential and permits same-device retry', async () => {
    const persistence = new MemoryPairingPersistence();
    const store = new TransactionalPairingStore(persistence);
    await store.replaceActive(claim('claim-1', 'robot-1', 'digest'));
    const input = {
      codeDigest: 'digest',
      mountedDeviceAccountId: 'device-1',
      now: new Date('2026-07-26T12:00:00.000Z'),
      canClaim: async () => true,
    };

    assert.deepEqual(await store.claimAtomically(input), {
      status: 'accepted',
      robotId: 'robot-1',
    });
    assert.deepEqual(await store.claimAtomically(input), {
      status: 'accepted',
      robotId: 'robot-1',
    });
  });

  test('blocks a device for 15 minutes after five unknown codes', async () => {
    const persistence = new MemoryPairingPersistence();
    const store = new TransactionalPairingStore(persistence);
    const base = new Date('2026-07-26T12:00:00.000Z');

    for (let attempt = 1; attempt <= 4; attempt += 1) {
      assert.deepEqual(
        await store.claimAtomically({
          codeDigest: `wrong-${attempt}`,
          mountedDeviceAccountId: 'device-1',
          now: base,
          canClaim: async () => true,
        }),
        { status: 'rejected', reason: 'invalid' },
      );
    }
    assert.deepEqual(
      await store.claimAtomically({
        codeDigest: 'wrong-5',
        mountedDeviceAccountId: 'device-1',
        now: base,
        canClaim: async () => true,
      }),
      { status: 'rejected', reason: 'attempts_exhausted' },
    );
    assert.equal(
      persistence.attempts.get('device-1')?.blockedUntil?.toISOString(),
      '2026-07-26T12:15:00.000Z',
    );
  });

  test('does not consume a matching credential for an ineligible account', async () => {
    const persistence = new MemoryPairingPersistence();
    const store = new TransactionalPairingStore(persistence);
    await store.replaceActive(claim('claim-1', 'robot-1', 'digest'));

    const result = await store.claimAtomically({
      codeDigest: 'digest',
      mountedDeviceAccountId: 'owner-1',
      now: new Date('2026-07-26T12:00:00.000Z'),
      canClaim: async () => false,
    });

    assert.deepEqual(result, { status: 'rejected', reason: 'invalid' });
    assert.equal(persistence.claims.get('claim-1')?.consumedAt, null);
  });

  test('rejects Team-member candidates before any pairing transaction write', async () => {
    const persistence = new MemoryPairingPersistence();
    const store = new TransactionalPairingStore(persistence);
    await store.replaceActive(claim('claim-1', 'robot-1', 'digest'));

    const result = await store.claimAtomically({
      codeDigest: 'digest', mountedDeviceAccountId: 'device-1',
      now: new Date('2026-07-26T12:00:00.000Z'), canClaim: async () => false,
    });

    assert.deepEqual(result, { status: 'rejected', reason: 'invalid' });
    assert.equal(persistence.claims.get('claim-1')?.consumedAt, null);
    assert.equal(persistence.mountedAccess.size, 0);
  });

  test('creates mounted access in the same claim transaction', async () => {
    const persistence = new MemoryPairingPersistence();
    const store = new TransactionalPairingStore(persistence);
    await store.replaceActive(claim('claim-1', 'robot-1', 'digest'));

    assert.deepEqual(await store.claimAtomically({
      codeDigest: 'digest',
      mountedDeviceAccountId: 'device-1',
      now: new Date('2026-07-26T12:00:00.000Z'),
      canClaim: async () => true,
    }), { status: 'accepted', robotId: 'robot-1' });
    assert.equal(persistence.mountedAccess.get('robot-1')?.pairingClaimId, 'claim-1');
  });

  test('replaces the mounted account atomically on a later claim', async () => {
    const persistence = new MemoryPairingPersistence();
    const store = new TransactionalPairingStore(persistence);
    await store.replaceActive(claim('claim-1', 'robot-1', 'first'));
    await store.claimAtomically({
      codeDigest: 'first', mountedDeviceAccountId: 'old-device',
      now: new Date('2026-07-26T12:00:00.000Z'), canClaim: async () => true,
    });
    await store.replaceActive(claim('claim-2', 'robot-1', 'second'));

    assert.deepEqual(await store.claimAtomically({
      codeDigest: 'second', mountedDeviceAccountId: 'new-device',
      now: new Date('2026-07-26T12:01:00.000Z'), canClaim: async () => true,
    }), { status: 'accepted', robotId: 'robot-1' });
    assert.deepEqual(persistence.mountedAccess.get('robot-1'), {
      robotId: 'robot-1',
      mountedDeviceAccountId: 'new-device',
      pairingClaimId: 'claim-2',
      createdAt: new Date('2026-07-26T12:00:00.000Z'),
      updatedAt: new Date('2026-07-26T12:01:00.000Z'),
    });
  });

  test('rejects a device already mounted to another robot without consuming the claim', async () => {
    const persistence = new MemoryPairingPersistence();
    const store = new TransactionalPairingStore(persistence);
    await store.replaceActive(claim('claim-1', 'robot-2', 'digest'));
    persistence.mountedAccess.set('robot-1', {
      robotId: 'robot-1', mountedDeviceAccountId: 'device-1', pairingClaimId: 'old',
      createdAt: new Date('2026-07-26T11:00:00.000Z'),
      updatedAt: new Date('2026-07-26T11:00:00.000Z'),
    });

    assert.deepEqual(await store.claimAtomically({
      codeDigest: 'digest', mountedDeviceAccountId: 'device-1',
      now: new Date('2026-07-26T12:00:00.000Z'), canClaim: async () => true,
    }), { status: 'rejected', reason: 'device_already_mounted' });
    assert.equal(persistence.claims.get('claim-1')?.consumedAt, null);
  });

  test('rolls back claim and access when the mounted access write fails', async () => {
    class FailingPersistence extends MemoryPairingPersistence {
      override async createMountedAccess(): Promise<void> {
        throw new Error('mounted access write failed');
      }
    }
    const persistence = new FailingPersistence();
    const store = new TransactionalPairingStore(persistence);
    await store.replaceActive(claim('claim-1', 'robot-1', 'digest'));

    await assert.rejects(
      store.claimAtomically({
        codeDigest: 'digest', mountedDeviceAccountId: 'device-1',
        now: new Date('2026-07-26T12:00:00.000Z'), canClaim: async () => true,
      }),
      /mounted access write failed/,
    );
    assert.equal(persistence.claims.get('claim-1')?.consumedAt, null);
    assert.equal(persistence.mountedAccess.size, 0);
  });
});
