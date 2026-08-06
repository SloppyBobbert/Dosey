import assert from 'node:assert/strict';
import {describe, test} from 'node:test';

import {canonicalMedicationSyncJson, parseDoseEvent, parseMutation, type MedicationSyncActor, type Mutation} from '../src/domain/medication-sync-contract.js';
import {
  TransactionalTerminalLedgerStore,
  TerminalLedgerStoredEvidenceError,
  type TerminalLedgerChange,
  type TerminalLedgerConflict,
  type TerminalLedgerPersistence,
  type TerminalLedgerRow,
  type TerminalLedgerState,
  type TerminalLedgerTransaction,
} from '../src/infrastructure/transactional-terminal-ledger-store.js';

class MemoryPersistence implements TerminalLedgerPersistence {
  accepted = new Map<string, TerminalLedgerRow>();
  idempotency = new Map<string, TerminalLedgerRow>();
  events = new Map<string, TerminalLedgerRow>();
  conflicts = new Map<string, TerminalLedgerConflict>();
  changes = new Map<string, TerminalLedgerChange>();
  states = new Map<string, TerminalLedgerState>();
  writes: string[] = [];
  failAfter: number | null = null;
  actualOutcome: 'committed' | 'not_committed' = 'committed';
  reportedOutcome: 'committed' | 'not_committed' | 'indeterminate' = 'committed';
  observedStatus: 'pending' | 'committing' | undefined;
  private queue = Promise.resolve();

  async transaction<T>(operation: (transaction: TerminalLedgerTransaction) => Promise<T>) {
    const prior = this.queue;
    let release!: () => void;
    this.queue = new Promise<void>((resolve) => { release = resolve; });
    await prior;
    const staged = {
      accepted: new Map(this.accepted), idempotency: new Map(this.idempotency),
      events: new Map(this.events), conflicts: new Map(this.conflicts),
      changes: new Map(this.changes), states: new Map(this.states), writes: [] as string[],
    };
    let stages = 0;
    const stage = (name: string) => {
      stages += 1;
      if (this.failAfter === stages) throw new Error(`failed after ${name}`);
      staged.writes.push(name);
    };
    const transaction: TerminalLedgerTransaction = {
      getAcceptedOccurrence: async (robotId, occurrenceId) => staged.accepted.get(`${robotId}:${occurrenceId}`) ?? null,
      getIdempotency: async (robotId, idempotencyKey) => staged.idempotency.get(`${robotId}:${idempotencyKey}`) ?? null,
      getEvent: async (robotId, eventId) => staged.events.get(`${robotId}:${eventId}`) ?? null,
      getConflict: async (id) => staged.conflicts.get(id) ?? null,
      getState: async (robotId) => staged.states.get(robotId) ?? null,
      stageAccepted: async (row) => {
        stage('accepted'); staged.accepted.set(`${row.robotId}:${row.occurrenceId}`, row);
        staged.idempotency.set(`${row.robotId}:${row.idempotencyKey}`, row);
        staged.events.set(`${row.robotId}:${row.eventId}`, row);
      },
      stageChange: async (row) => { stage('change'); staged.changes.set(`${row.robotId}:${row.sequence}`, row); },
      stageState: async (row) => { stage('state'); staged.states.set(row.robotId, row); },
      stageConflict: async (row) => { stage('conflict'); staged.conflicts.set(row.id, row); },
    };
    try {
      const value = await operation(transaction);
      if (this.reportedOutcome === 'indeterminate') {
        if (this.actualOutcome === 'committed') this.publish(staged);
        return {
          outcome: 'indeterminate' as const,
          transactionId: 'transaction-1',
          ...(this.observedStatus === undefined ? {} : {observedStatus: this.observedStatus}),
        };
      }
      if (this.actualOutcome !== 'committed' || this.reportedOutcome === 'not_committed') {
        return {outcome: 'not_committed' as const, status: 'rolled_back' as const};
      }
      this.publish(staged);
      return {outcome: 'committed' as const, value};
    } catch (error) {
      return {outcome: 'not_committed' as const, status: 'failed' as const, error};
    } finally { release(); }
  }

  private publish(staged: {accepted: Map<string, TerminalLedgerRow>; idempotency: Map<string, TerminalLedgerRow>; events: Map<string, TerminalLedgerRow>; conflicts: Map<string, TerminalLedgerConflict>; changes: Map<string, TerminalLedgerChange>; states: Map<string, TerminalLedgerState>; writes: string[]}) {
    this.accepted = staged.accepted; this.idempotency = staged.idempotency; this.events = staged.events;
    this.conflicts = staged.conflicts; this.changes = staged.changes; this.states = staged.states;
    this.writes.push(...staged.writes);
  }
}

const actor: MedicationSyncActor = {
  accountId: 'account-1', authority: 'patient_device', registeredDeviceId: 'device-1', role: null,
};
const otherActor: MedicationSyncActor = {
  accountId: 'account-2', authority: 'patient_device', registeredDeviceId: 'device-1', role: null,
};

function mutation(overrides: Record<string, unknown> = {}): Mutation {
  const occurrence = {
    contractVersion: 1, occurrenceId: 'schedule-1:1:2026-08-01T08:00:00.000Z', scheduleId: 'schedule-1',
    scheduleRevision: 1, scheduledAt: '2026-08-01T08:00:00Z', localDate: '2026-08-01', timezoneId: 'UTC',
  };
  return parseMutation({
    contractVersion: 1, mutationId: 'event-1', deviceId: 'device-1', idempotencyKey: 'idempotency-1',
    entityType: 'dose_event', operation: 'append', entityId: 'event-1', baseRevision: null,
    payload: {medicationId: 'medication-1', occurrence, kind: 'taken_confirmed', occurredAt: '2026-08-01T08:01:00Z'},
    ...overrides,
  });
}

function input(overrides: Record<string, unknown> = {}) {
  return {robotId: 'robot-1', mutation: mutation(), actor, now: new Date('2026-08-01T08:02:00Z'), ...overrides};
}

describe('Transactional terminal ledger store', () => {
  test('maps only permanent persistence evidence failures to malformed stored rows', async () => {
    for (const error of [new TerminalLedgerStoredEvidenceError('bad row'), new Error('network')]) {
      const persistence: TerminalLedgerPersistence = {
        transaction: async () => ({outcome: 'not_committed', status: 'failed', error}),
      };
      const result = await new TransactionalTerminalLedgerStore(persistence).accept(input());
      assert.deepEqual(result, error instanceof TerminalLedgerStoredEvidenceError
        ? {status: 'rejected', code: 'malformed_stored_row'}
        : {status: 'retryable_failure', transactionStatus: 'failed'});
    }
  });
  test('accepts Taken and Skipped as immutable terminal ledger outcomes', async () => {
    const persistence = new MemoryPersistence();
    const store = new TransactionalTerminalLedgerStore(persistence);
    assert.equal((await store.accept(input())).status, 'applied');
    assert.equal((await store.accept(input({mutation: mutation({mutationId: 'event-2', entityId: 'event-2', idempotencyKey: 'idempotency-2', payload: {...mutation().payload, kind: 'skipped', occurrence: {...mutation().payload.occurrence, occurrenceId: 'schedule-1:1:2026-08-02T08:00:00.000Z', scheduledAt: '2026-08-02T08:00:00Z', localDate: '2026-08-02'}}})}))).status, 'applied');
    assert.equal(persistence.accepted.size, 2);
    assert.equal(persistence.changes.size, 2);
    assert.equal(persistence.states.get('robot-1')?.highWatermark, 2);
    assert.deepEqual(persistence.writes.filter((write) => write.includes('inventory') || write.includes('receipt')), []);
  });

  test('uses entityId as the event identity when mutationId differs', async () => {
    const persistence = new MemoryPersistence();
    const result = await new TransactionalTerminalLedgerStore(persistence).accept(input({
      mutation: mutation({mutationId: 'mutation-1', entityId: 'event-1'}),
    }));
    assert.equal(result.status, 'applied');
    assert.equal(persistence.accepted.values().next().value.eventId, 'event-1');
    assert.equal(persistence.accepted.values().next().value.id.length, 36);
  });

  test('classifies valid records from another authorized actor by identity and occurrence', async () => {
    const persistence = new MemoryPersistence(); const store = new TransactionalTerminalLedgerStore(persistence);
    await store.accept(input());
    assert.deepEqual(await store.accept(input({actor: otherActor})), {status: 'rejected', code: 'idempotency_reused'});
    assert.equal((await store.accept(input({actor: otherActor, mutation: mutation({mutationId: 'event-2', entityId: 'event-2', idempotencyKey: 'idempotency-2', payload: {...mutation().payload, kind: 'skipped'}})}))).status, 'needs_review');
    assert.deepEqual(await store.accept(input({actor: otherActor, mutation: mutation({mutationId: 'other-mutation', entityId: 'event-1', idempotencyKey: 'idempotency-3'})})), {status: 'rejected', code: 'event_id_reused'});
  });

  test('rejects unsupported, malformed, incoherent, and unverified identity input before a transaction', async () => {
    const persistence = new MemoryPersistence();
    const store = new TransactionalTerminalLedgerStore(persistence);
    for (const value of [
      input({mutation: mutation({payload: {...mutation().payload, kind: 'missed'}})}),
      input({mutation: {...mutation(), entityType: 'medication'} as Mutation}),
      input({mutation: mutation({deviceId: 'other-device'})}),
      input({mutation: {...mutation(), payload: {...mutation().payload, occurrence: {...mutation().payload.occurrence, localDate: '2026-08-02'}}} as Mutation}),
    ]) assert.equal((await store.accept(value)).status, 'rejected');
    assert.equal(persistence.writes.length, 0);
  });

  test('returns exact canonical replay as a zero-write duplicate', async () => {
    const persistence = new MemoryPersistence(); const store = new TransactionalTerminalLedgerStore(persistence);
    const first = await store.accept(input()); const writes = persistence.writes.length;
    const replay = await store.accept(input());
    assert.equal(first.status, 'applied'); assert.deepEqual(replay, {status: 'duplicate', sequence: 1});
    assert.equal(persistence.writes.length, writes);
  });

  test('records one needs-review conflict for changed outcomes after identity reuse checks', async () => {
    const persistence = new MemoryPersistence(); const store = new TransactionalTerminalLedgerStore(persistence);
    await store.accept(input());
    const changed = input({mutation: mutation({mutationId: 'event-2', entityId: 'event-2', idempotencyKey: 'idempotency-2', payload: {...mutation().payload, occurredAt: '2026-08-01T08:03:00Z'}})});
    assert.equal((await store.accept(changed)).status, 'needs_review');
    assert.equal((await store.accept(changed)).status, 'needs_review');
    assert.equal(persistence.conflicts.size, 1); assert.equal(persistence.accepted.size, 1); assert.equal(persistence.changes.size, 1);
    const opposite = input({mutation: mutation({mutationId: 'event-3', entityId: 'event-3', idempotencyKey: 'idempotency-3', payload: {...mutation().payload, kind: 'skipped'}})});
    assert.equal((await store.accept(opposite)).status, 'needs_review');
    assert.equal(persistence.conflicts.size, 2);
    const identityReuse = input({mutation: mutation({mutationId: 'event-4', entityId: 'event-4', idempotencyKey: 'idempotency-1', payload: {...mutation().payload, kind: 'skipped'}})});
    assert.deepEqual(await store.accept(identityReuse), {status: 'rejected', code: 'idempotency_reused'});
  });

  test('fails closed for cross-occurrence idempotency or event reuse and malformed stored rows', async () => {
    const persistence = new MemoryPersistence(); const store = new TransactionalTerminalLedgerStore(persistence);
    await store.accept(input());
    const secondOccurrence = {...mutation().payload.occurrence, occurrenceId: 'schedule-1:1:2026-08-02T08:00:00.000Z', scheduledAt: '2026-08-02T08:00:00Z', localDate: '2026-08-02'};
    assert.deepEqual(await store.accept(input({mutation: mutation({mutationId: 'event-2', entityId: 'event-2', payload: {...mutation().payload, occurrence: secondOccurrence}})})), {status: 'rejected', code: 'idempotency_reused'});
    assert.deepEqual(await store.accept(input({mutation: mutation({mutationId: 'event-1', entityId: 'event-1', idempotencyKey: 'idempotency-2', payload: {...mutation().payload, occurrence: secondOccurrence}})})), {status: 'rejected', code: 'event_id_reused'});
    const corrupted = new MemoryPersistence();
    const occurrenceId = mutation().payload.occurrence.occurrenceId;
    corrupted.accepted.set(`robot-1:${occurrenceId}`, {...persistence.accepted.values().next().value, canonicalMutation: '{bad'});
    assert.deepEqual(await new TransactionalTerminalLedgerStore(corrupted).accept(input()), {status: 'rejected', code: 'malformed_stored_row'});
  });

  test('rolls back each accepted staging failure and leaves no partial write', async () => {
    for (const failure of [1, 2, 3]) {
      const persistence = new MemoryPersistence(); persistence.failAfter = failure;
      const result = await new TransactionalTerminalLedgerStore(persistence).accept(input());
      assert.equal(result.status, 'retryable_failure'); assert.equal(persistence.accepted.size, 0); assert.equal(persistence.changes.size, 0); assert.equal(persistence.states.size, 0);
    }
  });

  test('never reports ambiguous commit as applied and retry does not duplicate acceptance', async () => {
    const persistence = new MemoryPersistence();
    persistence.actualOutcome = 'committed';
    persistence.reportedOutcome = 'indeterminate';
    const store = new TransactionalTerminalLedgerStore(persistence);
    assert.deepEqual(await store.accept(input()), {status: 'indeterminate', transactionId: 'transaction-1'});
    assert.equal(persistence.accepted.size, 1);
    assert.equal(persistence.changes.size, 1);
    assert.equal(persistence.states.size, 1);
    persistence.reportedOutcome = 'committed';
    assert.deepEqual(await store.accept(input()), {status: 'duplicate', sequence: 1});
  });

  test('keeps a pending reported transaction invisible when it did not commit', async () => {
    const persistence = new MemoryPersistence();
    persistence.actualOutcome = 'not_committed';
    persistence.reportedOutcome = 'indeterminate';
    persistence.observedStatus = 'pending';
    const store = new TransactionalTerminalLedgerStore(persistence);
    assert.deepEqual(await store.accept(input()), {status: 'indeterminate', transactionId: 'transaction-1', transactionStatus: 'pending'});
    assert.equal(persistence.accepted.size, 0);
    assert.equal(persistence.changes.size, 0);
    assert.equal(persistence.states.size, 0);
    persistence.actualOutcome = 'committed';
    persistence.reportedOutcome = 'committed';
    persistence.observedStatus = undefined;
    assert.deepEqual(await store.accept(input()), {status: 'applied', sequence: 1});
  });

  test('stages the complete canonical DoseEvent change without unrelated writes', async () => {
    const persistence = new MemoryPersistence();
    await new TransactionalTerminalLedgerStore(persistence).accept(input({mutation: mutation({mutationId: 'mutation-1', entityId: 'event-1'})}));
    const change = persistence.changes.get('robot-1:1');
    assert.deepEqual(change, {
      robotId: 'robot-1', sequence: 1, resourceType: 'doseEvent', resourceId: 'event-1', resourceVersion: null,
      operation: 'event', payload: canonicalMedicationSyncJson(parseDoseEvent(JSON.parse(change!.payload))),
      actorAccountId: 'account-1', actorRole: 'device', changedAt: '2026-08-01T08:02:00.000Z',
      idempotencyKey: 'idempotency-1', operationHash: persistence.accepted.values().next().value.operationHash,
    });
    assert.equal(parseDoseEvent(JSON.parse(change!.payload)).id, 'event-1');
    assert.deepEqual(persistence.writes.filter((write) => !['accepted', 'change', 'state'].includes(write)), []);
  });

  test('fails closed for every corrupted accepted ledger link', async () => {
    for (const corruption of [
      (row: TerminalLedgerRow) => ({...row, canonicalMutation: reorderedJson(row.canonicalMutation)}),
      (row: TerminalLedgerRow) => ({...row, operationHash: '0'.repeat(64)}),
      (row: TerminalLedgerRow) => ({...row, id: 'x'.repeat(36)}),
      (row: TerminalLedgerRow) => ({...row, deviceId: 'other-device'}),
      (row: TerminalLedgerRow) => ({...row, occurrenceId: 'other-occurrence'}),
      (row: TerminalLedgerRow) => ({...row, canonicalMutation: row.canonicalMutation.replace('"scheduleId":"schedule-1"', '"scheduleId":"schedule-2"')}),
      (row: TerminalLedgerRow) => ({...row, eventId: 'other-event'}),
      (row: TerminalLedgerRow) => ({...row, kind: 'skipped' as const}),
    ]) {
      const persistence = new MemoryPersistence();
      await new TransactionalTerminalLedgerStore(persistence).accept(input());
      const key = `robot-1:${mutation().payload.occurrence.occurrenceId}`;
      persistence.accepted.set(key, corruption(persistence.accepted.get(key)!));
      assert.deepEqual(await new TransactionalTerminalLedgerStore(persistence).accept(input()), {status: 'rejected', code: 'malformed_stored_row'});
    }
  });

  test('accepts a legal occurrence identity longer than an ordinary ID', async () => {
    const scheduleId = `schedule-${'a'.repeat(119)}`;
    const scheduledAt = '2026-08-03T08:00:00Z';
    const occurrence = {contractVersion: 1, scheduleId, scheduleRevision: 1, scheduledAt, localDate: '2026-08-03', timezoneId: 'UTC', occurrenceId: `${scheduleId}:1:2026-08-03T08:00:00.000Z`};
    assert.ok(occurrence.occurrenceId.length > 128);
    assert.equal((await new TransactionalTerminalLedgerStore(new MemoryPersistence()).accept(input({mutation: mutation({payload: {...mutation().payload, occurrence}})}))).status, 'applied');
  });

  test('fails closed for corrupt or unexpected immutable conflict evidence', async () => {
    const changed = input({mutation: mutation({mutationId: 'event-2', entityId: 'event-2', idempotencyKey: 'idempotency-2', payload: {...mutation().payload, kind: 'skipped'}})});
    for (const corruption of [
      (row: TerminalLedgerConflict) => ({...row, canonicalMutation: reorderedJson(row.canonicalMutation)}),
      (row: TerminalLedgerConflict) => ({...row, incomingOperationHash: '0'.repeat(64)}),
      (row: TerminalLedgerConflict) => ({...row, id: 'x'.repeat(36)}),
      (row: TerminalLedgerConflict) => ({...row, code: 'terminal_outcome_replay_mismatch' as const}),
      (row: TerminalLedgerConflict) => ({...row, eventId: 'other-event'}),
      (row: TerminalLedgerConflict) => ({...row, acceptedLedgerId: 'other-ledger'}),
      (row: TerminalLedgerConflict) => ({...row, actorAccountId: 'other-account'}),
    ]) {
      const persistence = new MemoryPersistence(); const store = new TransactionalTerminalLedgerStore(persistence);
      await store.accept(input()); await store.accept(changed);
      const [id, conflict] = persistence.conflicts.entries().next().value;
      persistence.conflicts.set(id, corruption(conflict));
      assert.deepEqual(await store.accept(changed), {status: 'rejected', code: 'malformed_stored_row'});
    }
  });

  test('preserves an existing conflict recordedAt across a later identical retry', async () => {
    const persistence = new MemoryPersistence(); const store = new TransactionalTerminalLedgerStore(persistence);
    await store.accept(input());
    const changed = input({now: new Date('2026-08-01T08:04:00Z'), mutation: mutation({mutationId: 'event-2', entityId: 'event-2', idempotencyKey: 'idempotency-2', payload: {...mutation().payload, kind: 'skipped'}})});
    await store.accept(changed);
    const recordedAt = persistence.conflicts.values().next().value.recordedAt;
    assert.equal((await store.accept({...changed, now: new Date('2026-08-01T08:05:00Z')})).status, 'needs_review');
    assert.equal(persistence.conflicts.values().next().value.recordedAt, recordedAt);
  });

  test('rolls back a failed conflict stage and gives identity reuse precedence', async () => {
    const persistence = new MemoryPersistence(); const store = new TransactionalTerminalLedgerStore(persistence);
    await store.accept(input());
    persistence.failAfter = 1;
    const conflict = input({mutation: mutation({mutationId: 'event-2', entityId: 'event-2', idempotencyKey: 'idempotency-2', payload: {...mutation().payload, kind: 'skipped'}})});
    assert.equal((await store.accept(conflict)).status, 'retryable_failure');
    assert.equal(persistence.conflicts.size, 0);
    persistence.failAfter = null;
    assert.equal((await store.accept(conflict)).status, 'needs_review');
    const eventReuse = input({mutation: mutation({entityId: 'event-1', mutationId: 'other-mutation', idempotencyKey: 'idempotency-3', payload: {...mutation().payload, kind: 'skipped'}})});
    assert.deepEqual(await store.accept(eventReuse), {status: 'rejected', code: 'event_id_reused'});
  });

  test('rejects a saturated high watermark before staging', async () => {
    const persistence = new MemoryPersistence();
    persistence.states.set('robot-1', {robotId: 'robot-1', highWatermark: Number.MAX_SAFE_INTEGER, updatedAt: '2026-08-01T08:02:00.000Z'});
    assert.deepEqual(await new TransactionalTerminalLedgerStore(persistence).accept(input()), {status: 'rejected', code: 'sequence_exhausted'});
    assert.equal(persistence.writes.length, 0);
  });

  test('assigns contiguous sequences with sequential allocation', async () => {
    const persistence = new MemoryPersistence(); const store = new TransactionalTerminalLedgerStore(persistence);
    const first = store.accept(input());
    const second = store.accept(input({mutation: mutation({mutationId: 'event-2', entityId: 'event-2', idempotencyKey: 'idempotency-2', payload: {...mutation().payload, occurrence: {...mutation().payload.occurrence, occurrenceId: 'schedule-1:1:2026-08-02T08:00:00.000Z', scheduledAt: '2026-08-02T08:00:00Z', localDate: '2026-08-02'}}})}));
    assert.deepEqual((await Promise.all([first, second])).map((result) => result.status), ['applied', 'applied']);
    assert.deepEqual([...persistence.changes.values()].map((change) => change.sequence).sort(), [1, 2]);
  });
});

function reorderedJson(value: string): string {
  return JSON.stringify(Object.fromEntries(Object.entries(JSON.parse(value)).reverse()));
}
