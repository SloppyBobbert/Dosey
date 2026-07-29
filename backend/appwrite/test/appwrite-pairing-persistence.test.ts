import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  AppwritePairingRowsApi,
  AppwritePairingPersistence,
  PairingTransactionConflictError,
  type PairingRowsApi,
  type PairingRow,
} from '../src/infrastructure/appwrite-pairing-persistence.js';
import type { TablesDB } from 'node-appwrite';

class FakeRowsApi implements PairingRowsApi {
  events: string[] = [];
  rows: PairingRow[] = [];
  mountedRobotRow: PairingRow | null = null;
  mountedDeviceRows: PairingRow[] = [];

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

  async findMountedAccessByDevice(deviceAccountId: string, transactionId: string) {
    this.events.push(`mounted-device:${deviceAccountId}:${transactionId}`);
    return this.mountedDeviceRows;
  }

  async getMountedAccessByRobot(robotId: string, transactionId: string) {
    this.events.push(`mounted-robot:${robotId}:${transactionId}`);
    return this.mountedRobotRow;
  }

  async createMountedAccess(row: PairingRow, transactionId: string) {
    this.events.push(`create-mounted:${row.$id}:${transactionId}`);
  }

  async updateMountedAccess(rowId: string, data: PairingRow, transactionId: string) {
    this.events.push(`update-mounted:${rowId}:${transactionId}`);
  }
}

describe('Appwrite pairing persistence', () => {
  test('uses the SDK limit of two for duplicate mounted-access lookup', async () => {
    let queryStrings: readonly string[] | undefined;
    const tables = {
      listRows: async (input: { queries: readonly string[] }) => {
        queryStrings = input.queries;
        return { rows: [{
          $id: 'robot-1', robotId: 'robot-1', mountedDeviceAccountId: 'device-1',
          pairingClaimId: 'claim-1', createdAt: '2026-07-26T12:00:00.000Z',
          updatedAt: '2026-07-26T12:00:00.000Z',
        }] };
      },
    } as unknown as TablesDB;
    const rows = new AppwritePairingRowsApi(tables, {
      databaseId: 'database-1',
      pairingClaimsTableId: 'claims',
      pairingAttemptsTableId: 'attempts',
      mountedRobotAccessTableId: 'mounted-access',
    });

    await rows.findMountedAccessByDevice('device-1', 'transaction-1');

    assert.deepEqual(queryStrings, [
      '{"method":"equal","attribute":"mountedDeviceAccountId","values":["device-1"]}',
      '{"method":"limit","values":[2]}',
    ]);
  });

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
    assert.equal(api.rows[0]?.failedAttempts, 0);
  });

  test('stages mounted access reads and writes in the claim transaction', async () => {
    const api = new FakeRowsApi();
    const persistence = new AppwritePairingPersistence(api);

    await persistence.transaction(async (transaction) => {
      assert.deepEqual(await transaction.findMountedAccessByDevice('device-1'), []);
      assert.equal(await transaction.getMountedAccessByRobot('robot-1'), null);
      await transaction.createMountedAccess({
        robotId: 'robot-1',
        mountedDeviceAccountId: 'device-1',
        pairingClaimId: 'claim-1',
        createdAt: new Date('2026-07-26T12:00:00.000Z'),
        updatedAt: new Date('2026-07-26T12:00:00.000Z'),
      });
    });

    assert.deepEqual(api.events, [
      'begin',
      'mounted-device:device-1:transaction-1',
      'mounted-robot:robot-1:transaction-1',
      'create-mounted:robot-1:transaction-1',
      'commit:transaction-1',
    ]);
  });

  test('rejects a mounted access row with a mismatched row ID during mapping', async () => {
    const api = new FakeRowsApi();
    api.mountedRobotRow = {
      $id: 'robot-2', robotId: 'robot-1', mountedDeviceAccountId: 'device-1',
      pairingClaimId: 'claim-1', createdAt: '2026-07-26T12:00:00.000Z',
      updatedAt: '2026-07-26T12:00:00.000Z',
    };
    const persistence = new AppwritePairingPersistence(api);

    await assert.rejects(
      persistence.transaction((transaction) => transaction.getMountedAccessByRobot('robot-1')),
      /row ID/,
    );

    const deviceApi = new FakeRowsApi();
    deviceApi.mountedDeviceRows = [{
      $id: 'robot-1', robotId: 'robot-1', mountedDeviceAccountId: 'other-device',
      pairingClaimId: 'claim-1', createdAt: '2026-07-26T12:00:00.000Z',
      updatedAt: '2026-07-26T12:00:00.000Z',
    }];
    await assert.rejects(
      new AppwritePairingPersistence(deviceApi).transaction((transaction) =>
        transaction.findMountedAccessByDevice('device-1'),
      ),
      /requested account/,
    );
  });

  test('resolves transaction conflicts from authoritative post-conflict rows', async () => {
    const deviceRace = new FakeRowsApi();
    deviceRace.mountedDeviceRows = [{
      $id: 'robot-2', robotId: 'robot-2', mountedDeviceAccountId: 'device-1',
      pairingClaimId: 'other-claim', createdAt: '2026-07-26T12:00:00.000Z',
      updatedAt: '2026-07-26T12:00:00.000Z',
    }];
    const persistence = new AppwritePairingPersistence(deviceRace);
    assert.equal(await persistence.resolveClaimConflict({
      codeDigest: 'digest', robotId: 'robot-1', mountedDeviceAccountId: 'device-1',
    }), 'device_already_mounted');

    const consumed = new FakeRowsApi();
    consumed.rows = [{
      $id: 'claim-1', robotId: 'robot-1', codeDigest: 'digest', active: true,
      expiresAt: '2026-07-26T12:10:00.000Z', consumedAt: '2026-07-26T12:01:00.000Z',
      mountedDeviceAccountId: 'other-device',
    }];
    assert.equal(await new AppwritePairingPersistence(consumed).resolveClaimConflict({
      codeDigest: 'digest', robotId: 'robot-1', mountedDeviceAccountId: 'device-1',
    }), 'consumed');

    const unknown = new FakeRowsApi();
    unknown.rows = [{
      $id: 'claim-1', robotId: 'robot-1', codeDigest: 'digest', active: true,
      expiresAt: '2026-07-26T12:10:00.000Z', consumedAt: null,
    }];
    assert.equal(await new AppwritePairingPersistence(unknown).resolveClaimConflict({
      codeDigest: 'digest', robotId: 'robot-1', mountedDeviceAccountId: 'device-1',
    }), 'unknown');
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
