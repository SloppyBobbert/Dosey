import {
  MedicationSyncAuthorizationError,
  type MedicationSyncAcknowledgement,
  type MedicationSyncPushOperation,
} from '../application/medication-sync-services.js';
import type { MedicationSyncChangeRecord } from '../infrastructure/transactional-medication-sync-store.js';
import type { FunctionContext } from './claim-robot.js';
import type {
  AnonymousFunctionIdentityVerifier,
  HumanFunctionIdentityVerifier,
} from './function-identity.js';
import type { MedicationSyncActorType } from '../application/household-access.js';
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
    readonly actorType: MedicationSyncActorType;
    readonly robotId: string;
    readonly operations: readonly MedicationSyncPushOperation[];
  }): Promise<{ readonly acknowledgements: readonly MedicationSyncAcknowledgement[] }>;
}

interface MedicationSyncPullApplication {
  pull(input: {
    readonly accountId: string;
    readonly actorType: MedicationSyncActorType;
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

type MedicationSyncIdentityVerifier = HumanFunctionIdentityVerifier & AnonymousFunctionIdentityVerifier;
type MedicationSyncPrincipal = {
  readonly accountId: string;
  readonly actorType: MedicationSyncActorType;
};

export function medicationSyncPushHandler(
  service: MedicationSyncPushApplication,
  identity: MedicationSyncIdentityVerifier,
  parser: MedicationSyncRequestParser,
) {
  return medicationSyncHandler(identity, async (context, principal) => {
    const parsed = parser.parsePush(context.req.bodyJson);
    if (!parsed.ok) return context.res.json({ error: parsed.code }, 400);
    const result = await service.push({
      accountId: principal.accountId,
      actorType: principal.actorType,
      robotId: parsed.value.robotId,
      operations: parsed.value.operations,
    });
    return context.res.json(serializeMedicationSyncPushResponse(parsed.value.robotId, result.acknowledgements));
  });
}

export function medicationSyncPullHandler(
  service: MedicationSyncPullApplication,
  identity: MedicationSyncIdentityVerifier,
  parser: MedicationSyncRequestParser,
) {
  return medicationSyncHandler(identity, async (context, principal) => {
    const parsed = parser.parsePull(context.req.bodyJson);
    if (!parsed.ok) return context.res.json({ error: parsed.code }, 400);
    const result = await service.pull({
      accountId: principal.accountId,
      actorType: principal.actorType,
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
  identity: MedicationSyncIdentityVerifier,
  operation: (context: FunctionContext, principal: MedicationSyncPrincipal) => Promise<unknown>,
) {
  return async (context: FunctionContext) => {
    if (context.req.method !== 'POST') {
      return context.res.json({ error: 'method_not_allowed' }, 405);
    }
    const human = await identity.verifyHuman(context.req.headers);
    const anonymous = human == null
      ? await identity.verifyAnonymous(context.req.headers)
      : null;
    const principal: MedicationSyncPrincipal | null = human != null
      ? { accountId: human.accountId, actorType: 'human' }
      : typeof anonymous === 'string'
        ? { accountId: anonymous, actorType: 'device' }
        : null;
    if (principal == null) {
      return context.res.json({ error: 'authentication_required' }, 401);
    }
    try {
      return await operation(context, principal);
    } catch (error) {
      if (error instanceof MedicationSyncAuthorizationError) {
        return context.res.json({ error: 'household_access_denied' }, 403);
      }
      return context.res.json({ error: 'retryable_internal_error' }, 500);
    }
  };
}
