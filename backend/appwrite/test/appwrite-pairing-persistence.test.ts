import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  AppwritePairingPersistence,
  PairingTransactionConflictError,
  type PairingRowsApi,
  type PairingRow,
} from '../src/infrastructure/appwrite-pairing-persistence.js';

class FakeRowsApi implements PairingRowsApi {
  events: string[] = [];
  rows: PairingRow[] = [];

  async beginTransaction() {
    this.events.push('begin');
    return 'transaction-1';
  }

  async commitTransaction(id: string) {
    this.events.push(`commit:${id}`);
  }

  async rollbackTransaction(id: string) {
    this.events.push(`rollback:${id}`);
  }

  async deactivateRobotClaims(robotId: string, transactionId: string) {
    this.events.push(`deactivate:${robotId}:${transactionId}`);
  }

  async createClaim(row: PairingRow, transactionId: string) {
    this.rows.push(row);
    this.events.push(`create:${row.$id}:${transactionId}`);
  }

  async findClaimsByDigest(codeDigest: string, transactionId: string) {
    this.events.push(`find:${codeDigest}:${transactionId}`);
    return this.rows.filter(
      (row) => row.codeDigest === codeDigest && row.active === true,
    );
  }

  async updateClaim(rowId: string, data: PairingRow, transactionId: string) {
    this.events.push(`update:${rowId}:${transactionId}`);
    this.rows = this.rows.map((row) =>
      row.$id === rowId ? { ...row, ...data } : row,
    );
  }

  async getAttempt(deviceAccountId: string, transactionId: string) {
    this.events.push(`attempt:${deviceAccountId}:${transactionId}`);
    return null;
  }

  async upsertAttempt(row: PairingRow, transactionId: string) {
    this.events.push(`upsert-attempt:${row.$id}:${transactionId}`);
  }
}

describe('Appwrite pairing persistence', () => {
  test('commits mapped claim operations in one transaction', async () => {
    const api = new FakeRowsApi();
    const persistence = new AppwritePairingPersistence(api);

    await persistence.transaction(async (transaction) => {
      await transaction.deactivateRobotClaims('robot-1');
      await transaction.createClaim({
        id: 'claim-1',
        robotId: 'robot-1',
        codeDigest: 'digest',
        expiresAt: new Date('2026-07-26T12:10:00.000Z'),
        consumedAt: null,
      });
    });

    assert.deepEqual(api.events, [
      'begin',
      'deactivate:robot-1:transaction-1',
      'create:claim-1:transaction-1',
      'commit:transaction-1',
    ]);
    assert.equal(api.rows[0]?.expiresAt, '2026-07-26T12:10:00.000Z');
    assert.equal(api.rows[0]?.active, true);
  });

  test('rolls back when a staged operation fails', async () => {
    const api = new FakeRowsApi();
    const persistence = new AppwritePairingPersistence(api);

    await assert.rejects(
      persistence.transaction(async () => {
        throw new Error('staging failed');
      }),
      /staging failed/,
    );

    assert.deepEqual(api.events, ['begin', 'rollback:transaction-1']);
  });

  test('rejects duplicate active digests instead of selecting one', async () => {
    const api = new FakeRowsApi();
    api.rows = [
      { $id: 'claim-1', codeDigest: 'digest', active: true },
      { $id: 'claim-2', codeDigest: 'digest', active: true },
    ];
    const persistence = new AppwritePairingPersistence(api);

    await assert.rejects(
      persistence.transaction((transaction) =>
        transaction.findActiveClaimByDigest('digest'),
      ),
      /Multiple active pairing claims/,
    );
  });

  test('maps Appwrite 409 transaction failures to a typed conflict', async () => {
    const api = new FakeRowsApi();
    api.commitTransaction = async () => {
      throw { code: 409 };
    };
    const persistence = new AppwritePairingPersistence(api);

    await assert.rejects(
      persistence.transaction(async () => {}),
      PairingTransactionConflictError,
    );
  });

  test('reports rollback failure while preserving the original error', async () => {
    const api = new FakeRowsApi();
    const rollbackErrors: unknown[] = [];
    api.rollbackTransaction = async () => {
      throw new Error('rollback failed');
    };
    const persistence = new AppwritePairingPersistence(api, (error) => {
      rollbackErrors.push(error);
    });

    await assert.rejects(
      persistence.transaction(async () => {
        throw new Error('operation failed');
      }),
      /operation failed/,
    );
    assert.equal((rollbackErrors[0] as Error).message, 'rollback failed');
  });
});
