import {
  MedicationSyncContractError,
  canonicalMutationHashInput,
  parseMedication,
  parsePullPage,
  parsePullRequest,
  parsePushRequest,
  parsePushResponse,
  parseSchedule,
  type Medication,
  type MutationAck,
  type PullPage,
  type PushResponse,
  type Schedule,
} from '../domain/medication-sync-contract.js';
import type {
  MedicationSyncAcknowledgement,
  MedicationSyncPushOperation,
} from '../application/medication-sync-services.js';
import type { MedicationSyncChangeRecord } from '../infrastructure/transactional-medication-sync-store.js';
import type { MedicationSyncRequestParser } from './medication-sync-handlers.js';

export const medicationSyncContractParser: MedicationSyncRequestParser = {
  parsePush(body) {
    try {
      const request = parsePushRequest(body);
      return {
        ok: true,
        value: {
          robotId: request.robotId,
          operations: request.operations.map((mutation) => toApplicationOperation(request.robotId, mutation)),
        },
      };
    } catch (error) {
      if (error instanceof MedicationSyncContractError) return { ok: false, code: error.code };
      throw error;
    }
  },
  parsePull(body) {
    try {
      const request = parsePullRequest(body);
      return {
        ok: true,
        value: {
          robotId: request.robotId,
          cursor: request.cursor == null ? 0 : Number(request.cursor),
          ...(request.checkpoint == null ? {} : { checkpoint: Number(request.checkpoint) }),
          limit: request.limit,
          wireCursor: request.cursor,
        },
      };
    } catch (error) {
      if (error instanceof MedicationSyncContractError) return { ok: false, code: error.code };
      throw error;
    }
  },
};

function toApplicationOperation(
  robotId: string,
  mutation: ReturnType<typeof parsePushRequest>['operations'][number],
): MedicationSyncPushOperation {
  const common = {
    operationId: mutation.mutationId,
    idempotencyKey: mutation.idempotencyKey,
    deviceId: mutation.deviceId,
    canonicalHashInput: canonicalMutationHashInput(robotId, mutation),
  };
  if (mutation.entityType === 'dose_event') {
    if (mutation.payload.kind === 'missed') {
      throw new MedicationSyncContractError(
        'MISSED_EVENT_NOT_IMPLEMENTED',
        '$.operations[].payload.kind',
        'The wire contract defines missed, but the sync service does not implement it yet.',
      );
    }
    return {
      ...common,
      type: 'appendEvent',
      eventId: mutation.entityId,
      kind: mutation.payload.kind,
      doseId: mutation.payload.occurrence.occurrenceId,
      scheduleId: mutation.payload.occurrence.scheduleId,
      occurredAt: new Date(mutation.payload.occurredAt),
      payload: JSON.stringify(mutation.payload),
    };
  }
  if (mutation.operation === 'delete') {
    return {
      ...common,
      type: 'archiveDocument',
      resourceType: mutation.entityType,
      resourceId: mutation.entityId,
      baseVersion: mutation.baseRevision,
    };
  }
  return {
    ...common,
    type: 'upsertDocument',
    resourceType: mutation.entityType,
    resourceId: mutation.entityId,
    baseVersion: mutation.baseRevision ?? 0,
    payload: JSON.stringify(mutation.payload),
  };
}

export function serializeMedicationSyncPushResponse(
  robotId: string,
  acknowledgements: readonly MedicationSyncAcknowledgement[],
): PushResponse {
  return parsePushResponse({
    contractVersion: 1,
    robotId,
    acknowledgements: acknowledgements.map(toWireAcknowledgement),
  });
}

function toWireAcknowledgement(ack: MedicationSyncAcknowledgement): MutationAck {
  if (ack.status === 'applied' || ack.status === 'duplicate') {
    return {
      contractVersion: 1,
      mutationId: ack.operationId,
      outcome: ack.status,
      revision: ack.resourceVersion ?? null,
      cursor: String(ack.sequence),
      errorCode: null,
      conflict: null,
    };
  }
  if (
    ack.status === 'conflict' &&
    ack.code === 'version_conflict' &&
    ack.currentDocument != null &&
    ack.currentVersion != null &&
    ack.resourceType != null &&
    ack.resourceId != null &&
    ack.baseVersion != null && ack.baseVersion >= 0 &&
    ack.currentVersion >= 1
  ) {
    return {
      contractVersion: 1,
      mutationId: ack.operationId,
      outcome: 'conflict',
      revision: null,
      cursor: null,
      errorCode: null,
      conflict: {
        contractVersion: 1,
        entityType: ack.resourceType,
        entityId: ack.resourceId,
        expectedRevision: ack.baseVersion,
        actualRevision: ack.currentVersion,
        authoritativeRecord: parseAuthoritativeRecord(ack.resourceType, ack.currentDocument.payload),
      },
    };
  }
  return {
    contractVersion: 1,
    mutationId: ack.operationId,
    outcome: 'rejected',
    revision: null,
    cursor: null,
    errorCode: errorCode(ack.code),
    conflict: null,
  };
}

function errorCode(code: string | undefined): string {
  switch (code) {
    case 'owner_required': return 'OWNER_REQUIRED';
    case 'operation_id_reused': return 'IDEMPOTENCY_KEY_REUSED';
    case 'event_id_reused': return 'EVENT_ID_REUSED';
    case 'version_conflict': return 'VERSION_CONFLICT';
    case 'retryable_internal_error': return 'RETRYABLE_INTERNAL_ERROR';
    default: return 'MUTATION_REJECTED';
  }
}

export function serializeMedicationSyncPullPage(input: {
  readonly robotId: string;
  readonly cursor: string | null;
  readonly changes: readonly MedicationSyncChangeRecord[];
  readonly nextCursor: number;
  readonly checkpoint: number;
  readonly complete: boolean;
}): PullPage {
  return parsePullPage({
    contractVersion: 1,
    robotId: input.robotId,
    cursor: input.cursor,
    checkpoint: String(input.checkpoint),
    nextCursor: String(input.nextCursor),
    hasMore: !input.complete,
    changes: input.changes.map((change) => ({
      cursor: String(change.sequence),
      entityType: change.resourceType === 'doseEvent' ? 'dose_event' : change.resourceType,
      entityId: change.resourceId,
      operation: change.operation === 'archive'
        ? 'delete'
        : change.operation === 'event'
          ? 'append'
          : 'upsert',
      record: JSON.parse(change.payload) as Medication | Schedule,
    })),
  });
}

export function parseAuthoritativeRecord(
  resourceType: 'medication' | 'schedule',
  payload: string,
): Medication | Schedule {
  const value = JSON.parse(payload) as unknown;
  return resourceType === 'medication' ? parseMedication(value) : parseSchedule(value);
}
