import {
  MedicationSyncAuthorizationError,
  type MedicationSyncAcknowledgement,
  type MedicationSyncPushOperation,
} from '../application/medication-sync-services.js';
import type { MedicationSyncChangeRecord } from '../infrastructure/transactional-medication-sync-store.js';
import type { FunctionContext } from './claim-robot.js';
import type { HumanFunctionIdentityVerifier } from './function-identity.js';
import {
  serializeMedicationSyncPullPage,
  serializeMedicationSyncPushResponse,
} from './medication-sync-contract-adapter.js';

type ParseResult<T> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly code: string };

export interface MedicationSyncRequestParser {
  parsePush(body: unknown): ParseResult<{
    readonly robotId: string;
    readonly operations: readonly MedicationSyncPushOperation[];
  }>;
  parsePull(body: unknown): ParseResult<{
    readonly robotId: string;
    readonly cursor: number;
    readonly checkpoint?: number;
    readonly limit: number;
    readonly wireCursor?: string | null;
  }>;
}

interface MedicationSyncPushApplication {
  push(input: {
    readonly accountId: string;
    readonly robotId: string;
    readonly operations: readonly MedicationSyncPushOperation[];
  }): Promise<{ readonly acknowledgements: readonly MedicationSyncAcknowledgement[] }>;
}

interface MedicationSyncPullApplication {
  pull(input: {
    readonly accountId: string;
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

export function medicationSyncPushHandler(
  service: MedicationSyncPushApplication,
  identity: HumanFunctionIdentityVerifier,
  parser: MedicationSyncRequestParser,
) {
  return medicationSyncHandler(identity, async (context, accountId) => {
    const parsed = parser.parsePush(context.req.bodyJson);
    if (!parsed.ok) return context.res.json({ error: parsed.code }, 400);
    const result = await service.push({
      accountId,
      robotId: parsed.value.robotId,
      operations: parsed.value.operations,
    });
    return context.res.json(serializeMedicationSyncPushResponse(parsed.value.robotId, result.acknowledgements));
  });
}

export function medicationSyncPullHandler(
  service: MedicationSyncPullApplication,
  identity: HumanFunctionIdentityVerifier,
  parser: MedicationSyncRequestParser,
) {
  return medicationSyncHandler(identity, async (context, accountId) => {
    const parsed = parser.parsePull(context.req.bodyJson);
    if (!parsed.ok) return context.res.json({ error: parsed.code }, 400);
    const result = await service.pull({
      accountId,
      robotId: parsed.value.robotId,
      cursor: parsed.value.cursor,
      limit: parsed.value.limit,
      ...(parsed.value.checkpoint == null ? {} : { checkpoint: parsed.value.checkpoint }),
    });
    return context.res.json(serializeMedicationSyncPullPage({
      robotId: parsed.value.robotId,
      cursor: parsed.value.wireCursor ?? null,
      ...result,
    }));
  });
}

function medicationSyncHandler(
  identity: HumanFunctionIdentityVerifier,
  operation: (context: FunctionContext, accountId: string) => Promise<unknown>,
) {
  return async (context: FunctionContext) => {
    if (context.req.method !== 'POST') {
      return context.res.json({ error: 'method_not_allowed' }, 405);
    }
    const human = await identity.verifyHuman(context.req.headers);
    if (human == null) {
      return context.res.json({ error: 'authentication_required' }, 401);
    }
    try {
      return await operation(context, human.accountId);
    } catch (error) {
      if (error instanceof MedicationSyncAuthorizationError) {
        return context.res.json({ error: 'household_access_denied' }, 403);
      }
      throw error;
    }
  };
}
