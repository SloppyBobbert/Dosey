import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { createPairingCodeHandler } from '../src/functions/create-pairing-code.js';
import { RobotOwnerRequiredError } from '../src/application/pairing-services.js';

function context(input: {
  method?: string;
  userId?: string;
  body?: unknown;
}) {
  let response: { body: unknown; status: number } | null = null;
  return {
    value: {
      req: {
        method: input.method ?? 'POST',
        headers: { 'x-appwrite-user-id': input.userId },
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

describe('create pairing code function boundary', () => {
  const identity = {
    verify: async (headers: Readonly<Record<string, string | undefined>>) =>
      headers['x-appwrite-user-id'] ?? null,
  };

  test('requires an authenticated owner', async () => {
    const request = context({ body: { robotId: 'robot-1' } });
    const handler = createPairingCodeHandler({
      create: () => Promise.reject(new Error('must not run')),
    }, identity);

    await handler(request.value);

    assert.deepEqual(request.response(), {
      body: { error: 'authentication_required' },
      status: 401,
    });
  });

  test('returns only the plaintext code and expiry after owner authorization', async () => {
    const calls: unknown[] = [];
    const request = context({
      userId: 'owner-1',
      body: { robotId: 'robot-1' },
    });
    const handler = createPairingCodeHandler({
      create(input) {
        calls.push(input);
        return Promise.resolve({
          code: 'ABCDEFGHJK',
          record: {
            id: 'claim-1',
            robotId: 'robot-1',
            codeDigest: 'secret-digest',
            expiresAt: new Date('2026-07-26T12:10:00.000Z'),
            consumedAt: null,
          },
        });
      },
    }, identity);

    await handler(request.value);

    assert.deepEqual(calls, [
      { robotId: 'robot-1', ownerAccountId: 'owner-1' },
    ]);
    assert.deepEqual(request.response(), {
      body: {
        code: 'ABCDEFGHJK',
        expiresAt: '2026-07-26T12:10:00.000Z',
      },
      status: 200,
    });
  });

  test('rejects missing and blank robot IDs before calling the service', async () => {
    for (const body of [{}, { robotId: '   ' }]) {
      let called = false;
      const request = context({ userId: 'owner-1', body });
      const handler = createPairingCodeHandler(
        {
          create: async () => {
            called = true;
            throw new Error('must not run');
          },
        },
        identity,
      );

      await handler(request.value);

      assert.equal(called, false);
      assert.deepEqual(request.response(), {
        body: { error: 'invalid_robot_id' },
        status: 400,
      });
    }
  });

  test('maps owner authorization failures to a safe response', async () => {
    const request = context({
      userId: 'not-owner',
      body: { robotId: 'robot-1' },
    });
    const handler = createPairingCodeHandler(
      { create: async () => { throw new RobotOwnerRequiredError(); } },
      identity,
    );

    await handler(request.value);

    assert.deepEqual(request.response(), {
      body: { error: 'owner_required' },
      status: 403,
    });
  });
});
