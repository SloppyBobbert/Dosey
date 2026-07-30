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
  readonly operationId: string;
  readonly operationHash: string;
}

export interface MedicationSyncTransaction {
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
  readonly operationId: string;
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
        operationId: input.operationId,
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
        operationId: input.operationId,
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
        operationId: input.operationId,
        operationHash: input.operationHash,
      });
      await transaction.saveReceipt(receipt(input, sequence, null));
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
  const parsed = JSON.parse(input.mutationPayload) as Record<string, unknown>;
  const domainPayload = 'contractVersion' in parsed && 'householdId' in parsed
    ? Object.fromEntries(
        Object.entries(parsed).filter(([key]) => ![
          'contractVersion', 'id', 'householdId', 'revision', 'deletedAt', 'updatedAt',
        ].includes(key)),
      )
    : parsed;
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
    contractVersion: 1,
    id: input.eventId,
    householdId: input.robotId,
    ...(JSON.parse(input.payload) as Record<string, unknown>),
    actorAccountId: input.actorAccountId,
  });
}

async function replayResult(
  transaction: MedicationSyncTransaction,
  input: MutationContext,
): Promise<MedicationSyncMutationResult | null> {
  const existing = await transaction.getReceipt(input.robotId, input.operationId);
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
  const sequence = ((await transaction.getState(robotId))?.highWatermark ?? 0) + 1;
  await transaction.saveState({ robotId, highWatermark: sequence, updatedAt: now });
  return sequence;
}

function receipt(
  input: MutationContext,
  sequence: number,
  resourceVersion: number | null,
): MedicationSyncReceiptRecord {
  return {
    robotId: input.robotId,
    idempotencyKey: input.operationId,
    operationHash: input.operationHash,
    sequence,
    resourceVersion,
    createdAt: input.now,
  };
}
