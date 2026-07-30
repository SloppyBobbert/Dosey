import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { describe, test } from 'node:test';
import { AppwriteException } from 'node-appwrite';

import {
  AppwriteMedicationSyncPersistence,
  AppwriteMedicationSyncRowsApi,
  type MedicationSyncRow,
  type MedicationSyncRowsApi,
  type MedicationSyncTable,
} from '../src/infrastructure/appwrite-medication-sync-persistence.js';

class FakeRows implements MedicationSyncRowsApi {
  events: string[] = [];
  rows = new Map<string, MedicationSyncRow>();
  transactions = new Map<string, Map<string, MedicationSyncRow>>();
  commitFailures = 0;
  conflictType: string = 'transaction_conflict';
  rollbackFailures = 0;

  async beginTransaction() {
    const id = `transaction-${this.events.filter((event) => event === 'begin').length + 1}`;
    this.events.push('begin');
    this.transactions.set(id, new Map(this.rows));
    return id;
  }
  async commitTransaction(id: string) {
    this.events.push(`commit:${id}`);
    if (this.commitFailures-- > 0) {
      throw new AppwriteException('conflict', 409, this.conflictType);
    }
    this.rows = new Map(this.transaction(id));
    this.transactions.delete(id);
  }
  async rollbackTransaction(id: string) {
    this.events.push(`rollback:${id}`);
    this.transactions.delete(id);
    if (this.rollbackFailures-- > 0) throw new Error('rollback failed');
  }
  async getRow(table: MedicationSyncTable, id: string, transactionId: string) {
    return this.transaction(transactionId).get(`${table}:${id}`) ?? null;
  }
  async createRow(table: MedicationSyncTable, row: MedicationSyncRow, transactionId: string) {
    this.transaction(transactionId).set(`${table}:${row.$id}`, row);
  }
  async upsertRow(table: MedicationSyncTable, row: MedicationSyncRow, transactionId: string) {
    this.transaction(transactionId).set(`${table}:${row.$id}`, row);
  }
  async listChanges(
    robotId: string, after: number, through: number, limit: number, transactionId: string,
  ) {
    return [...this.transaction(transactionId).entries()]
      .filter(([key, row]) => key.startsWith('changes:') && row.robotId === robotId)
      .map(([, row]) => row)
      .filter((row) => Number(row.sequence) > after && Number(row.sequence) <= through)
      .sort((left, right) => Number(left.sequence) - Number(right.sequence))
      .slice(0, limit);
  }

  private transaction(id: string): Map<string, MedicationSyncRow> {
    const rows = this.transactions.get(id);
    if (rows == null) throw new Error(`Unknown transaction ${id}`);
    return rows;
  }
}

describe('Appwrite medication sync persistence', () => {
  test('maps document, event, receipt, state, and immutable change rows', async () => {
    const rows = new FakeRows();
    const persistence = new AppwriteMedicationSyncPersistence(rows);
    const now = new Date('2026-07-29T10:00:00Z');

    await persistence.transaction(async (transaction) => {
      await transaction.saveDocument({
        robotId: 'robot-1', resourceType: 'medication', resourceId: 'medication-1',
        version: 1, archived: false, payload: '{"name":"Morning"}',
        createdAt: now, createdByAccountId: 'owner-1',
        updatedAt: now, updatedByAccountId: 'owner-1',
      });
      await transaction.createEvent({
        robotId: 'robot-1', eventId: 'event-1', eventHash: 'event-hash',
        kind: 'taken_confirmed', doseId: 'dose-1', scheduleId: 'schedule-1', payload: '{}',
        occurredAt: new Date('2026-07-29T08:00:00Z'), receivedAt: now,
        actorAccountId: 'member-1', sequence: 1,
      });
      await transaction.createHelpRequest({
        robotId: 'robot-1', helpRequestId: 'event-1', sourceEventId: 'event-1',
        status: 'open', version: 1, openedAt: now, openedByAccountId: 'member-1',
        updatedAt: now, updatedByAccountId: 'member-1',
      });
      await transaction.saveReceipt({
        robotId: 'robot-1', idempotencyKey: 'operation-1', operationHash: 'operation-hash',
        sequence: 1, resourceVersion: null, createdAt: now,
      });
      await transaction.saveState({ robotId: 'robot-1', highWatermark: 1, updatedAt: now });
      await transaction.createChange({
        robotId: 'robot-1', sequence: 1, resourceType: 'doseEvent', resourceId: 'event-1',
        resourceVersion: null, operation: 'event', payload: '{}', actorAccountId: 'member-1',
        actorRole: 'member', changedAt: now, idempotencyKey: 'operation-1',
        operationHash: 'operation-hash',
      });

      assert.equal((await transaction.getDocument('robot-1', 'medication', 'medication-1'))?.version, 1);
      assert.equal((await transaction.getEvent('robot-1', 'event-1'))?.occurredAt.toISOString(), '2026-07-29T08:00:00.000Z');
      assert.equal((await transaction.getReceipt('robot-1', 'operation-1'))?.resourceVersion, null);
      assert.equal((await transaction.getState('robot-1'))?.highWatermark, 1);
      assert.deepEqual(
        (await transaction.listChanges('robot-1', 0, 1, 10)).map((change) => change.sequence),
        [1],
      );
    });
  });

  test('rolls back a staged mutation and retries the complete atomic write after a conflict', async () => {
    const rows = new FakeRows();
    rows.commitFailures = 1;
    const delays: number[] = [];
    const persistence = new AppwriteMedicationSyncPersistence(
      rows,
      () => {},
      3,
      async (milliseconds) => void delays.push(milliseconds),
      () => 0.5,
    );
    let attempts = 0;

    const now = new Date('2026-07-29T10:00:00Z');
    await persistence.transaction(async (transaction) => {
      attempts += 1;
      await transaction.saveDocument({
        robotId: 'robot-1', resourceType: 'medication', resourceId: 'medication-1',
        version: 1, archived: false, payload: '{"name":"Morning"}',
        createdAt: now, createdByAccountId: 'owner-1', updatedAt: now,
        updatedByAccountId: 'owner-1',
      });
      await transaction.saveState({ robotId: 'robot-1', highWatermark: 1, updatedAt: now });
      await transaction.createChange({
        robotId: 'robot-1', sequence: 1, resourceType: 'medication',
        resourceId: 'medication-1', resourceVersion: 1, operation: 'upsert',
        payload: '{"name":"Morning"}', actorAccountId: 'owner-1', actorRole: 'owner',
        changedAt: now, idempotencyKey: 'key-1', operationHash: 'hash-1',
      });
      await transaction.saveReceipt({
        robotId: 'robot-1', idempotencyKey: 'key-1', operationHash: 'hash-1',
        sequence: 1, resourceVersion: 1, createdAt: now,
      });
    });

    assert.equal(attempts, 2);
    assert.deepEqual(rows.events, [
      'begin', 'commit:transaction-1', 'rollback:transaction-1',
      'begin', 'commit:transaction-2',
    ]);
    assert.deepEqual(delays, [15]);
    assert.deepEqual([...rows.rows.keys()].sort(), [
      `changes:${rowId('change', 'robot-1', '1')}`,
      `documents:${rowId('document', 'robot-1', 'medication', 'medication-1')}`,
      `receipts:${rowId('receipt', 'robot-1', 'key-1')}`,
      `state:${rowId('state', 'robot-1')}`,
    ].sort());
  });

  test('retries genuine conflicts through the configured maximum and reports rollback failures', async () => {
    const rows = new FakeRows();
    rows.commitFailures = 5;
    rows.rollbackFailures = 1;
    const delays: number[] = [];
    const rollbackErrors: unknown[] = [];
    const persistence = new AppwriteMedicationSyncPersistence(
      rows, (error) => rollbackErrors.push(error), 5,
      async (milliseconds) => void delays.push(milliseconds), () => 0,
    );
    let attempts = 0;

    await assert.rejects(persistence.transaction(async () => {
      attempts += 1;
    }), AppwriteException);

    assert.equal(attempts, 5);
    assert.deepEqual(delays, [10, 20, 40, 80]);
    assert.equal(rollbackErrors.length, 1);
  });

  test('retries row-update conflicts but not arbitrary structural or Appwrite 409 errors', async () => {
    const rows = new FakeRows();
    const delays: number[] = [];
    const persistence = new AppwriteMedicationSyncPersistence(
      rows, () => {}, 5, async (milliseconds) => void delays.push(milliseconds), () => 1,
    );
    rows.commitFailures = 1;
    rows.conflictType = 'row_update_conflict';
    let attempts = 0;

    await persistence.transaction(async () => {
      attempts += 1;
    });

    assert.equal(attempts, 2);
    assert.deepEqual(delays, [21]);

    for (const error of [
      { code: 409 },
      new AppwriteException('other conflict', 409, 'other_conflict'),
    ]) {
      let callbackAttempts = 0;
      await assert.rejects(persistence.transaction(async () => {
        callbackAttempts += 1;
        throw error;
      }));
      assert.equal(callbackAttempts, 1);
    }

    assert.deepEqual(delays, [21]);
  });

  test('returns null only for Appwrite row-not-found errors', async () => {
    const tables = {
      getRow: async () => {
        throw new AppwriteException('not found', 404, 'row_not_found');
      },
    };
    const rows = new AppwriteMedicationSyncRowsApi(tables as never, {
      databaseId: 'database', documentsTableId: 'documents', eventsTableId: 'events',
      helpRequestsTableId: 'helpRequests', receiptsTableId: 'receipts', stateTableId: 'state',
      changesTableId: 'changes',
    });

    assert.equal(await rows.getRow('documents', 'document-1', 'transaction-1'), null);

    const nonRowNotFound = new AppwriteMedicationSyncRowsApi({
      getRow: async () => {
        throw new AppwriteException('other missing', 404, 'table_not_found');
      },
    } as never, {
      databaseId: 'database', documentsTableId: 'documents', eventsTableId: 'events',
      helpRequestsTableId: 'helpRequests', receiptsTableId: 'receipts', stateTableId: 'state',
      changesTableId: 'changes',
    });
    await assert.rejects(
      nonRowNotFound.getRow('documents', 'document-1', 'transaction-1'),
      AppwriteException,
    );
  });

  test('uses bounded exponential backoff jitter and rejects invalid retry limits', async () => {
    const rows = new FakeRows();
    rows.commitFailures = 1;
    const delays: number[] = [];
    const persistence = new AppwriteMedicationSyncPersistence(
      rows, () => {}, 2, async (milliseconds) => void delays.push(milliseconds), () => 1,
    );
    await persistence.transaction(async () => {});
    assert.deepEqual(delays, [21]);
    assert.throws(() => new AppwriteMedicationSyncPersistence(rows, () => {}, 0), /maximumAttempts/);
  });
});

function rowId(...parts: readonly string[]): string {
  return createHash('sha256').update(parts.join('\u0000')).digest('hex').slice(0, 36);
}
