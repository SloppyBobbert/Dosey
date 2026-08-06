import {createHash} from 'node:crypto';

import {
  canonicalMedicationSyncJson,
  canonicalMutationHashInput,
  evaluateTerminalOutcomeAuthority,
  parseDoseEvent,
  parseMutation,
  type DoseEventAppendMutation,
  type MedicationSyncActor,
  type Mutation,
} from '../domain/medication-sync-contract.js';

export type TransactionStatus = 'pending' | 'committing' | 'committed' | 'rolled_back' | 'failed';
export type TerminalOutcomeKind = 'taken_confirmed' | 'skipped';

export interface TerminalLedgerRow {
  readonly id: string;
  readonly robotId: string;
  readonly occurrenceId: string;
  readonly eventId: string;
  readonly idempotencyKey: string;
  readonly operationHash: string;
  readonly canonicalMutation: string;
  readonly kind: TerminalOutcomeKind;
  readonly actorAccountId: string;
  readonly deviceId: string;
  readonly sequence: number;
  readonly acceptedAt: string;
}

export interface TerminalLedgerChange {
  readonly robotId: string;
  readonly sequence: number;
  readonly resourceType: 'doseEvent';
  readonly resourceId: string;
  readonly resourceVersion: null;
  readonly operation: 'event';
  readonly payload: string;
  readonly actorAccountId: string;
  readonly actorRole: 'device';
  readonly changedAt: string;
  readonly idempotencyKey: string;
  readonly operationHash: string;
}

export interface TerminalLedgerState {
  readonly robotId: string;
  readonly highWatermark: number;
  readonly updatedAt: string;
}

export interface TerminalLedgerConflict {
  readonly id: string;
  readonly robotId: string;
  readonly occurrenceId: string;
  readonly acceptedLedgerId: string;
  readonly acceptedOperationHash: string;
  readonly incomingOperationHash: string;
  readonly canonicalMutation: string;
  readonly eventId: string;
  readonly idempotencyKey: string;
  readonly deviceId: string;
  readonly actorAccountId: string;
  readonly kind: TerminalOutcomeKind;
  readonly occurredAt: string;
  readonly code: 'terminal_outcome_conflict' | 'terminal_outcome_replay_mismatch';
  readonly recordedAt: string;
}

export interface TerminalLedgerTransaction {
  getAcceptedOccurrence(robotId: string, occurrenceId: string): Promise<TerminalLedgerRow | null>;
  getIdempotency(robotId: string, idempotencyKey: string): Promise<TerminalLedgerRow | null>;
  getEvent(robotId: string, eventId: string): Promise<TerminalLedgerRow | null>;
  getConflict(id: string): Promise<TerminalLedgerConflict | null>;
  getState(robotId: string): Promise<TerminalLedgerState | null>;
  stageAccepted(row: TerminalLedgerRow): Promise<void>;
  stageChange(change: TerminalLedgerChange): Promise<void>;
  stageState(state: TerminalLedgerState): Promise<void>;
  stageConflict(conflict: TerminalLedgerConflict): Promise<void>;
}

export type TerminalLedgerTransactionResult<T> =
  | {readonly outcome: 'committed'; readonly value: T}
  | {readonly outcome: 'not_committed'; readonly status: 'rolled_back' | 'failed'; readonly error?: unknown}
  | {readonly outcome: 'indeterminate'; readonly transactionId: string; readonly observedStatus?: 'pending' | 'committing'; readonly error?: unknown};

export interface TerminalLedgerPersistence {
  transaction<T>(operation: (transaction: TerminalLedgerTransaction) => Promise<T>): Promise<TerminalLedgerTransactionResult<T>>;
}

export type TerminalLedgerResult =
  | {readonly status: 'applied'; readonly sequence: number}
  | {readonly status: 'duplicate'; readonly sequence: number}
  | {readonly status: 'needs_review'; readonly conflictId: string}
  | {readonly status: 'rejected'; readonly code: string}
  | {readonly status: 'retryable_failure'; readonly transactionStatus: 'rolled_back' | 'failed'}
  | {readonly status: 'indeterminate'; readonly transactionId: string; readonly transactionStatus?: 'pending' | 'committing'};

type Prepared = {
  readonly robotId: string;
  readonly mutation: DoseEventAppendMutation;
  readonly occurrenceId: string;
  readonly kind: TerminalOutcomeKind;
  readonly canonicalMutation: string;
  readonly operationHash: string;
  readonly actor: MedicationSyncActor;
  readonly acceptedAt: string;
};

export class TransactionalTerminalLedgerStore {
  constructor(private readonly persistence: TerminalLedgerPersistence) {}

  async accept(input: {readonly robotId: string; readonly mutation: Mutation; readonly actor: MedicationSyncActor; readonly now: Date}): Promise<TerminalLedgerResult> {
    const prepared = prepare(input);
    if ('code' in prepared) return {status: 'rejected', code: prepared.code};
    const transaction = await this.persistence.transaction(async (store) => {
      const accepted = await store.getAcceptedOccurrence(prepared.robotId, prepared.occurrenceId);
      if (accepted !== null && !validLedgerRow(accepted)) return rejected('malformed_stored_row');
      if (accepted !== null && exactReplay(accepted, prepared)) return {status: 'duplicate' as const, sequence: accepted.sequence};

      const idempotency = await store.getIdempotency(prepared.robotId, prepared.mutation.idempotencyKey);
      if (idempotency !== null && !validLedgerRow(idempotency)) return rejected('malformed_stored_row');
      if (idempotency !== null) return rejected('idempotency_reused');

      const event = await store.getEvent(prepared.robotId, prepared.mutation.entityId);
      if (event !== null && !validLedgerRow(event)) return rejected('malformed_stored_row');
      if (event !== null) return rejected('event_id_reused');

      if (accepted !== null) {
        const conflict = conflictRow(accepted, prepared);
        const existing = await store.getConflict(conflict.id);
        if (existing !== null && !validConflict(existing, accepted, prepared)) return rejected('malformed_stored_row');
        if (existing === null) await store.stageConflict(conflict);
        return {status: 'needs_review' as const, conflictId: conflict.id};
      }

      const state = await store.getState(prepared.robotId);
      if (state !== null && !validState(state, prepared.robotId)) return rejected('malformed_stored_row');
      if (state?.highWatermark === Number.MAX_SAFE_INTEGER) return rejected('sequence_exhausted');
      const sequence = (state?.highWatermark ?? 0) + 1;
      const row = acceptedRow(prepared, sequence);
      await store.stageAccepted(row);
      await store.stageChange(changeRow(prepared, sequence));
      await store.stageState({robotId: prepared.robotId, highWatermark: sequence, updatedAt: prepared.acceptedAt});
      return {status: 'applied' as const, sequence};
    });
    if (transaction.outcome === 'committed') return transaction.value;
    if (transaction.outcome === 'not_committed') return {status: 'retryable_failure', transactionStatus: transaction.status};
    return {
      status: 'indeterminate', transactionId: transaction.transactionId,
      ...(transaction.observedStatus === undefined ? {} : {transactionStatus: transaction.observedStatus}),
    };
  }
}

function prepare(input: {readonly robotId: string; readonly mutation: Mutation; readonly actor: MedicationSyncActor; readonly now: Date}): Prepared | {readonly code: string} {
  try {
    const mutation = parseMutation(input.mutation);
    if (!validId(input.robotId) || !validActor(input.actor) || !validNow(input.now)) return {code: 'malformed_input'};
    if (mutation.entityType !== 'dose_event' || mutation.operation !== 'append') return {code: 'terminal_outcome_required'};
    if (mutation.payload.kind !== 'taken_confirmed' && mutation.payload.kind !== 'skipped') return {code: 'unsupported_terminal_outcome'};
    const authority = evaluateTerminalOutcomeAuthority(input.actor, mutation);
    if (authority.outcome === 'rejected') return {code: authority.errorCode};
    const canonicalMutation = canonicalMedicationSyncJson(mutation);
    return {
      robotId: input.robotId, mutation, occurrenceId: mutation.payload.occurrence.occurrenceId,
      kind: mutation.payload.kind, canonicalMutation,
      operationHash: hash(canonicalMutationHashInput(input.robotId, mutation)), actor: input.actor,
      acceptedAt: input.now.toISOString(),
    };
  } catch { return {code: 'malformed_input'}; }
}

function acceptedRow(prepared: Prepared, sequence: number): TerminalLedgerRow {
  return {
    id: ledgerId(prepared.robotId, prepared.mutation.idempotencyKey), robotId: prepared.robotId,
    occurrenceId: prepared.occurrenceId, eventId: prepared.mutation.entityId,
    idempotencyKey: prepared.mutation.idempotencyKey, operationHash: prepared.operationHash,
    canonicalMutation: prepared.canonicalMutation, kind: prepared.kind,
    actorAccountId: prepared.actor.accountId, deviceId: prepared.mutation.deviceId,
    sequence, acceptedAt: prepared.acceptedAt,
  };
}

function changeRow(prepared: Prepared, sequence: number): TerminalLedgerChange {
  const event = parseDoseEvent({
    contractVersion: 1, id: prepared.mutation.entityId, householdId: prepared.robotId,
    medicationId: prepared.mutation.payload.medicationId, occurrence: prepared.mutation.payload.occurrence,
    kind: prepared.kind, occurredAt: prepared.mutation.payload.occurredAt,
    actorAccountId: prepared.actor.accountId,
  });
  return {
    robotId: prepared.robotId, sequence, resourceType: 'doseEvent', resourceId: prepared.mutation.entityId,
    resourceVersion: null, operation: 'event', payload: canonicalMedicationSyncJson(event),
    actorAccountId: prepared.actor.accountId, actorRole: 'device', changedAt: prepared.acceptedAt,
    idempotencyKey: prepared.mutation.idempotencyKey, operationHash: prepared.operationHash,
  };
}

function conflictRow(accepted: TerminalLedgerRow, prepared: Prepared): TerminalLedgerConflict {
  const code = accepted.kind === prepared.kind ? 'terminal_outcome_replay_mismatch' : 'terminal_outcome_conflict';
  return {
    id: conflictId(accepted.id, accepted.operationHash, prepared.operationHash), robotId: prepared.robotId,
    occurrenceId: prepared.occurrenceId, acceptedLedgerId: accepted.id,
    acceptedOperationHash: accepted.operationHash, incomingOperationHash: prepared.operationHash,
    canonicalMutation: prepared.canonicalMutation, eventId: prepared.mutation.entityId,
    idempotencyKey: prepared.mutation.idempotencyKey, deviceId: prepared.mutation.deviceId,
    actorAccountId: prepared.actor.accountId, kind: prepared.kind,
    occurredAt: prepared.mutation.payload.occurredAt, code, recordedAt: prepared.acceptedAt,
  };
}

function exactReplay(row: TerminalLedgerRow, prepared: Prepared): boolean {
  return row.operationHash === prepared.operationHash && row.canonicalMutation === prepared.canonicalMutation &&
    row.actorAccountId === prepared.actor.accountId && row.deviceId === prepared.mutation.deviceId;
}

function validLedgerRow(row: TerminalLedgerRow): boolean {
  try {
    const mutation = parseMutation(JSON.parse(row.canonicalMutation));
    const canonical = canonicalMedicationSyncJson(mutation);
    return row.canonicalMutation === canonical && validAppwriteId(row.id) && row.id === ledgerId(row.robotId, row.idempotencyKey) &&
      validId(row.robotId) && validOccurrenceId(row.occurrenceId) && validId(row.eventId) && validId(row.idempotencyKey) &&
      row.operationHash === hash(canonicalMutationHashInput(row.robotId, mutation)) &&
      mutation.entityType === 'dose_event' && mutation.operation === 'append' &&
      (row.kind === 'taken_confirmed' || row.kind === 'skipped') && mutation.payload.kind === row.kind &&
      mutation.entityId === row.eventId && mutation.idempotencyKey === row.idempotencyKey &&
      mutation.deviceId === row.deviceId && mutation.payload.occurrence.occurrenceId === row.occurrenceId &&
      validId(row.actorAccountId) && validId(row.deviceId) && Number.isSafeInteger(row.sequence) && row.sequence > 0 && validTimestamp(row.acceptedAt);
  } catch { return false; }
}

function validConflict(value: TerminalLedgerConflict, accepted: TerminalLedgerRow, prepared: Prepared): boolean {
  try {
    const mutation = parseMutation(JSON.parse(value.canonicalMutation));
    const expected = conflictRow(accepted, prepared);
    return value.id === expected.id && validAppwriteId(value.id) && value.robotId === expected.robotId &&
      value.occurrenceId === expected.occurrenceId && value.acceptedLedgerId === expected.acceptedLedgerId &&
      value.acceptedOperationHash === expected.acceptedOperationHash && value.incomingOperationHash === expected.incomingOperationHash &&
      value.canonicalMutation === canonicalMedicationSyncJson(mutation) && value.canonicalMutation === expected.canonicalMutation &&
      value.eventId === expected.eventId && value.idempotencyKey === expected.idempotencyKey && value.deviceId === expected.deviceId &&
      value.actorAccountId === expected.actorAccountId && value.kind === expected.kind && value.occurredAt === expected.occurredAt &&
      value.code === expected.code && validTimestamp(value.recordedAt);
  } catch { return false; }
}

function validState(value: TerminalLedgerState, robotId: string): boolean {
  return value.robotId === robotId && Number.isSafeInteger(value.highWatermark) && value.highWatermark >= 0 && validTimestamp(value.updatedAt);
}

function validActor(actor: MedicationSyncActor): boolean {
  return validId(actor.accountId) && (actor.authority === 'human' || actor.authority === 'patient_device') &&
    (actor.registeredDeviceId === null || validId(actor.registeredDeviceId));
}

function rejected(code: string): {readonly status: 'rejected'; readonly code: string} { return {status: 'rejected', code}; }
function validId(value: unknown): value is string { return typeof value === 'string' && value.length > 0 && value.length <= 128 && value.trim() === value; }
function validOccurrenceId(value: unknown): value is string { return typeof value === 'string' && value.length > 0 && value.length <= 256 && value.trim() === value; }
function validNow(value: Date): boolean { return Number.isFinite(value.getTime()); }
function validTimestamp(value: string): boolean { return typeof value === 'string' && Number.isFinite(new Date(value).getTime()) && new Date(value).toISOString() === value; }
function hash(value: string): string { return createHash('sha256').update(value).digest('hex'); }
function appwriteId(...parts: string[]): string { return `t${createHash('sha256').update(parts.join('\u0000')).digest('base64url').slice(0, 35)}`; }
function validAppwriteId(value: string): boolean { return /^[A-Za-z0-9][A-Za-z0-9_-]{35}$/.test(value); }
function ledgerId(robotId: string, idempotencyKey: string): string { return appwriteId('terminal-ledger', robotId, idempotencyKey); }
function conflictId(acceptedId: string, acceptedHash: string, incomingHash: string): string { return appwriteId('terminal-conflict', acceptedId, acceptedHash, incomingHash); }
