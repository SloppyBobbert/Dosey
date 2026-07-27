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

class MemoryPairingPersistence implements PairingPersistence, PairingTransaction {
  claims = new Map<string, PairingClaimRecord>();
  activeClaimIds = new Set<string>();
  attempts = new Map<string, PairingAttemptRecord>();

  async transaction<T>(operation: (transaction: PairingTransaction) => Promise<T>) {
    return operation(this);
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
    });

    const result = await store.claimAtomically({
      codeDigest: 'digest',
      mountedDeviceAccountId: 'device-1',
      now: new Date('2026-07-26T12:00:00.000Z'),
      canClaim: async () => true,
    });

    assert.deepEqual(result, { status: 'rejected', reason: 'consumed' });
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
});
