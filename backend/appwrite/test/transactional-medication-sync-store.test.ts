import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  TransactionalMedicationSyncStore,
  type MedicationSyncChangeRecord,
  type MedicationSyncDocumentRecord,
  type MedicationSyncEventRecord,
  type MedicationSyncHelpRequestRecord,
  type MedicationSyncPersistence,
  type MedicationSyncReceiptRecord,
  type MedicationSyncStateRecord,
  type MedicationSyncTransaction,
} from '../src/infrastructure/transactional-medication-sync-store.js';

class MemoryPersistence implements MedicationSyncPersistence {
  documents = new Map<string, MedicationSyncDocumentRecord>();
  events = new Map<string, MedicationSyncEventRecord>();
  helpRequests = new Map<string, MedicationSyncHelpRequestRecord>();
  receipts = new Map<string, MedicationSyncReceiptRecord>();
  states = new Map<string, MedicationSyncStateRecord>();
  changes = new Map<string, MedicationSyncChangeRecord>();
  failChange = false;
  dropChanges = false;

  async transaction<T>(operation: (transaction: MedicationSyncTransaction) => Promise<T>) {
    const snapshot = {
      documents: new Map(this.documents),
      events: new Map(this.events),
      helpRequests: new Map(this.helpRequests),
      receipts: new Map(this.receipts),
      states: new Map(this.states),
      changes: new Map(this.changes),
    };
    const transaction: MedicationSyncTransaction = {
      getDocument: async (robotId, resourceType, resourceId) =>
        this.documents.get(`${robotId}:${resourceType}:${resourceId}`) ?? null,
      saveDocument: async (record) => void this.documents.set(
        `${record.robotId}:${record.resourceType}:${record.resourceId}`,
        record,
      ),
      getEvent: async (robotId, eventId) =>
        this.events.get(`${robotId}:${eventId}`) ?? null,
      createEvent: async (record) => void this.events.set(
        `${record.robotId}:${record.eventId}`,
        record,
      ),
      createHelpRequest: async (record) => void this.helpRequests.set(
        `${record.robotId}:${record.helpRequestId}`,
        record,
      ),
      getReceipt: async (robotId, idempotencyKey) =>
        this.receipts.get(`${robotId}:${idempotencyKey}`) ?? null,
      saveReceipt: async (record) => void this.receipts.set(
        `${record.robotId}:${record.idempotencyKey}`,
        record,
      ),
      getState: async (robotId) => this.states.get(robotId) ?? null,
      saveState: async (record) => void this.states.set(record.robotId, record),
      createChange: async (record) => {
        if (this.failChange) throw new Error('change failed');
        this.changes.set(`${record.robotId}:${record.sequence}`, record);
      },
      listChanges: async (robotId, after, through, limit) => this.dropChanges ? [] : [...this.changes.values()]
        .filter((change) => change.robotId === robotId)
        .filter((change) => change.sequence > after && change.sequence <= through)
        .sort((left, right) => left.sequence - right.sequence)
        .slice(0, limit),
    };
    try {
      return await operation(transaction);
    } catch (error) {
      this.documents = snapshot.documents;
      this.events = snapshot.events;
      this.helpRequests = snapshot.helpRequests;
      this.receipts = snapshot.receipts;
      this.states = snapshot.states;
      this.changes = snapshot.changes;
      throw error;
    }
  }
}

const mutation = {
  robotId: 'robot-1',
  idempotencyKey: 'operation-1',
  operationHash: 'hash-1',
  actorAccountId: 'owner-1',
  actorRole: 'owner' as const,
  now: new Date('2026-07-29T10:00:00Z'),
};

describe('Transactional medication sync store', () => {
  test('versions a document and appends exactly one immutable change', async () => {
    const persistence = new MemoryPersistence();
    const store = new TransactionalMedicationSyncStore(persistence);

    const result = await store.upsertDocument({
      ...mutation,
      resourceType: 'medication',
      resourceId: 'medication-1',
      baseVersion: 0,
      payload: '{"name":"Morning"}',
    });

    assert.deepEqual(result, { status: 'applied', sequence: 1, resourceVersion: 1 });
    assert.equal(persistence.states.get('robot-1')?.highWatermark, 1);
    assert.equal(persistence.documents.get('robot-1:medication:medication-1')?.version, 1);
    assert.deepEqual(
      [...persistence.changes.values()].map(({ sequence, operation, payload }) => ({
        sequence,
        operation,
        payload,
      })),
      [{
        sequence: 1,
        operation: 'upsert',
        payload: JSON.stringify({
          contractVersion: 1, id: 'medication-1', householdId: 'robot-1', name: 'Morning',
          revision: 1, deletedAt: null, updatedAt: '2026-07-29T10:00:00.000Z',
        }),
      }],
    );

    assert.deepEqual(
      await store.upsertDocument({
        ...mutation,
        resourceType: 'medication',
        resourceId: 'medication-1',
        baseVersion: 0,
        payload: '{"name":"Morning"}',
      }),
      { status: 'duplicate', sequence: 1, resourceVersion: 1 },
    );
    assert.equal(persistence.changes.size, 1);
  });

  test('rejects reused idempotency keys and stale resource versions without mutation', async () => {
    const persistence = new MemoryPersistence();
    const store = new TransactionalMedicationSyncStore(persistence);
    await store.upsertDocument({
      ...mutation,
      resourceType: 'schedule',
      resourceId: 'schedule-1',
      baseVersion: 0,
      payload: '{"hour":8}',
    });

    assert.deepEqual(
      await store.upsertDocument({
        ...mutation,
        operationHash: 'changed-hash',
        resourceType: 'schedule',
        resourceId: 'schedule-1',
        baseVersion: 1,
        payload: '{"hour":9}',
      }),
      { status: 'conflict', code: 'operation_id_reused' },
    );
    assert.deepEqual(
      await store.upsertDocument({
        ...mutation,
        idempotencyKey: 'operation-2',
        operationHash: 'hash-2',
        resourceType: 'schedule',
        resourceId: 'schedule-1',
        baseVersion: 0,
        payload: '{"hour":9}',
      }),
      {
        status: 'conflict', code: 'version_conflict', currentVersion: 1,
        currentDocument: {
          robotId: 'robot-1', resourceType: 'schedule', resourceId: 'schedule-1',
          version: 1, archived: false, payload: JSON.stringify({
            contractVersion: 1, id: 'schedule-1', householdId: 'robot-1', hour: 8,
            revision: 1, deletedAt: null, updatedAt: '2026-07-29T10:00:00.000Z',
          }),
          createdAt: mutation.now, createdByAccountId: 'owner-1',
          updatedAt: mutation.now, updatedByAccountId: 'owner-1',
        },
      },
    );
    assert.equal(persistence.changes.size, 1);
  });

  test('scopes idempotency receipts and sequences to the exact robot', async () => {
    const persistence = new MemoryPersistence();
    const store = new TransactionalMedicationSyncStore(persistence);

    const first = await store.appendEvent({
      ...mutation, eventId: 'event-1', eventHash: 'event-hash', kind: 'snoozed',
      doseId: 'dose-1', scheduleId: 'schedule-1', occurredAt: mutation.now, payload: '{}',
    });
    const second = await store.appendEvent({
      ...mutation, robotId: 'robot-2', actorAccountId: 'device-2', actorRole: 'device',
      eventId: 'event-1', eventHash: 'event-hash', kind: 'snoozed',
      doseId: 'dose-1', scheduleId: 'schedule-1', occurredAt: mutation.now, payload: '{}',
    });

    assert.deepEqual(first, { status: 'applied', sequence: 1 });
    assert.deepEqual(second, { status: 'applied', sequence: 1 });
    assert.deepEqual([...persistence.receipts.keys()].sort(), [
      'robot-1:operation-1', 'robot-2:operation-1',
    ]);
  });

  test('archives an existing document as a versioned tombstone', async () => {
    const persistence = new MemoryPersistence();
    const store = new TransactionalMedicationSyncStore(persistence);
    await store.upsertDocument({
      ...mutation,
      resourceType: 'medication',
      resourceId: 'medication-1',
      baseVersion: 0,
      payload: '{"name":"Morning"}',
    });

    assert.deepEqual(
      await store.archiveDocument({
        ...mutation,
        idempotencyKey: 'operation-2',
        operationHash: 'hash-2',
        resourceType: 'medication',
        resourceId: 'medication-1',
        baseVersion: 1,
      }),
      { status: 'applied', sequence: 2, resourceVersion: 2 },
    );
    assert.equal(
      persistence.documents.get('robot-1:medication:medication-1')?.archived,
      true,
    );
    assert.deepEqual(
      [...persistence.changes.values()].at(-1)?.operation,
      'archive',
    );
  });

  test('deduplicates immutable events by event ID and content hash', async () => {
    const persistence = new MemoryPersistence();
    const store = new TransactionalMedicationSyncStore(persistence);
    const first = await store.appendEvent({
      ...mutation,
      eventId: 'event-1',
      eventHash: 'event-hash',
      kind: 'taken_confirmed',
      doseId: 'schedule-1:2026-07-29',
      scheduleId: 'schedule-1',
      occurredAt: new Date('2026-07-28T08:00:00Z'),
      payload: '{"kind":"taken_confirmed"}',
    });

    assert.deepEqual(first, { status: 'applied', sequence: 1 });
    assert.deepEqual(
      await store.appendEvent({
        ...mutation,
        idempotencyKey: 'operation-2',
        operationHash: 'hash-2',
        eventId: 'event-1',
        eventHash: 'event-hash',
        kind: 'taken_confirmed',
        doseId: 'schedule-1:2026-07-29',
        scheduleId: 'schedule-1',
        occurredAt: new Date('2026-07-28T08:00:00Z'),
        payload: '{"kind":"taken_confirmed"}',
      }),
      { status: 'duplicate', sequence: 1 },
    );
    assert.deepEqual(
      await store.appendEvent({
        ...mutation,
        idempotencyKey: 'operation-3',
        operationHash: 'hash-3',
        eventId: 'event-1',
        eventHash: 'changed-event-hash',
        kind: 'skipped',
        doseId: 'schedule-1:2026-07-29',
        scheduleId: 'schedule-1',
        occurredAt: new Date('2026-07-28T08:00:00Z'),
        payload: '{"kind":"skipped"}',
      }),
      { status: 'conflict', code: 'event_id_reused' },
    );
    assert.equal(persistence.events.size, 1);
    assert.equal(persistence.changes.size, 1);
    assert.equal(
      persistence.events.get('robot-1:event-1')?.occurredAt.toISOString(),
      '2026-07-28T08:00:00.000Z',
    );
    assert.equal(
      persistence.events.get('robot-1:event-1')?.receivedAt.toISOString(),
      '2026-07-29T10:00:00.000Z',
    );
  });

  test('opens help from an event without exposing status transitions', async () => {
    const persistence = new MemoryPersistence();
    const store = new TransactionalMedicationSyncStore(persistence);
    await store.appendEvent({
      ...mutation,
      eventId: 'help-1',
      eventHash: 'help-hash',
      kind: 'help_requested',
      doseId: 'dose-1',
      scheduleId: 'schedule-1',
      occurredAt: new Date('2026-07-29T08:00:00Z'),
      payload: '{"kind":"help_requested"}',
    });

    assert.deepEqual(persistence.helpRequests.get('robot-1:help-1'), {
      robotId: 'robot-1', helpRequestId: 'help-1', sourceEventId: 'help-1',
      status: 'open', version: 1, openedAt: mutation.now, openedByAccountId: 'owner-1',
      updatedAt: mutation.now, updatedByAccountId: 'owner-1',
    });
    assert.equal(persistence.changes.size, 1);
  });

  test('rolls back the domain mutation and high watermark when change append fails', async () => {
    const persistence = new MemoryPersistence();
    persistence.failChange = true;
    const store = new TransactionalMedicationSyncStore(persistence);

    await assert.rejects(store.upsertDocument({
      ...mutation,
      resourceType: 'medication',
      resourceId: 'medication-1',
      baseVersion: 0,
      payload: '{}',
    }), /change failed/);

    assert.equal(persistence.documents.size, 0);
    assert.equal(persistence.states.size, 0);
    assert.equal(persistence.receipts.size, 0);
  });

  test('removes reserved fields from document and event payloads', async () => {
    const persistence = new MemoryPersistence();
    const store = new TransactionalMedicationSyncStore(persistence);
    const reserved = {
      contractVersion: 99, id: 'other', householdId: 'other', revision: 99,
      deletedAt: 'other', updatedAt: 'other', actorAccountId: 'other', name: 'Morning',
    };
    await store.upsertDocument({
      ...mutation, resourceType: 'medication', resourceId: 'medication-1', baseVersion: 0,
      payload: JSON.stringify(reserved),
    });
    await store.appendEvent({
      ...mutation, idempotencyKey: 'operation-2', operationHash: 'hash-2', eventId: 'event-1',
      eventHash: 'event-hash', kind: 'snoozed', doseId: 'dose-1', scheduleId: 'schedule-1',
      occurredAt: mutation.now, payload: JSON.stringify(reserved),
    });

    assert.deepEqual(JSON.parse(persistence.documents.values().next().value.payload), {
      contractVersion: 1, id: 'medication-1', householdId: 'robot-1', name: 'Morning',
      revision: 1, deletedAt: null, updatedAt: '2026-07-29T10:00:00.000Z',
    });
    assert.deepEqual(JSON.parse(persistence.events.values().next().value.payload), {
      name: 'Morning', contractVersion: 1, id: 'event-1', householdId: 'robot-1',
      actorAccountId: 'owner-1',
    });
  });

  test('rejects null, arrays, and non-object payloads for documents and events', async () => {
    for (const payload of ['null', '[]', '"text"']) {
      const documentStore = new TransactionalMedicationSyncStore(new MemoryPersistence());
      await assert.rejects(documentStore.upsertDocument({
        ...mutation, resourceType: 'medication', resourceId: 'medication-1', baseVersion: 0, payload,
      }), /Invalid medication sync payload/);
      const eventStore = new TransactionalMedicationSyncStore(new MemoryPersistence());
      await assert.rejects(eventStore.appendEvent({
        ...mutation, eventId: 'event-1', eventHash: 'event-hash', kind: 'snoozed', doseId: 'dose-1',
        scheduleId: 'schedule-1', occurredAt: mutation.now, payload,
      }), /Invalid medication sync payload/);
    }
  });

  test('holds one high-water checkpoint across pull pages', async () => {
    const persistence = new MemoryPersistence();
    const store = new TransactionalMedicationSyncStore(persistence);
    for (let index = 1; index <= 3; index += 1) {
      await store.upsertDocument({
        ...mutation,
        idempotencyKey: `operation-${index}`,
        operationHash: `hash-${index}`,
        resourceType: 'medication',
        resourceId: `medication-${index}`,
        baseVersion: 0,
        payload: `{ "index": ${index} }`,
      });
    }

    const first = await store.pull({ robotId: 'robot-1', cursor: 0, limit: 2 });
    assert.deepEqual(first.changes.map((change) => change.sequence), [1, 2]);
    assert.deepEqual(
      { nextCursor: first.nextCursor, checkpoint: first.checkpoint, complete: first.complete },
      { nextCursor: 2, checkpoint: 3, complete: false },
    );

    await store.upsertDocument({
      ...mutation,
      idempotencyKey: 'operation-4',
      operationHash: 'hash-4',
      resourceType: 'medication',
      resourceId: 'medication-4',
      baseVersion: 0,
      payload: '{}',
    });
    const second = await store.pull({
      robotId: 'robot-1',
      cursor: first.nextCursor,
      checkpoint: first.checkpoint,
      limit: 2,
    });
    assert.deepEqual(second.changes.map((change) => change.sequence), [3]);
    assert.deepEqual(
      { nextCursor: second.nextCursor, checkpoint: second.checkpoint, complete: second.complete },
      { nextCursor: 3, checkpoint: 3, complete: true },
    );
  });

  test('rejects non-integer cursors and limits outside the bounded safe range', async () => {
    const store = new TransactionalMedicationSyncStore(new MemoryPersistence());
    const invalid = [
      { cursor: Number.NaN, limit: 1 },
      { cursor: Number.POSITIVE_INFINITY, limit: 1 },
      { cursor: 0.5, limit: 1 },
      { cursor: Number.MAX_SAFE_INTEGER + 1, limit: 1 },
      { cursor: -1, checkpoint: 0, limit: 1 },
      { cursor: 0, checkpoint: -1, limit: 1 },
      { cursor: 1, checkpoint: 0, limit: 1 },
      { cursor: 0, checkpoint: 0.5, limit: 1 },
      { cursor: 0, limit: 0 },
      { cursor: 0, limit: 101 },
    ];

    for (const request of invalid) {
      await assert.rejects(
        store.pull({ robotId: 'robot-1', ...request }),
        /Invalid medication sync cursor/,
      );
    }
  });

  test('fails closed when persistence omits changes before the checkpoint', async () => {
    const persistence = new MemoryPersistence();
    persistence.states.set('robot-1', { robotId: 'robot-1', highWatermark: 1, updatedAt: new Date() });
    persistence.dropChanges = true;
    await assert.rejects(
      new TransactionalMedicationSyncStore(persistence).pull({ robotId: 'robot-1', cursor: 0, limit: 1 }),
      /did not advance/,
    );
  });
});
