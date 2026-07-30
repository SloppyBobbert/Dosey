import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { MedicationSyncAuthorizationError } from '../src/application/medication-sync-services.js';
import {
  medicationSyncPullHandler,
  medicationSyncPushHandler,
  type MedicationSyncRequestParser,
} from '../src/functions/medication-sync-handlers.js';

function context(input: { method?: string; body?: unknown } = {}) {
  let response: { body: unknown; status: number } | null = null;
  return {
    value: {
      req: {
        method: input.method ?? 'POST',
        headers: {
          'x-appwrite-user-id': 'owner-1',
          'x-appwrite-user-jwt': 'jwt',
        },
        bodyJson: input.body,
      },
      res: {
        json(body: unknown, status = 200) {
          response = { body, status };
          return response;
        },
      },
      error() {},
    },
    response: () => response,
  };
}

const identity = {
  verifyHuman: async () => ({ accountId: 'owner-1', email: 'owner@example.com' }),
};

const parser: MedicationSyncRequestParser = {
  parsePush: () => ({ ok: true, value: { robotId: 'robot-1', operations: [] } }),
  parsePull: () => ({
    ok: true,
    value: { robotId: 'robot-1', cursor: 0, limit: 50 },
  }),
};

describe('Medication sync function boundaries', () => {
  test('requires POST and a verified human before parsing', async () => {
    let parsed = false;
    const guardedParser: MedicationSyncRequestParser = {
      parsePush: () => { parsed = true; return parser.parsePush({}); },
      parsePull: parser.parsePull,
    };
    const service = { push: async () => ({ acknowledgements: [] }) };

    const wrongMethod = context({ method: 'GET' });
    await medicationSyncPushHandler(service, identity, guardedParser)(wrongMethod.value);
    assert.deepEqual(wrongMethod.response(), {
      body: { error: 'method_not_allowed' }, status: 405,
    });

    const unauthenticated = context();
    await medicationSyncPushHandler(
      service,
      { verifyHuman: async () => null },
      guardedParser,
    )(unauthenticated.value);
    assert.deepEqual(unauthenticated.response(), {
      body: { error: 'authentication_required' }, status: 401,
    });
    assert.equal(parsed, false);
  });

  test('returns the parser error without calling push', async () => {
    const request = context({ body: { operations: 'not-an-array' } });
    await medicationSyncPushHandler(
      { push: async () => { throw new Error('must not run'); } },
      identity,
      {
        ...parser,
        parsePush: () => ({ ok: false, code: 'invalid_sync_envelope' }),
      },
    )(request.value);

    assert.deepEqual(request.response(), {
      body: { error: 'invalid_sync_envelope' }, status: 400,
    });
  });

  test('uses only the authenticated account when calling push', async () => {
    const calls: unknown[] = [];
    const request = context({ body: { accountId: 'forged' } });
    await medicationSyncPushHandler({
      push: async (input) => {
        calls.push(input);
        return { acknowledgements: [{ operationId: 'operation-1', status: 'applied' as const, sequence: 1 }] };
      },
    }, identity, parser)(request.value);

    assert.deepEqual(calls, [{ accountId: 'owner-1', robotId: 'robot-1', operations: [] }]);
    assert.deepEqual(request.response(), {
      body: {
        contractVersion: 1,
        robotId: 'robot-1',
        acknowledgements: [{
          contractVersion: 1, mutationId: 'operation-1', outcome: 'applied', revision: null,
          cursor: '1', errorCode: null, conflict: null,
        }],
      },
      status: 200,
    });
  });

  test('maps household authorization denial to a detail-free forbidden response', async () => {
    const request = context();
    await medicationSyncPushHandler({
      push: async () => { throw new MedicationSyncAuthorizationError(); },
    }, identity, parser)(request.value);

    assert.deepEqual(request.response(), {
      body: { error: 'household_access_denied' }, status: 403,
    });
  });

  test('serializes pull changes from the fixed checkpoint', async () => {
    const request = context();
    await medicationSyncPullHandler({
      pull: async () => ({
        changes: [{
          robotId: 'robot-1', sequence: 3, resourceType: 'medication' as const,
          resourceId: 'medication-1', resourceVersion: 2, operation: 'upsert' as const,
          payload: JSON.stringify({
            contractVersion: 1, id: 'medication-1', householdId: 'robot-1',
            name: 'Morning', pillType: 'pill', instructions: null, revision: 2,
            deletedAt: null, updatedAt: '2026-07-29T10:00:00.000Z',
          }), actorAccountId: 'owner-1', actorRole: 'owner' as const,
          changedAt: new Date('2026-07-29T10:00:00Z'), idempotencyKey: 'operation-1',
          operationHash: 'server-only-hash',
        }],
        nextCursor: 3,
        checkpoint: 4,
        complete: false,
      }),
    }, identity, parser)(request.value);

    assert.deepEqual(request.response(), {
      body: {
        contractVersion: 1,
        robotId: 'robot-1',
        cursor: null,
        checkpoint: '4',
        nextCursor: '3',
        hasMore: true,
        changes: [{
          cursor: '3', entityType: 'medication', entityId: 'medication-1', operation: 'upsert',
          record: {
            contractVersion: 1, id: 'medication-1', householdId: 'robot-1',
            name: 'Morning', pillType: 'pill', instructions: null, revision: 2,
            deletedAt: null, updatedAt: '2026-07-29T10:00:00.000Z',
          },
        }],
      },
      status: 200,
    });
  });
});
