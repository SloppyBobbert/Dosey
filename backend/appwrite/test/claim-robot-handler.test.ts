import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  createClaimRobotHandler,
  type ClaimRobotService,
  type FunctionContext,
} from '../src/functions/claim-robot.js';

function context(input: {
  userId?: string;
  body?: unknown;
}): FunctionContext & { responses: Array<{ body: unknown; status: number }> } {
  const responses: Array<{ body: unknown; status: number }> = [];
  return {
    req: {
      method: 'POST',
      headers: input.userId == null ? {} : { 'x-appwrite-user-id': input.userId },
      bodyJson: input.body,
    },
    res: {
      json(body, status = 200) {
        const response = { body, status };
        responses.push(response);
        return response;
      },
    },
    error() {},
    responses,
  };
}

describe('claim robot function boundary', () => {
  test('requires an authenticated device account', async () => {
    const handler = createClaimRobotHandler({
      claimRobot: async () => ({ status: 'accepted', robotId: 'robot-1' }),
    });
    const request = context({ body: { code: 'ABCD2EFGH3' } });

    const response = (await handler(request)) as {
      body: unknown;
      status: number;
    };

    assert.equal(response.status, 401);
    assert.deepEqual(response.body, { error: 'authentication_required' });
  });

  test('rejects malformed codes before calling the service', async () => {
    let called = false;
    const handler = createClaimRobotHandler({
      claimRobot: async () => {
        called = true;
        return { status: 'accepted', robotId: 'robot-1' };
      },
    });
    const request = context({ userId: 'device-1', body: { code: '123' } });

    const response = (await handler(request)) as {
      body: unknown;
      status: number;
    };

    assert.equal(response.status, 400);
    assert.equal(called, false);
    assert.deepEqual(response.body, { error: 'invalid_pairing_code' });
  });

  test('passes only normalized code and authenticated account to the service', async () => {
    let input: Parameters<ClaimRobotService['claimRobot']>[0] | null = null;
    const handler = createClaimRobotHandler({
      claimRobot: async (value) => {
        input = value;
        return { status: 'accepted', robotId: 'robot-1' };
      },
    });
    const request = context({
      userId: 'device-1',
      body: { code: 'abcd2-efgh3' },
    });

    const response = (await handler(request)) as {
      body: unknown;
      status: number;
    };

    assert.deepEqual(input, {
      code: 'ABCD2EFGH3',
      mountedDeviceAccountId: 'device-1',
    });
    assert.equal(response.status, 200);
    assert.deepEqual(response.body, { robotId: 'robot-1' });
  });

  test('maps safe rejection reasons without exposing claim details', async () => {
    const cases: Array<{
      reason: 'invalid' | 'expired' | 'consumed' | 'attempts_exhausted';
      expectedStatus: number;
    }> = [
      { reason: 'invalid', expectedStatus: 400 },
      { reason: 'expired', expectedStatus: 410 },
      { reason: 'consumed', expectedStatus: 409 },
      {
        reason: 'attempts_exhausted',
        expectedStatus: 429,
      },
    ];

    for (const testCase of cases) {
      const handler = createClaimRobotHandler({
        claimRobot: async () => ({ status: 'rejected', reason: testCase.reason }),
      });
      const response = (await handler(
        context({ userId: 'device-1', body: { code: 'ABCD2EFGH3' } }),
      )) as { body: unknown; status: number };
      assert.equal(response.status, testCase.expectedStatus);
      assert.deepEqual(response.body, { error: testCase.reason });
    }
  });
});
