export type MedicationSyncResourceType = 'medication' | 'schedule';
export type MedicationSyncActorRole = 'owner' | 'member' | 'device';
export type MedicationSyncEventKind =
  | 'taken_confirmed'
  | 'skipped'
  | 'snoozed'
  | 'help_requested';

export interface MedicationSyncDocumentRecord {
  readonly robotId: string;
  readonly resourceType: MedicationSyncResourceType;
  readonly resourceId: string;
  readonly version: number;
  readonly archived: boolean;
  readonly payload: string;
  readonly createdAt: Date;
  readonly createdByAccountId: string;
  readonly updatedAt: Date;
  readonly updatedByAccountId: string;
}

export interface MedicationSyncEventRecord {
  readonly robotId: string;
  readonly eventId: string;
  readonly eventHash: string;
  readonly kind: MedicationSyncEventKind;
  readonly doseId: string;
  readonly scheduleId: string;
  readonly payload: string;
  readonly occurredAt: Date;
  readonly receivedAt: Date;
  readonly actorAccountId: string;
  readonly sequence: number;
}

export interface MedicationSyncHelpRequestRecord {
  readonly robotId: string;
  readonly helpRequestId: string;
  readonly sourceEventId: string;
  readonly status: 'open';
  readonly version: number;
  readonly openedAt: Date;
  readonly openedByAccountId: string;
  readonly updatedAt: Date;
  readonly updatedByAccountId: string;
}

export interface MedicationSyncReceiptRecord {
  readonly robotId: string;
  readonly idempotencyKey: string;
  readonly operationHash: string;
  readonly sequence: number;
  readonly resourceVersion: number | null;
  readonly createdAt: Date;
}

export interface MedicationSyncStateRecord {
  readonly robotId: string;
  readonly highWatermark: number;
  readonly updatedAt: Date;
}

export interface MedicationSyncChangeRecord {
  readonly robotId: string;
  readonly sequence: number;
  readonly resourceType: MedicationSyncResourceType | 'doseEvent';
  readonly resourceId: string;
  readonly resourceVersion: number | null;
  readonly operation: 'upsert' | 'archive' | 'event';
  readonly payload: string;
  readonly actorAccountId: string;
  readonly actorRole: MedicationSyncActorRole;
  readonly changedAt: Date;
  readonly idempotencyKey: string;
  readonly operationHash: string;
}

export type MedicationSyncTerminalKind = 'taken_confirmed' | 'skipped' | 'missed';
export type MedicationSyncTerminalConflictCode =
  | 'TERMINAL_OUTCOME_REPLAY_MISMATCH'
  | 'TERMINAL_OUTCOME_CONFLICT';

export interface MedicationSyncTerminalOccurrenceRecord {
  readonly robotId: string;
  readonly occurrenceId: string;
  readonly acceptedKind: MedicationSyncTerminalKind;
  readonly acceptedEventId: string;
  readonly acceptedOperationHash: string;
  readonly acceptedIdempotencyKey: string;
  readonly acceptedDeviceId: string;
  readonly acceptedActorAccountId: string;
  readonly acceptedSequence: number;
  readonly occurredAt: Date;
  readonly acceptedAt: Date;
}

export interface MedicationSyncTerminalConflictRecord {
  readonly robotId: string;
  readonly occurrenceId: string;
  readonly conflictCode: MedicationSyncTerminalConflictCode;
  readonly acceptedEventId: string;
  readonly acceptedOperationHash: string;
  readonly acceptedKind: MedicationSyncTerminalKind;
  readonly acceptedSequence: number;
  readonly incomingEventId: string;
  readonly incomingOperationHash: string;
  readonly incomingKind: MedicationSyncTerminalKind;
  readonly incomingIdempotencyKey: string;
  readonly incomingDeviceId: string;
  readonly incomingActorAccountId: string;
  readonly incomingPayload: string;
  readonly incomingOccurredAt: Date;
  readonly recordedAt: Date;
}

export interface MedicationSyncTransaction {
  getTerminalOccurrence(
    robotId: string,
    occurrenceId: string,
  ): Promise<MedicationSyncTerminalOccurrenceRecord | null>;
  createTerminalOccurrence(record: MedicationSyncTerminalOccurrenceRecord): Promise<void>;
  getTerminalConflict(
    robotId: string,
    incomingOperationHash: string,
  ): Promise<MedicationSyncTerminalConflictRecord | null>;
  createTerminalConflict(record: MedicationSyncTerminalConflictRecord): Promise<void>;
  getDocument(
    robotId: string,
    resourceType: MedicationSyncResourceType,
    resourceId: string,
  ): Promise<MedicationSyncDocumentRecord | null>;
  saveDocument(record: MedicationSyncDocumentRecord): Promise<void>;
  getEvent(robotId: string, eventId: string): Promise<MedicationSyncEventRecord | null>;
  createEvent(record: MedicationSyncEventRecord): Promise<void>;
  createHelpRequest(record: MedicationSyncHelpRequestRecord): Promise<void>;
  getReceipt(robotId: string, idempotencyKey: string): Promise<MedicationSyncReceiptRecord | null>;
  saveReceipt(record: MedicationSyncReceiptRecord): Promise<void>;
  getState(robotId: string): Promise<MedicationSyncStateRecord | null>;
  saveState(record: MedicationSyncStateRecord): Promise<void>;
  createChange(record: MedicationSyncChangeRecord): Promise<void>;
  listChanges(
    robotId: string,
    afterSequence: number,
    throughSequence: number,
    limit: number,
  ): Promise<readonly MedicationSyncChangeRecord[]>;
}

export interface MedicationSyncPersistence {
  transaction<T>(operation: (transaction: MedicationSyncTransaction) => Promise<T>): Promise<T>;
}

type MutationContext = {
  readonly robotId: string;
  readonly idempotencyKey: string;
  readonly operationHash: string;
  readonly actorAccountId: string;
  readonly actorRole: MedicationSyncActorRole;
  readonly now: Date;
};

export type MedicationSyncMutationResult =
  | {
      readonly status: 'applied' | 'duplicate';
      readonly sequence: number;
      readonly resourceVersion?: number;
    }
  | {
      readonly status: 'conflict';
      readonly code:
        | 'operation_id_reused'
        | 'version_conflict'
        | 'event_id_reused';
      readonly currentVersion?: number;
      readonly currentDocument?: MedicationSyncDocumentRecord | null;
    };

export type TerminalOutcomeResult =
  | {
      readonly status: 'applied' | 'duplicate';
      readonly sequence: number;
    }
  | {
      readonly status: 'needs_review';
      readonly code: MedicationSyncTerminalConflictCode;
      readonly acceptedSequence: number;
    }
  | {
      readonly status: 'conflict';
      readonly code: 'operation_id_reused' | 'event_id_reused';
    };

export class TerminalOutcomeIntegrityError extends Error {}

type TerminalOutcomeInput = {
  readonly robotId: string;
  readonly occurrenceId: string;
  readonly eventId: string;
  readonly kind: 'taken_confirmed' | 'skipped';
  readonly scheduleId: string;
  readonly idempotencyKey: string;
  readonly operationHash: string;
  readonly deviceId: string;
  readonly actorAccountId: string;
  readonly occurredAt: Date;
  readonly payload: string;
  readonly now: Date;
};

export class TransactionalMedicationSyncStore {
  constructor(private readonly persistence: MedicationSyncPersistence) {}

  upsertDocument(input: MutationContext & {
    readonly resourceType: MedicationSyncResourceType;
    readonly resourceId: string;
    readonly baseVersion: number;
    readonly payload: string;
  }): Promise<MedicationSyncMutationResult> {
    return this.persistence.transaction(async (transaction) => {
      const replay = await replayResult(transaction, input);
      if (replay != null) return replay;

      const current = await transaction.getDocument(
        input.robotId,
        input.resourceType,
        input.resourceId,
      );
      const currentVersion = current?.version ?? 0;
      if (input.baseVersion !== currentVersion) {
        return {
          status: 'conflict' as const,
          code: 'version_conflict' as const,
          currentVersion,
          currentDocument: current,
        };
      }

      const version = currentVersion + 1;
      const sequence = await allocateSequence(transaction, input.robotId, input.now);
      const payload = documentPayload({
        robotId: input.robotId,
        resourceType: input.resourceType,
        resourceId: input.resourceId,
        version,
        deletedAt: null,
        updatedAt: input.now,
        mutationPayload: input.payload,
      });
      await transaction.saveDocument({
        robotId: input.robotId,
        resourceType: input.resourceType,
        resourceId: input.resourceId,
        version,
        archived: false,
        payload,
        createdAt: current?.createdAt ?? input.now,
        createdByAccountId: current?.createdByAccountId ?? input.actorAccountId,
        updatedAt: input.now,
        updatedByAccountId: input.actorAccountId,
      });
      await transaction.createChange({
        robotId: input.robotId,
        sequence,
        resourceType: input.resourceType,
        resourceId: input.resourceId,
        resourceVersion: version,
        operation: 'upsert',
        payload,
        actorAccountId: input.actorAccountId,
        actorRole: input.actorRole,
        changedAt: input.now,
        idempotencyKey: input.idempotencyKey,
        operationHash: input.operationHash,
      });
      await transaction.saveReceipt(receipt(input, sequence, version));
      return { status: 'applied', sequence, resourceVersion: version };
    });
  }

  archiveDocument(input: MutationContext & {
    readonly resourceType: MedicationSyncResourceType;
    readonly resourceId: string;
    readonly baseVersion: number;
  }): Promise<MedicationSyncMutationResult> {
    return this.persistence.transaction(async (transaction) => {
      const replay = await replayResult(transaction, input);
      if (replay != null) return replay;

      const current = await transaction.getDocument(
        input.robotId,
        input.resourceType,
        input.resourceId,
      );
      if (current == null || input.baseVersion !== current.version) {
        return {
          status: 'conflict' as const,
          code: 'version_conflict' as const,
          currentVersion: current?.version ?? 0,
          currentDocument: current,
        };
      }

      const version = current.version + 1;
      const sequence = await allocateSequence(transaction, input.robotId, input.now);
      const payload = documentPayload({
        robotId: input.robotId,
        resourceType: input.resourceType,
        resourceId: input.resourceId,
        version,
        deletedAt: input.now,
        updatedAt: input.now,
        mutationPayload: current.payload,
      });
      await transaction.saveDocument({
        ...current,
        version,
        archived: true,
        payload,
        updatedAt: input.now,
        updatedByAccountId: input.actorAccountId,
      });
      await transaction.createChange({
        robotId: input.robotId,
        sequence,
        resourceType: input.resourceType,
        resourceId: input.resourceId,
        resourceVersion: version,
        operation: 'archive',
        payload,
        actorAccountId: input.actorAccountId,
        actorRole: input.actorRole,
        changedAt: input.now,
        idempotencyKey: input.idempotencyKey,
        operationHash: input.operationHash,
      });
      await transaction.saveReceipt(receipt(input, sequence, version));
      return { status: 'applied', sequence, resourceVersion: version };
    });
  }

  appendEvent(input: MutationContext & {
    readonly eventId: string;
    readonly eventHash: string;
    readonly kind: MedicationSyncEventKind;
    readonly doseId: string;
    readonly scheduleId: string;
    readonly occurredAt: Date;
    readonly payload: string;
  }): Promise<MedicationSyncMutationResult> {
    return this.persistence.transaction(async (transaction) => {
      const replay = await replayResult(transaction, input);
      if (replay != null) return replay;

      const existing = await transaction.getEvent(input.robotId, input.eventId);
      if (existing != null) {
        if (existing.eventHash !== input.eventHash) {
          return { status: 'conflict', code: 'event_id_reused' };
        }
        await transaction.saveReceipt(receipt(input, existing.sequence, null));
        return { status: 'duplicate', sequence: existing.sequence };
      }

      const sequence = await allocateSequence(transaction, input.robotId, input.now);
      const payload = eventPayload(input);
      await transaction.createEvent({
        robotId: input.robotId,
        eventId: input.eventId,
        eventHash: input.eventHash,
        kind: input.kind,
        doseId: input.doseId,
        scheduleId: input.scheduleId,
        payload,
        occurredAt: input.occurredAt,
        receivedAt: input.now,
        actorAccountId: input.actorAccountId,
        sequence,
      });
      if (input.kind === 'help_requested') {
        await transaction.createHelpRequest({
          robotId: input.robotId,
          helpRequestId: input.eventId,
          sourceEventId: input.eventId,
          status: 'open',
          version: 1,
          openedAt: input.now,
          openedByAccountId: input.actorAccountId,
          updatedAt: input.now,
          updatedByAccountId: input.actorAccountId,
        });
      }
      await transaction.createChange({
        robotId: input.robotId,
        sequence,
        resourceType: 'doseEvent',
        resourceId: input.eventId,
        resourceVersion: null,
        operation: 'event',
        payload,
        actorAccountId: input.actorAccountId,
        actorRole: input.actorRole,
        changedAt: input.now,
        idempotencyKey: input.idempotencyKey,
        operationHash: input.operationHash,
      });
      await transaction.saveReceipt(receipt(input, sequence, null));
      return { status: 'applied', sequence };
    });
  }

  recordTerminalOutcome(
    input: TerminalOutcomeInput,
  ): Promise<TerminalOutcomeResult> {
    return this.persistence.transaction(async (transaction) => {
      const guard = await transaction.getTerminalOccurrence(input.robotId, input.occurrenceId);
      if (guard != null) {
        await assertAcceptedTerminalBundle(transaction, guard);
        if (guard.acceptedOperationHash === input.operationHash) {
          if (!matchesAcceptedTerminalInput(guard, input)) {
            throw new TerminalOutcomeIntegrityError(
              'Terminal operation hash is reserved for its accepted metadata.',
            );
          }
          await assertAcceptedTerminalInput(transaction, guard, input);
          return { status: 'duplicate', sequence: guard.acceptedSequence };
        }
        const code: MedicationSyncTerminalConflictCode = guard.acceptedKind === input.kind
          ? 'TERMINAL_OUTCOME_REPLAY_MISMATCH'
          : 'TERMINAL_OUTCOME_CONFLICT';
        const existing = await transaction.getTerminalConflict(input.robotId, input.operationHash);
        if (existing != null) {
          if (!matchesTerminalConflict(existing, terminalConflictRecord(guard, input, code))) {
            throw new TerminalOutcomeIntegrityError('Incoherent terminal conflict evidence.');
          }
          return { status: 'needs_review', code, acceptedSequence: guard.acceptedSequence };
        }
        await transaction.createTerminalConflict(terminalConflictRecord(guard, input, code));
        return { status: 'needs_review', code, acceptedSequence: guard.acceptedSequence };
      }
      const receipt = await transaction.getReceipt(input.robotId, input.idempotencyKey);
      if (receipt != null) {
        if (receipt.operationHash !== input.operationHash) {
          return { status: 'conflict', code: 'operation_id_reused' };
        }
        throw new TerminalOutcomeIntegrityError('Terminal receipt without occurrence guard.');
      }
      const event = await transaction.getEvent(input.robotId, input.eventId);
      if (event != null) {
        if (event.eventHash !== input.operationHash) {
          return { status: 'conflict', code: 'event_id_reused' };
        }
        throw new TerminalOutcomeIntegrityError('Terminal event without occurrence guard.');
      }

      const sequence = await allocateSequence(transaction, input.robotId, input.now);
      const payload = eventPayload(input);
      await transaction.createEvent({
        robotId: input.robotId,
        eventId: input.eventId,
        eventHash: input.operationHash,
        kind: input.kind,
        doseId: input.occurrenceId,
        scheduleId: input.scheduleId,
        payload,
        occurredAt: input.occurredAt,
        receivedAt: input.now,
        actorAccountId: input.actorAccountId,
        sequence,
      });
      await transaction.createTerminalOccurrence(terminalOccurrenceRecord(input, sequence));
      await transaction.createChange({
        robotId: input.robotId,
        sequence,
        resourceType: 'doseEvent',
        resourceId: input.eventId,
        resourceVersion: null,
        operation: 'event',
        payload,
        actorAccountId: input.actorAccountId,
        actorRole: 'device',
        changedAt: input.now,
        idempotencyKey: input.idempotencyKey,
        operationHash: input.operationHash,
      });
      await transaction.saveReceipt({
        robotId: input.robotId,
        idempotencyKey: input.idempotencyKey,
        operationHash: input.operationHash,
        sequence,
        resourceVersion: null,
        createdAt: input.now,
      });
      return { status: 'applied', sequence };
    });
  }

  pull(input: {
    readonly robotId: string;
    readonly cursor: number;
    readonly checkpoint?: number;
    readonly limit: number;
  }): Promise<{
    readonly changes: readonly MedicationSyncChangeRecord[];
    readonly nextCursor: number;
    readonly checkpoint: number;
    readonly complete: boolean;
  }> {
    return this.persistence.transaction(async (transaction) => {
      const highWatermark = (await transaction.getState(input.robotId))?.highWatermark ?? 0;
      const checkpoint = input.checkpoint ?? highWatermark;
      if (
        !Number.isSafeInteger(input.cursor) ||
        !Number.isSafeInteger(checkpoint) ||
        !Number.isSafeInteger(input.limit) ||
        input.cursor < 0 ||
        checkpoint < 0 ||
        input.cursor > checkpoint ||
        checkpoint > highWatermark ||
        input.limit < 1 ||
        input.limit > 100
      ) {
        throw new Error('Invalid medication sync cursor.');
      }
      const changes = await transaction.listChanges(
        input.robotId,
        input.cursor,
        checkpoint,
        input.limit,
      );
      const nextCursor = changes.at(-1)?.sequence ?? input.cursor;
      return {
        changes,
        nextCursor,
        checkpoint,
        complete: nextCursor >= checkpoint,
      };
    });
  }
}

function documentPayload(input: {
  robotId: string;
  resourceType: MedicationSyncResourceType;
  resourceId: string;
  version: number;
  deletedAt: Date | null;
  updatedAt: Date;
  mutationPayload: string;
}): string {
  const domainPayload = domainPayloadFromJson(input.mutationPayload);
  return JSON.stringify({
    contractVersion: 1,
    id: input.resourceId,
    householdId: input.robotId,
    ...domainPayload,
    revision: input.version,
    deletedAt: input.deletedAt?.toISOString() ?? null,
    updatedAt: input.updatedAt.toISOString(),
  });
}

function eventPayload(input: {
  robotId: string;
  eventId: string;
  payload: string;
  actorAccountId: string;
}): string {
  return JSON.stringify({
    ...domainPayloadFromJson(input.payload),
    contractVersion: 1,
    id: input.eventId,
    householdId: input.robotId,
    actorAccountId: input.actorAccountId,
  });
}

const reservedPayloadKeys = new Set([
  'contractVersion', 'id', 'householdId', 'revision', 'deletedAt', 'updatedAt', 'actorAccountId',
]);

function domainPayloadFromJson(payload: string): Record<string, unknown> {
  const parsed: unknown = JSON.parse(payload);
  if (
    parsed == null ||
    typeof parsed !== 'object' ||
    Array.isArray(parsed) ||
    (Object.getPrototypeOf(parsed) !== Object.prototype && Object.getPrototypeOf(parsed) !== null)
  ) {
    throw new Error('Invalid medication sync payload.');
  }
  return Object.fromEntries(
    Object.entries(parsed).filter(([key]) => !reservedPayloadKeys.has(key)),
  );
}

async function replayResult(
  transaction: MedicationSyncTransaction,
  input: MutationContext,
): Promise<MedicationSyncMutationResult | null> {
  const existing = await transaction.getReceipt(input.robotId, input.idempotencyKey);
  if (existing == null) return null;
  if (existing.operationHash !== input.operationHash) {
    return { status: 'conflict', code: 'operation_id_reused' };
  }
  return existing.resourceVersion == null
    ? { status: 'duplicate', sequence: existing.sequence }
    : {
        status: 'duplicate',
        sequence: existing.sequence,
        resourceVersion: existing.resourceVersion,
      };
}

async function allocateSequence(
  transaction: MedicationSyncTransaction,
  robotId: string,
  now: Date,
): Promise<number> {
  // Commit conflicts retry the whole transaction to refetch this high watermark.
  const sequence = ((await transaction.getState(robotId))?.highWatermark ?? 0) + 1;
  await transaction.saveState({ robotId, highWatermark: sequence, updatedAt: now });
  return sequence;
}

function terminalOccurrenceRecord(
  input: TerminalOutcomeInput,
  sequence: number,
): MedicationSyncTerminalOccurrenceRecord {
  return {
    robotId: input.robotId,
    occurrenceId: input.occurrenceId,
    acceptedKind: input.kind,
    acceptedEventId: input.eventId,
    acceptedOperationHash: input.operationHash,
    acceptedIdempotencyKey: input.idempotencyKey,
    acceptedDeviceId: input.deviceId,
    acceptedActorAccountId: input.actorAccountId,
    acceptedSequence: sequence,
    occurredAt: input.occurredAt,
    acceptedAt: input.now,
  };
}

function terminalConflictRecord(
  guard: MedicationSyncTerminalOccurrenceRecord,
  input: TerminalOutcomeInput,
  conflictCode: MedicationSyncTerminalConflictCode,
): MedicationSyncTerminalConflictRecord {
  return {
    robotId: input.robotId,
    occurrenceId: input.occurrenceId,
    conflictCode,
    acceptedEventId: guard.acceptedEventId,
    acceptedOperationHash: guard.acceptedOperationHash,
    acceptedKind: guard.acceptedKind,
    acceptedSequence: guard.acceptedSequence,
    incomingEventId: input.eventId,
    incomingOperationHash: input.operationHash,
    incomingKind: input.kind,
    incomingIdempotencyKey: input.idempotencyKey,
    incomingDeviceId: input.deviceId,
    incomingActorAccountId: input.actorAccountId,
    incomingPayload: input.payload,
    incomingOccurredAt: input.occurredAt,
    recordedAt: input.now,
  };
}

function matchesAcceptedTerminalInput(
  guard: MedicationSyncTerminalOccurrenceRecord,
  input: TerminalOutcomeInput,
): boolean {
  return guard.robotId === input.robotId &&
    guard.occurrenceId === input.occurrenceId &&
    guard.acceptedKind === input.kind &&
    guard.acceptedEventId === input.eventId &&
    guard.acceptedOperationHash === input.operationHash &&
    guard.acceptedIdempotencyKey === input.idempotencyKey &&
    guard.acceptedDeviceId === input.deviceId &&
    guard.acceptedActorAccountId === input.actorAccountId &&
    sameTime(guard.occurredAt, input.occurredAt);
}

async function assertAcceptedTerminalInput(
  transaction: MedicationSyncTransaction,
  guard: MedicationSyncTerminalOccurrenceRecord,
  input: TerminalOutcomeInput,
): Promise<void> {
  const event = await transaction.getEvent(input.robotId, input.eventId);
  if (event == null ||
    event.eventHash !== input.operationHash ||
    event.kind !== input.kind ||
    event.doseId !== input.occurrenceId ||
    event.scheduleId !== input.scheduleId ||
    event.payload !== eventPayload(input) ||
    !sameTime(event.occurredAt, input.occurredAt) ||
    event.actorAccountId !== input.actorAccountId ||
    event.sequence !== guard.acceptedSequence) {
    throw new TerminalOutcomeIntegrityError('Terminal replay does not match accepted event evidence.');
  }
}

async function assertAcceptedTerminalBundle(
  transaction: MedicationSyncTransaction,
  guard: MedicationSyncTerminalOccurrenceRecord,
): Promise<void> {
  const [receipt, event, state, changes] = await Promise.all([
    transaction.getReceipt(guard.robotId, guard.acceptedIdempotencyKey),
    transaction.getEvent(guard.robotId, guard.acceptedEventId),
    transaction.getState(guard.robotId),
    transaction.listChanges(
      guard.robotId,
      guard.acceptedSequence - 1,
      guard.acceptedSequence,
      1,
    ),
  ]);
  const change = changes[0];
  if (receipt == null ||
    receipt.operationHash !== guard.acceptedOperationHash ||
    receipt.sequence !== guard.acceptedSequence ||
    receipt.resourceVersion !== null ||
    !sameTime(receipt.createdAt, guard.acceptedAt) ||
    event == null ||
    event.eventHash !== guard.acceptedOperationHash ||
    event.kind !== guard.acceptedKind ||
    event.doseId !== guard.occurrenceId ||
    !sameTime(event.occurredAt, guard.occurredAt) ||
    !sameTime(event.receivedAt, guard.acceptedAt) ||
    event.actorAccountId !== guard.acceptedActorAccountId ||
    event.sequence !== guard.acceptedSequence ||
    change == null ||
    change.sequence !== guard.acceptedSequence ||
    change.resourceType !== 'doseEvent' ||
    change.resourceId !== guard.acceptedEventId ||
    change.resourceVersion !== null ||
    change.operation !== 'event' ||
    change.payload !== event.payload ||
    change.actorAccountId !== guard.acceptedActorAccountId ||
    change.actorRole !== 'device' ||
    !sameTime(change.changedAt, guard.acceptedAt) ||
    change.idempotencyKey !== guard.acceptedIdempotencyKey ||
    change.operationHash !== guard.acceptedOperationHash ||
    state == null ||
    state.highWatermark < guard.acceptedSequence) {
    throw new TerminalOutcomeIntegrityError('Incoherent accepted terminal evidence.');
  }
  assertAcceptedTerminalEventPayload(event.payload, guard, event.scheduleId);
}

function assertAcceptedTerminalEventPayload(
  payload: string,
  guard: MedicationSyncTerminalOccurrenceRecord,
  scheduleId: string,
): void {
  let parsed: unknown;
  try {
    parsed = JSON.parse(payload);
  } catch {
    throw new TerminalOutcomeIntegrityError('Malformed accepted terminal event payload.');
  }
  if (!isRecord(parsed) ||
    parsed.contractVersion !== 1 ||
    parsed.id !== guard.acceptedEventId ||
    parsed.householdId !== guard.robotId ||
    parsed.actorAccountId !== guard.acceptedActorAccountId ||
    parsed.kind !== guard.acceptedKind ||
    parsed.occurredAt !== guard.occurredAt.toISOString() ||
    !isRecord(parsed.occurrence) ||
    parsed.occurrence.occurrenceId !== guard.occurrenceId ||
    parsed.occurrence.scheduleId !== scheduleId) {
    throw new TerminalOutcomeIntegrityError('Incoherent accepted terminal event payload.');
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value != null && typeof value === 'object' && !Array.isArray(value);
}

function matchesTerminalConflict(
  existing: MedicationSyncTerminalConflictRecord,
  expected: MedicationSyncTerminalConflictRecord,
): boolean {
  return existing.robotId === expected.robotId &&
    existing.occurrenceId === expected.occurrenceId &&
    existing.conflictCode === expected.conflictCode &&
    existing.acceptedEventId === expected.acceptedEventId &&
    existing.acceptedOperationHash === expected.acceptedOperationHash &&
    existing.acceptedKind === expected.acceptedKind &&
    existing.acceptedSequence === expected.acceptedSequence &&
    existing.incomingEventId === expected.incomingEventId &&
    existing.incomingOperationHash === expected.incomingOperationHash &&
    existing.incomingKind === expected.incomingKind &&
    existing.incomingIdempotencyKey === expected.incomingIdempotencyKey &&
    existing.incomingDeviceId === expected.incomingDeviceId &&
    existing.incomingActorAccountId === expected.incomingActorAccountId &&
    existing.incomingPayload === expected.incomingPayload &&
    sameTime(existing.incomingOccurredAt, expected.incomingOccurredAt);
}

function sameTime(left: Date, right: Date): boolean {
  return left.getTime() === right.getTime();
}

function receipt(
  input: MutationContext,
  sequence: number,
  resourceVersion: number | null,
): MedicationSyncReceiptRecord {
  return {
    robotId: input.robotId,
    idempotencyKey: input.idempotencyKey,
    operationHash: input.operationHash,
    sequence,
    resourceVersion,
    createdAt: input.now,
  };
}
