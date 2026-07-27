import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { HouseholdFailure } from '../src/application/household-services.js';
import {
  acceptHouseholdInvitationHandler,
  createHouseholdInvitationHandler,
  createRobotHandler,
  removeHouseholdMemberHandler,
} from '../src/functions/household-handlers.js';

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

const ownerIdentity = {
  verifyHuman: async () => ({ accountId: 'owner-1', email: 'owner@example.com' }),
};

const snapshot = {
  robotId: 'robot-1',
  displayName: 'Kitchen Dosey',
  ownerAccountId: 'owner-1',
  mountedDeviceId: null,
  currentRole: 'owner' as const,
  members: [{ accountId: 'owner-1', label: 'Owner', role: 'owner' as const }],
};

describe('household function boundaries', () => {
  test('requires a verified human identity', async () => {
    const request = context({ body: { displayName: 'Dosey' } });
    const handler = createRobotHandler(
      { create: async () => { throw new Error('must not run'); } },
      { verifyHuman: async () => null },
    );

    await handler(request.value);

    assert.deepEqual(request.response(), {
      body: { error: 'authentication_required' },
      status: 401,
    });
  });

  test('creates a robot for the authenticated account', async () => {
    const calls: unknown[] = [];
    const request = context({ body: { displayName: ' Kitchen Dosey ' } });
    const handler = createRobotHandler({
      create(input) {
        calls.push(input);
        return Promise.resolve(snapshot);
      },
    }, ownerIdentity);

    await handler(request.value);

    assert.deepEqual(calls, [{ accountId: 'owner-1', displayName: 'Kitchen Dosey' }]);
    assert.deepEqual(request.response(), { body: snapshot, status: 200 });
  });

  test('returns invitation plaintext once without persistence details', async () => {
    const calls: unknown[] = [];
    const request = context({
      body: { robotId: 'robot-1', email: ' Person@Example.com ' },
    });
    const handler = createHouseholdInvitationHandler({
      create(input) {
        calls.push(input);
        return Promise.resolve({
          code: 'ABCD2EFGH3JKMNPQ',
          expiresAt: new Date('2026-07-27T12:00:00.000Z'),
        });
      },
    }, ownerIdentity);

    await handler(request.value);

    assert.deepEqual(calls, [{
      robotId: 'robot-1',
      ownerAccountId: 'owner-1',
      invitedEmail: 'Person@Example.com',
    }]);
    assert.deepEqual(request.response(), {
      body: {
        code: 'ABCD2EFGH3JKMNPQ',
        expiresAt: '2026-07-27T12:00:00.000Z',
      },
      status: 200,
    });
  });

  test('accepts an invitation using the verified account email', async () => {
    const calls: unknown[] = [];
    const request = context({ body: { code: 'ABCD2-EFGH3-JKMNPQ' } });
    const handler = acceptHouseholdInvitationHandler({
      accept(input) {
        calls.push(input);
        return Promise.resolve({ ...snapshot, currentRole: 'member' as const });
      },
    }, ownerIdentity);

    await handler(request.value);

    assert.deepEqual(calls, [{
      accountId: 'owner-1',
      email: 'owner@example.com',
      code: 'ABCD2-EFGH3-JKMNPQ',
    }]);
    assert.equal(request.response()?.status, 200);
  });

  test('uses the current account as the target when leaving', async () => {
    const calls: unknown[] = [];
    const request = context({ body: { robotId: 'robot-1' } });
    const handler = removeHouseholdMemberHandler({
      remove(input) {
        calls.push(input);
        return Promise.resolve(null);
      },
    }, ownerIdentity);

    await handler(request.value);

    assert.deepEqual(calls, [{
      robotId: 'robot-1',
      actorAccountId: 'owner-1',
      targetAccountId: 'owner-1',
    }]);
    assert.deepEqual(request.response(), { body: { removed: true }, status: 200 });
  });

  test('maps household failures to stable safe statuses', async () => {
    const cases = [
      ['already_linked', 409],
      ['household_full', 409],
      ['invalid_invitation', 400],
      ['invitation_expired', 410],
      ['email_mismatch', 403],
      ['owner_required', 403],
      ['owner_cannot_leave', 409],
      ['member_not_found', 404],
    ] as const;

    for (const [code, status] of cases) {
      const request = context({ body: { displayName: 'Dosey' } });
      const handler = createRobotHandler({
        create: async () => { throw new HouseholdFailure(code); },
      }, ownerIdentity);
      await handler(request.value);
      assert.deepEqual(request.response(), { body: { error: code }, status });
    }
  });

  test('rejects malformed request fields before calling services', async () => {
    const invalidRequests = [
      createRobotHandler({ create: async () => { throw new Error('must not run'); } }, ownerIdentity),
      createHouseholdInvitationHandler({ create: async () => { throw new Error('must not run'); } }, ownerIdentity),
      acceptHouseholdInvitationHandler({ accept: async () => { throw new Error('must not run'); } }, ownerIdentity),
      removeHouseholdMemberHandler({ remove: async () => { throw new Error('must not run'); } }, ownerIdentity),
    ];

    for (const handler of invalidRequests) {
      const request = context({ body: {} });
      await handler(request.value);
      assert.equal(request.response()?.status, 400);
    }
  });
});
