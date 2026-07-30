import { createHash } from 'node:crypto';

import type {
  AuthorizedMedicationSyncAccess,
  MedicationSyncActorType,
} from './household-access.js';
import type {
  MedicationSyncChangeRecord,
  MedicationSyncDocumentRecord,
  MedicationSyncEventKind,
  MedicationSyncMutationResult,
  MedicationSyncResourceType,
} from '../infrastructure/transactional-medication-sync-store.js';

interface MedicationSyncAccessAuthorizer {
  authorize(input: {
    accountId: string;
    actorType: MedicationSyncActorType;
    robotId: string;
  }): Promise<AuthorizedMedicationSyncAccess | null>;
}

type MutationActor = {
  readonly robotId: string;
  readonly idempotencyKey: string;
  readonly operationHash: string;
  readonly actorAccountId: string;
  readonly actorRole: 'owner' | 'member' | 'device';
  readonly now: Date;
};

export interface MedicationSyncApplicationStore {
  upsertDocument(input: MutationActor & {
    readonly resourceType: MedicationSyncResourceType;
    readonly resourceId: string;
    readonly baseVersion: number;
    readonly payload: string;
  }): Promise<MedicationSyncMutationResult>;
  archiveDocument(input: MutationActor & {
    readonly resourceType: MedicationSyncResourceType;
    readonly resourceId: string;
    readonly baseVersion: number;
  }): Promise<MedicationSyncMutationResult>;
  appendEvent(input: MutationActor & {
    readonly eventId: string;
    readonly eventHash: string;
    readonly kind: MedicationSyncEventKind;
    readonly doseId: string;
    readonly scheduleId: string;
    readonly occurredAt: Date;
    readonly payload: string;
  }): Promise<MedicationSyncMutationResult>;
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
  }>;
}

export type MedicationSyncPushOperation =
  | {
      readonly type: 'upsertDocument';
      readonly operationId: string;
      readonly idempotencyKey: string;
      readonly deviceId: string;
      readonly canonicalHashInput: string;
      readonly resourceType: MedicationSyncResourceType;
      readonly resourceId: string;
      readonly baseVersion: number;
      readonly payload: string;
    }
  | {
      readonly type: 'archiveDocument';
      readonly operationId: string;
      readonly idempotencyKey: string;
      readonly deviceId: string;
      readonly canonicalHashInput: string;
      readonly resourceType: MedicationSyncResourceType;
      readonly resourceId: string;
      readonly baseVersion: number;
    }
  | {
      readonly type: 'appendEvent';
      readonly operationId: string;
      readonly idempotencyKey: string;
      readonly deviceId: string;
      readonly canonicalHashInput: string;
      readonly eventId: string;
      readonly kind: MedicationSyncEventKind;
      readonly doseId: string;
      readonly scheduleId: string;
      readonly occurredAt: Date;
      readonly payload: string;
    };

export interface MedicationSyncAcknowledgement {
  readonly operationId: string;
  readonly status: 'applied' | 'duplicate' | 'conflict' | 'rejected';
  readonly sequence?: number;
  readonly resourceVersion?: number;
  readonly currentVersion?: number;
  readonly currentDocument?: MedicationSyncDocumentRecord | null;
  readonly resourceType?: MedicationSyncResourceType;
  readonly resourceId?: string;
  readonly baseVersion?: number;
  readonly code?: string;
}

export class MedicationSyncAuthorizationError extends Error {
  constructor() {
    super('The authenticated account cannot access this household.');
    this.name = 'MedicationSyncAuthorizationError';
  }
}

export class MedicationSyncPushService {
  constructor(
    private readonly access: MedicationSyncAccessAuthorizer,
    private readonly store: MedicationSyncApplicationStore,
    private readonly now: () => Date,
  ) {}

  async push(input: {
    readonly accountId: string;
    readonly actorType: MedicationSyncActorType;
    readonly robotId: string;
    readonly operations: readonly MedicationSyncPushOperation[];
  }): Promise<{ readonly acknowledgements: readonly MedicationSyncAcknowledgement[] }> {
    const authorized = await this.access.authorize({
      accountId: input.accountId,
      actorType: input.actorType,
      robotId: input.robotId,
    });
    if (authorized == null) throw new MedicationSyncAuthorizationError();

    const acknowledgements: MedicationSyncAcknowledgement[] = [];
    for (const operation of input.operations) {
      if (
        operation.type !== 'appendEvent' &&
        authorized.role !== 'owner'
      ) {
        acknowledgements.push({
          operationId: operation.operationId,
          status: 'rejected',
          code: 'owner_required',
        });
        continue;
      }

      const actor = {
        robotId: input.robotId,
        idempotencyKey: operation.idempotencyKey,
        operationHash: digest(operation.canonicalHashInput),
        actorAccountId: input.accountId,
        actorRole: authorized.role,
        now: this.now(),
      };
      try {
      const result = operation.type === 'upsertDocument'
        ? await this.store.upsertDocument({
            ...actor,
            resourceType: operation.resourceType,
            resourceId: operation.resourceId,
            baseVersion: operation.baseVersion,
            payload: operation.payload,
          })
        : operation.type === 'archiveDocument'
          ? await this.store.archiveDocument({
              ...actor,
              resourceType: operation.resourceType,
              resourceId: operation.resourceId,
              baseVersion: operation.baseVersion,
            })
          : await this.store.appendEvent({
              ...actor,
              eventId: operation.eventId,
              eventHash: digest(operation.canonicalHashInput),
              kind: operation.kind,
              doseId: operation.doseId,
              scheduleId: operation.scheduleId,
              occurredAt: operation.occurredAt,
              payload: operation.payload,
            });
      acknowledgements.push(toAcknowledgement(operation.operationId, result, operation));
      } catch {
        acknowledgements.push({
          operationId: operation.operationId,
          status: 'rejected',
          code: 'retryable_internal_error',
        });
      }
    }
    return { acknowledgements };
  }
}

export class MedicationSyncPullService {
  constructor(
    private readonly access: MedicationSyncAccessAuthorizer,
    private readonly store: MedicationSyncApplicationStore,
  ) {}

  async pull(input: {
    readonly accountId: string;
    readonly actorType: MedicationSyncActorType;
    readonly robotId: string;
    readonly cursor: number;
    readonly checkpoint?: number;
    readonly limit: number;
  }) {
    const authorized = await this.access.authorize({
      accountId: input.accountId,
      actorType: input.actorType,
      robotId: input.robotId,
    });
    if (authorized == null) throw new MedicationSyncAuthorizationError();
    return this.store.pull({
      robotId: input.robotId,
      cursor: input.cursor,
      limit: input.limit,
      ...(input.checkpoint == null ? {} : { checkpoint: input.checkpoint }),
    });
  }
}

function digest(value: string): string {
  return createHash('sha256').update(value, 'utf8').digest('hex');
}

function toAcknowledgement(
  operationId: string,
  result: MedicationSyncMutationResult,
  operation: MedicationSyncPushOperation,
): MedicationSyncAcknowledgement {
  if (result.status === 'conflict') {
    return {
      operationId,
      status: 'conflict',
      code: result.code,
      ...('currentVersion' in result ? { currentVersion: result.currentVersion } : {}),
      ...('currentDocument' in result ? { currentDocument: result.currentDocument } : {}),
      ...(operation.type === 'appendEvent' ? {} : {
        resourceType: operation.resourceType,
        resourceId: operation.resourceId,
        baseVersion: operation.baseVersion,
      }),
    };
  }
  return {
    operationId,
    status: result.status,
    sequence: result.sequence,
    ...('resourceVersion' in result && result.resourceVersion != null
      ? { resourceVersion: result.resourceVersion }
      : {}),
  };
}
