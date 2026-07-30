import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  AppwriteMedicationSyncPersistence,
  type MedicationSyncRow,
  type MedicationSyncRowsApi,
  type MedicationSyncTable,
} from '../src/infrastructure/appwrite-medication-sync-persistence.js';

class FakeRows implements MedicationSyncRowsApi {
  events: string[] = [];
  rows = new Map<string, MedicationSyncRow>();
  transactions = new Map<string, Map<string, MedicationSyncRow>>();
  commitFailures = 0;

  async beginTransaction() {
    const id = `transaction-${this.events.filter((event) => event === 'begin').length + 1}`;
    this.events.push('begin');
    this.transactions.set(id, new Map(this.rows));
    return id;
  }
  async commitTransaction(id: string) {
    this.events.push(`commit:${id}`);
    if (this.commitFailures-- > 0) throw { code: 409 };
    this.rows = new Map(this.transaction(id));
    this.transactions.delete(id);
  }
  async rollbackTransaction(id: string) {
    this.events.push(`rollback:${id}`);
    this.transactions.delete(id);
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
        actorRole: 'member', changedAt: now, operationId: 'operation-1',
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
        changedAt: now, operationId: 'key-1', operationHash: 'hash-1',
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
    assert.equal(rows.rows.size, 4);
    assert.equal([...rows.rows.keys()].filter((key) => key.startsWith('changes:')).length, 1);
  });
});
