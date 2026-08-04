import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { describe, test } from 'node:test';
import { AppwriteException } from 'node-appwrite';

import {
  AppwriteMedicationSyncPersistence,
  AppwriteMedicationSyncRowsApi,
  type AppwriteMedicationSyncTableConfiguration,
  type MedicationSyncRow,
  type MedicationSyncRowsApi,
  type MedicationSyncTable,
} from '../src/infrastructure/appwrite-medication-sync-persistence.js';
import type {
  MedicationSyncTerminalConflictRecord,
  MedicationSyncTerminalOccurrenceRecord,
} from '../src/infrastructure/transactional-medication-sync-store.js';
import { TransactionalMedicationSyncStore } from '../src/infrastructure/transactional-medication-sync-store.js';

const tableConfiguration: AppwriteMedicationSyncTableConfiguration = {
  databaseId: 'database',
  documentsTableId: 'documents',
  eventsTableId: 'events',
  helpRequestsTableId: 'helpRequests',
  receiptsTableId: 'receipts',
  stateTableId: 'state',
  changesTableId: 'changes',
  terminalOccurrencesTableId: 'terminal-occurrences',
  terminalConflictsTableId: 'terminal-conflicts',
};

const terminalDates = {
  occurredAt: new Date('2026-08-04T09:00:00.000Z'),
  acceptedAt: new Date('2026-08-04T10:00:00.000Z'),
  incomingOccurredAt: new Date('2026-08-04T11:00:00.000Z'),
  recordedAt: new Date('2026-08-04T12:00:00.000Z'),
};

function terminalOccurrence(
  overrides: Partial<MedicationSyncTerminalOccurrenceRecord> = {},
): MedicationSyncTerminalOccurrenceRecord {
  return {
    robotId: 'robot-1',
    occurrenceId: 'occurrence-1',
    acceptedKind: 'taken_confirmed',
    acceptedEventId: 'accepted-event-1',
    acceptedOperationHash: 'a'.repeat(64),
    acceptedIdempotencyKey: 'accepted-key-1',
    acceptedDeviceId: 'accepted-device-1',
    acceptedActorAccountId: 'accepted-account-1',
    acceptedSequence: Number.MAX_SAFE_INTEGER,
    occurredAt: terminalDates.occurredAt,
    acceptedAt: terminalDates.acceptedAt,
    ...overrides,
  };
}

function terminalConflict(
  overrides: Partial<MedicationSyncTerminalConflictRecord> = {},
): MedicationSyncTerminalConflictRecord {
  return {
    robotId: 'robot-1',
    occurrenceId: 'conflict-occurrence-2',
    conflictCode: 'TERMINAL_OUTCOME_CONFLICT',
    acceptedEventId: 'accepted-event-1',
    acceptedOperationHash: 'a'.repeat(64),
    acceptedKind: 'taken_confirmed',
    acceptedSequence: Number.MAX_SAFE_INTEGER,
    incomingEventId: 'incoming-event-1',
    incomingOperationHash: 'b'.repeat(64),
    incomingKind: 'missed',
    incomingIdempotencyKey: 'incoming-key-1',
    incomingDeviceId: 'incoming-device-1',
    incomingActorAccountId: 'incoming-account-1',
    incomingPayload: '{not parsed}',
    incomingOccurredAt: terminalDates.incomingOccurredAt,
    recordedAt: terminalDates.recordedAt,
    ...overrides,
  };
}

class FakeRows implements MedicationSyncRowsApi {
  events: string[] = [];
  writes: Array<{
    method: 'create' | 'upsert';
    table: MedicationSyncTable;
    row: MedicationSyncRow;
    transactionId: string;
  }> = [];
  rows = new Map<string, MedicationSyncRow>();
  transactions = new Map<string, Map<string, MedicationSyncRow>>();
  commitFailures = 0;
  conflictType: string = 'transaction_conflict';
  rollbackFailures = 0;
  onCommitConflict: (() => Promise<void>) | null = null;

  async beginTransaction() {
    const id = `transaction-${this.events.filter((event) => event === 'begin').length + 1}`;
    this.events.push('begin');
    this.transactions.set(id, new Map(this.rows));
    return id;
  }
  async commitTransaction(id: string) {
    this.events.push(`commit:${id}`);
    if (this.commitFailures-- > 0) {
      await this.onCommitConflict?.();
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
    if (this.transaction(transactionId).has(`${table}:${row.$id}`)) {
      throw new AppwriteException('duplicate row', 409, 'row_update_conflict');
    }
    this.writes.push({ method: 'create', table, row, transactionId });
    this.transaction(transactionId).set(`${table}:${row.$id}`, row);
  }
  async upsertRow(table: MedicationSyncTable, row: MedicationSyncRow, transactionId: string) {
    this.writes.push({ method: 'upsert', table, row, transactionId });
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
        actorRole: 'device', changedAt: now, idempotencyKey: 'operation-1',
        operationHash: 'operation-hash',
      });

      assert.equal((await transaction.getDocument('robot-1', 'medication', 'medication-1'))?.version, 1);
      assert.equal((await transaction.getEvent('robot-1', 'event-1'))?.occurredAt.toISOString(), '2026-07-29T08:00:00.000Z');
      assert.equal((await transaction.getReceipt('robot-1', 'operation-1'))?.resourceVersion, null);
      assert.equal((await transaction.getState('robot-1'))?.highWatermark, 1);
      assert.deepEqual(
        (await transaction.listChanges('robot-1', 0, 1, 10)).map((change) => [change.sequence, change.actorRole]),
        [[1, 'device']],
      );
    });
  });

  test('maps terminal rows with create-only writes and deterministic identities', async () => {
    const rows = new FakeRows();
    const persistence = new AppwriteMedicationSyncPersistence(rows);
    const occurrence = terminalOccurrence();
    const conflict = terminalConflict();

    await persistence.transaction(async (transaction) => {
      await transaction.createTerminalOccurrence(occurrence);
      await transaction.createTerminalConflict(conflict);
      assert.deepEqual(
        await transaction.getTerminalOccurrence(occurrence.robotId, occurrence.occurrenceId),
        occurrence,
      );
      assert.deepEqual(
        await transaction.getTerminalConflict(conflict.robotId, conflict.incomingOperationHash),
        conflict,
      );
      assert.equal(await transaction.getTerminalOccurrence('robot-1', 'absent'), null);
      assert.equal(await transaction.getTerminalConflict('robot-1', 'c'.repeat(64)), null);
    });

    const occurrenceId = rowId('terminalOccurrence', occurrence.robotId, occurrence.occurrenceId);
    const conflictId = rowId('terminalConflict', conflict.robotId, conflict.incomingOperationHash);
    assert.notEqual(conflictId, rowId('terminalConflict', conflict.robotId, conflict.occurrenceId));
    assert.deepEqual(rows.rows.get(`terminalOccurrences:${occurrenceId}`), {
      $id: occurrenceId,
      ...occurrence,
      occurredAt: '2026-08-04T09:00:00.000Z',
      acceptedAt: '2026-08-04T10:00:00.000Z',
    });
    assert.deepEqual(rows.rows.get(`terminalConflicts:${conflictId}`), {
      $id: conflictId,
      ...conflict,
      incomingOccurredAt: '2026-08-04T11:00:00.000Z',
      recordedAt: '2026-08-04T12:00:00.000Z',
    });
    assert.deepEqual(rows.writes.map(({ method, table }) => ({ method, table })), [
      { method: 'create', table: 'terminalOccurrences' },
      { method: 'create', table: 'terminalConflicts' },
    ]);
    assert.equal(rows.writes.some((write) => write.method === 'upsert'), false);
  });

  test('accepts terminal identifiers at their schema limits', async () => {
    const rows = new FakeRows();
    const persistence = new AppwriteMedicationSyncPersistence(rows);
    const identifier = 'i'.repeat(128);
    const occurrenceId = 'o'.repeat(256);
    const occurrence = terminalOccurrence({
      robotId: identifier,
      occurrenceId,
      acceptedEventId: identifier,
      acceptedIdempotencyKey: identifier,
      acceptedDeviceId: identifier,
      acceptedActorAccountId: identifier,
    });
    const conflict = terminalConflict({
      robotId: identifier,
      occurrenceId,
      acceptedEventId: identifier,
      incomingEventId: identifier,
      incomingIdempotencyKey: identifier,
      incomingDeviceId: identifier,
      incomingActorAccountId: identifier,
    });

    await persistence.transaction(async (transaction) => {
      await transaction.createTerminalOccurrence(occurrence);
      await transaction.createTerminalConflict(conflict);
      assert.deepEqual(
        await transaction.getTerminalOccurrence(occurrence.robotId, occurrence.occurrenceId),
        occurrence,
      );
      assert.deepEqual(
        await transaction.getTerminalConflict(conflict.robotId, conflict.incomingOperationHash),
        conflict,
      );
    });

    assert.deepEqual(rows.writes.map(({ method }) => method), ['create', 'create']);
  });

  test('rejects invalid terminal records before writing', async () => {
    const invalidRecords: Array<
      | { method: 'occurrence'; record: MedicationSyncTerminalOccurrenceRecord }
      | { method: 'conflict'; record: MedicationSyncTerminalConflictRecord }
    > = [
      { method: 'occurrence', record: terminalOccurrence({ robotId: ' robot-1 ' }) },
      { method: 'occurrence', record: terminalOccurrence({ robotId: 'r'.repeat(129) }) },
      { method: 'occurrence', record: terminalOccurrence({ occurrenceId: 'o'.repeat(257) }) },
      { method: 'occurrence', record: terminalOccurrence({ acceptedOperationHash: 'bad-hash' }) },
      { method: 'occurrence', record: terminalOccurrence({ acceptedKind: 'other' as never }) },
      { method: 'occurrence', record: terminalOccurrence({ acceptedSequence: 0 }) },
      { method: 'occurrence', record: terminalOccurrence({ acceptedSequence: Number.MAX_SAFE_INTEGER + 1 }) },
      { method: 'occurrence', record: terminalOccurrence({ occurredAt: new Date('invalid') }) },
      { method: 'conflict', record: terminalConflict({ conflictCode: 'OTHER' as never }) },
      { method: 'conflict', record: terminalConflict({ incomingEventId: 'e'.repeat(129) }) },
      { method: 'conflict', record: terminalConflict({ incomingPayload: '' }) },
    ];

    for (const invalid of invalidRecords) {
      const rows = new FakeRows();
      const persistence = new AppwriteMedicationSyncPersistence(rows);
      await assert.rejects(persistence.transaction(async (transaction) => {
        if (invalid.method === 'occurrence') {
          await transaction.createTerminalOccurrence(invalid.record);
        } else {
          await transaction.createTerminalConflict(invalid.record);
        }
      }));
      assert.deepEqual(rows.writes, []);
    }
  });

  test('fails closed for malformed stored terminal rows', async () => {
    const occurrence = terminalOccurrence();
    const conflict = terminalConflict();
    const validOccurrenceRow = terminalOccurrenceRow(occurrence);
    const validConflictRow = terminalConflictRow(conflict);
    const invalidOccurrences: Array<Readonly<Record<string, unknown>>> = [
      { robotId: ' robot-1' },
      { acceptedEventId: 'e'.repeat(129) },
      { occurrenceId: 'o'.repeat(257) },
      { acceptedKind: 'other' },
      { acceptedOperationHash: 'bad-hash' },
      { acceptedSequence: 0 },
      { acceptedSequence: Number.MAX_SAFE_INTEGER + 1 },
      { acceptedSequence: '1' },
      { acceptedSequence: BigInt(1) },
      { occurredAt: 'invalid-date' },
      { $id: 'wrong-id' },
    ];
    const invalidConflicts: Array<Readonly<Record<string, unknown>>> = [
      { conflictCode: 'OTHER' },
      { incomingDeviceId: 'd'.repeat(129) },
      { occurrenceId: 'o'.repeat(257) },
      { incomingKind: 'other' },
      { incomingOperationHash: 'bad-hash' },
      { incomingPayload: '' },
      { recordedAt: 'invalid-date' },
      { $id: 'wrong-id' },
    ];

    for (const mutation of invalidOccurrences) {
      const rows = new FakeRows();
      rows.rows.set(`terminalOccurrences:${validOccurrenceRow.$id}`, { ...validOccurrenceRow, ...mutation });
      await assert.rejects(readTerminalOccurrence(rows, occurrence));
    }
    for (const mutation of invalidConflicts) {
      const rows = new FakeRows();
      rows.rows.set(`terminalConflicts:${validConflictRow.$id}`, { ...validConflictRow, ...mutation });
      await assert.rejects(readTerminalConflict(rows, conflict));
    }

    const rows = new FakeRows();
    rows.rows.set(`terminalOccurrences:${validOccurrenceRow.$id}`, validOccurrenceRow);
    rows.rows.set(`terminalConflicts:${validConflictRow.$id}`, validConflictRow);
    const persistence = new AppwriteMedicationSyncPersistence(rows);
    await persistence.transaction(async (transaction) => {
      assert.equal(
        (await transaction.getTerminalOccurrence(occurrence.robotId, occurrence.occurrenceId))?.acceptedSequence,
        Number.MAX_SAFE_INTEGER,
      );
      assert.equal(
        (await transaction.getTerminalConflict(conflict.robotId, conflict.incomingOperationHash))?.acceptedSequence,
        Number.MAX_SAFE_INTEGER,
      );
    });
  });

  test('routes terminal rows to their configured physical tables', async () => {
    const calls: unknown[] = [];
    const rows = new AppwriteMedicationSyncRowsApi({
      async createRow(input: unknown) {
        calls.push(input);
      },
    } as never, {
      ...tableConfiguration,
      terminalOccurrencesTableId: 'physical-terminal-occurrences',
      terminalConflictsTableId: 'physical-terminal-conflicts',
    });
    const occurrenceRow = terminalOccurrenceRow(terminalOccurrence());
    const conflictRow = terminalConflictRow(terminalConflict());

    await rows.createRow('terminalOccurrences', occurrenceRow, 'transaction-1');
    await rows.createRow('terminalConflicts', conflictRow, 'transaction-2');

    assert.deepEqual(calls, [
      {
        databaseId: 'database',
        tableId: 'physical-terminal-occurrences',
        rowId: occurrenceRow.$id,
        data: withoutId(occurrenceRow),
        transactionId: 'transaction-1',
      },
      {
        databaseId: 'database',
        tableId: 'physical-terminal-conflicts',
        rowId: conflictRow.$id,
        data: withoutId(conflictRow),
        transactionId: 'transaction-2',
      },
    ]);
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

  test('retries terminal outcomes as one callback without partial artifacts or extra sequences', async () => {
    const rows = new FakeRows();
    rows.commitFailures = 1;
    const persistence = new AppwriteMedicationSyncPersistence(rows, () => {}, 2, async () => {}, () => 0);
    const store = new TransactionalMedicationSyncStore(persistence);
    const input = terminalInput();

    assert.deepEqual(await store.recordTerminalOutcome(input), { status: 'applied', sequence: 1 });
    assert.equal(rows.rows.size, 5);
    assert.equal((await terminalState(rows))?.highWatermark, 1);

    assert.deepEqual(await store.recordTerminalOutcome(input), { status: 'duplicate', sequence: 1 });
    assert.equal(rows.rows.size, 5);
  });

  test('retries a losing terminal winner as a duplicate after whole-callback contention', async () => {
    const rows = new FakeRows();
    rows.commitFailures = 1;
    const persistence = new AppwriteMedicationSyncPersistence(rows, () => {}, 2, async () => {}, () => 0);
    const store = new TransactionalMedicationSyncStore(persistence);
    const input = terminalInput();
    rows.onCommitConflict = async () => {
      rows.onCommitConflict = null;
      await new TransactionalMedicationSyncStore(
        new AppwriteMedicationSyncPersistence(rows),
      ).recordTerminalOutcome(input);
    };

    assert.deepEqual(await store.recordTerminalOutcome(input), { status: 'duplicate', sequence: 1 });
    assert.equal(rows.rows.size, 5);
  });

  test('records a taken conflict after a skipped winner commits during callback retry', async () => {
    const rows = new FakeRows();
    rows.commitFailures = 1;
    const persistence = new AppwriteMedicationSyncPersistence(
      rows,
      () => {},
      2,
      async () => {},
      () => 0,
    );
    const outerTaken = terminalInput();
    const winnerSkipped = terminalInput({
      eventId: 'skipped-event',
      kind: 'skipped',
      idempotencyKey: 'skipped-key',
      operationHash: 'b'.repeat(64),
      deviceId: 'skipped-device',
    });
    rows.onCommitConflict = async () => {
      rows.onCommitConflict = null;
      await new TransactionalMedicationSyncStore(
        new AppwriteMedicationSyncPersistence(rows),
      ).recordTerminalOutcome(winnerSkipped);
    };

    assert.deepEqual(
      await new TransactionalMedicationSyncStore(persistence).recordTerminalOutcome(outerTaken),
      {
        status: 'needs_review',
        code: 'TERMINAL_OUTCOME_CONFLICT',
        acceptedSequence: 1,
      },
    );
    assert.equal((await terminalState(rows))?.highWatermark, 1);
    assert.equal(rows.rows.size, 6);
    assert.ok(rows.rows.has(`events:${rowId('event', 'robot-1', 'skipped-event')}`));
    assert.ok(rows.rows.has(`changes:${rowId('change', 'robot-1', '1')}`));
    assert.ok(rows.rows.has(`receipts:${rowId('receipt', 'robot-1', 'skipped-key')}`));
    assert.ok(rows.rows.has(`terminalOccurrences:${rowId('terminalOccurrence', 'robot-1', 'occurrence-1')}`));
    assert.equal(rows.rows.has(`events:${rowId('event', 'robot-1', 'event-1')}`), false);
    assert.equal(rows.rows.has(`receipts:${rowId('receipt', 'robot-1', 'key-1')}`), false);
    const conflict = await new AppwriteMedicationSyncPersistence(rows).transaction(
      (transaction) => transaction.getTerminalConflict('robot-1', outerTaken.operationHash),
    );
    assert.deepEqual(conflict, {
      robotId: 'robot-1',
      occurrenceId: 'occurrence-1',
      conflictCode: 'TERMINAL_OUTCOME_CONFLICT',
      acceptedEventId: 'skipped-event',
      acceptedOperationHash: winnerSkipped.operationHash,
      acceptedKind: 'skipped',
      acceptedSequence: 1,
      incomingEventId: outerTaken.eventId,
      incomingOperationHash: outerTaken.operationHash,
      incomingKind: 'taken_confirmed',
      incomingIdempotencyKey: outerTaken.idempotencyKey,
      incomingDeviceId: outerTaken.deviceId,
      incomingActorAccountId: outerTaken.actorAccountId,
      incomingPayload: outerTaken.payload,
      incomingOccurredAt: outerTaken.occurredAt,
      recordedAt: outerTaken.now,
    });
  });

  test('records one durable competing-kind conflict and reuses an identical conflict row', async () => {
    const rows = new FakeRows();
    const store = new TransactionalMedicationSyncStore(new AppwriteMedicationSyncPersistence(rows));
    await store.recordTerminalOutcome(terminalInput());
    const competing = terminalInput({
      eventId: 'event-2', kind: 'skipped', idempotencyKey: 'key-2', operationHash: 'b'.repeat(64),
    });

    assert.deepEqual(await store.recordTerminalOutcome(competing), {
      status: 'needs_review', code: 'TERMINAL_OUTCOME_CONFLICT', acceptedSequence: 1,
    });
    assert.deepEqual(await store.recordTerminalOutcome(competing), {
      status: 'needs_review', code: 'TERMINAL_OUTCOME_CONFLICT', acceptedSequence: 1,
    });
    assert.equal([...rows.rows.keys()].filter((key) => key.startsWith('terminalConflicts:')).length, 1);
    assert.equal((await terminalState(rows))?.highWatermark, 1);
  });

  test('creates one conflict row when identical competing terminal callbacks race', async () => {
    const rows = new FakeRows();
    const seed = new TransactionalMedicationSyncStore(new AppwriteMedicationSyncPersistence(rows));
    await seed.recordTerminalOutcome(terminalInput());
    rows.commitFailures = 1;
    const persistence = new AppwriteMedicationSyncPersistence(rows, () => {}, 2, async () => {}, () => 0);
    const competing = terminalInput({
      eventId: 'event-2', kind: 'skipped', idempotencyKey: 'key-2', operationHash: 'b'.repeat(64),
    });
    rows.onCommitConflict = async () => {
      rows.onCommitConflict = null;
      await new TransactionalMedicationSyncStore(
        new AppwriteMedicationSyncPersistence(rows),
      ).recordTerminalOutcome(competing);
    };

    assert.deepEqual(await new TransactionalMedicationSyncStore(persistence).recordTerminalOutcome(competing), {
      status: 'needs_review', code: 'TERMINAL_OUTCOME_CONFLICT', acceptedSequence: 1,
    });
    assert.equal([...rows.rows.keys()].filter((key) => key.startsWith('terminalConflicts:')).length, 1);
  });

  test('leaves no terminal artifacts when callback conflicts are exhausted', async () => {
    const rows = new FakeRows();
    rows.commitFailures = 2;
    const store = new TransactionalMedicationSyncStore(
      new AppwriteMedicationSyncPersistence(rows, () => {}, 2, async () => {}, () => 0),
    );

    await assert.rejects(store.recordTerminalOutcome(terminalInput()), AppwriteException);
    assert.equal(rows.rows.size, 0);
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
    const rows = new AppwriteMedicationSyncRowsApi(tables as never, tableConfiguration);

    assert.equal(await rows.getRow('documents', 'document-1', 'transaction-1'), null);

    const nonRowNotFound = new AppwriteMedicationSyncRowsApi({
      getRow: async () => {
        throw new AppwriteException('other missing', 404, 'table_not_found');
      },
    } as never, tableConfiguration);
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

function terminalOccurrenceRow(record: MedicationSyncTerminalOccurrenceRecord): MedicationSyncRow {
  return {
    $id: rowId('terminalOccurrence', record.robotId, record.occurrenceId),
    ...record,
    occurredAt: record.occurredAt.toISOString(),
    acceptedAt: record.acceptedAt.toISOString(),
  };
}

function terminalConflictRow(record: MedicationSyncTerminalConflictRecord): MedicationSyncRow {
  return {
    $id: rowId('terminalConflict', record.robotId, record.incomingOperationHash),
    ...record,
    incomingOccurredAt: record.incomingOccurredAt.toISOString(),
    recordedAt: record.recordedAt.toISOString(),
  };
}

async function readTerminalOccurrence(
  rows: FakeRows,
  record: MedicationSyncTerminalOccurrenceRecord,
): Promise<void> {
  const persistence = new AppwriteMedicationSyncPersistence(rows);
  await persistence.transaction(async (transaction) => {
    await transaction.getTerminalOccurrence(record.robotId, record.occurrenceId);
  });
}

async function readTerminalConflict(
  rows: FakeRows,
  record: MedicationSyncTerminalConflictRecord,
): Promise<void> {
  const persistence = new AppwriteMedicationSyncPersistence(rows);
  await persistence.transaction(async (transaction) => {
    await transaction.getTerminalConflict(record.robotId, record.incomingOperationHash);
  });
}

function withoutId(row: MedicationSyncRow): Record<string, unknown> {
  const { $id: _, ...data } = row;
  return data;
}

function terminalInput(overrides: Partial<{
  robotId: string;
  occurrenceId: string;
  eventId: string;
  kind: 'taken_confirmed' | 'skipped';
  scheduleId: string;
  idempotencyKey: string;
  operationHash: string;
  deviceId: string;
  actorAccountId: string;
  occurredAt: Date;
  payload: string;
  now: Date;
}> = {}) {
  const input = {
    robotId: 'robot-1', occurrenceId: 'occurrence-1', eventId: 'event-1',
    kind: 'taken_confirmed' as const, scheduleId: 'schedule-1', idempotencyKey: 'key-1',
    operationHash: 'a'.repeat(64), deviceId: 'device-1', actorAccountId: 'account-1',
    occurredAt: new Date('2026-08-04T08:00:00.000Z'), ...overrides,
  };
  return {
    ...input,
    payload: overrides.payload ?? JSON.stringify({
      kind: input.kind,
      occurredAt: input.occurredAt.toISOString(),
      occurrence: {
        occurrenceId: input.occurrenceId,
        scheduleId: input.scheduleId,
      },
    }),
    now: overrides.now ?? new Date('2026-08-04T10:00:00.000Z'),
  };
}

async function terminalState(rows: FakeRows): Promise<{ highWatermark: number } | null> {
  const persistence = new AppwriteMedicationSyncPersistence(rows);
  return persistence.transaction((transaction) => transaction.getState('robot-1'));
}
