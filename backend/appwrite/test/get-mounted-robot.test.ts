import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import type {
  MountedRobotAccessRecord,
  RobotInstallationRecord,
} from '../src/domain/mounted-robot-access.js';
import {
  GetMountedRobotService,
  type MountedRobotLookup,
} from '../src/application/mounted-robot-services.js';
import {
  createGetMountedRobotHandler,
  type FunctionContext,
} from '../src/functions/get-mounted-robot.js';

function context(bodyJson: unknown, userId = 'device-1', userJwt = 'jwt') {
  const responses: Array<{ body: unknown; status: number }> = [];
  const value: FunctionContext & { responses: typeof responses } = {
    req: {
      method: 'POST',
      headers: { 'x-appwrite-user-id': userId, 'x-appwrite-user-jwt': userJwt },
      bodyJson,
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
  return value;
}

const access: MountedRobotAccessRecord = {
  robotId: 'robot-1',
  mountedDeviceAccountId: 'device-1',
  pairingClaimId: 'claim-1',
  createdAt: new Date('2026-07-26T12:00:00.000Z'),
  updatedAt: new Date('2026-07-26T12:00:00.000Z'),
};

const installation: RobotInstallationRecord = {
  robotId: 'robot-1',
  displayName: 'Kitchen Dosey',
  status: 'active',
};

class FakeLookup implements MountedRobotLookup {
  accesses: readonly MountedRobotAccessRecord[] = [access];
  robot: RobotInstallationRecord | null = installation;
  calls: string[] = [];

  findByDevice(accountId: string) {
    this.calls.push(`access:${accountId}`);
    return Promise.resolve(this.accesses);
  }

  getRobotInstallation(robotId: string) {
    this.calls.push(`robot:${robotId}`);
    return Promise.resolve(this.robot);
  }
}

describe('get mounted robot function', () => {
  const anonymousIdentity = {
    verifyAnonymous: async () => 'device-1',
  };

  test('returns only the mounted robot identity and display name', async () => {
    const lookup = new FakeLookup();
    const handler = createGetMountedRobotHandler(
      new GetMountedRobotService(lookup),
      anonymousIdentity,
    );

    const response = (await handler(context({}))) as { body: unknown; status: number };
    assert.deepEqual(response, {
      body: { robot: { robotId: 'robot-1', displayName: 'Kitchen Dosey' } },
      status: 200,
    });
    assert.deepEqual(lookup.calls, ['access:device-1', 'robot:robot-1']);
    assertPrivacySafe(response.body);
  });

  test('returns null only after a successful empty access lookup', async () => {
    const lookup = new FakeLookup();
    lookup.accesses = [];
    const response = (await createGetMountedRobotHandler(
      new GetMountedRobotService(lookup), anonymousIdentity,
    )(context({}))) as { body: unknown; status: number };

    assert.deepEqual(response, { body: { robot: null }, status: 200 });
    assert.deepEqual(lookup.calls, ['access:device-1']);
  });

  test('rejects a provisioning installation without returning a robot identity', async () => {
    const lookup = new FakeLookup();
    lookup.robot = { ...installation, status: 'provisioning' };

    await assert.rejects(
      new GetMountedRobotService(lookup).get('device-1'),
      /missing or inactive/,
    );
  });

  test('rejects duplicate access rows and missing installations as integrity failures', async () => {
    const duplicate = new FakeLookup();
    duplicate.accesses = [access, { ...access, robotId: 'robot-2' }];
    await assert.rejects(
      new GetMountedRobotService(duplicate).get('device-1'),
      /Multiple mounted robot access rows/,
    );

    const missing = new FakeLookup();
    missing.robot = null;
    await assert.rejects(
      new GetMountedRobotService(missing).get('device-1'),
      /Mounted robot installation is missing/,
    );
  });

  test('propagates access database failures instead of returning null', async () => {
    const lookup: MountedRobotLookup = {
      findByDevice: async () => { throw new Error('database unavailable'); },
      getRobotInstallation: async () => installation,
    };
    await assert.rejects(
      new GetMountedRobotService(lookup).get('device-1'),
      /database unavailable/,
    );
  });

  test('maps authentication and provider results without exposing details', async () => {
    const service = new GetMountedRobotService(new FakeLookup());
    for (const result of [null, { reason: 'provider' } as const]) {
      const handler = createGetMountedRobotHandler(service, {
        verifyAnonymous: async () => result,
      });
      const response = (await handler(context({}))) as { body: unknown; status: number };
      assert.equal(response.status, result == null ? 401 : 403);
      assert.deepEqual(response.body, {
        error: result == null ? 'authentication_required' : 'anonymous_account_required',
      });
    }
  });

  test('requires an empty object request body', async () => {
    const handler = createGetMountedRobotHandler(
      new GetMountedRobotService(new FakeLookup()), anonymousIdentity,
    );
    for (const body of [null, [], { extra: true }]) {
      const response = (await handler(context(body))) as { body: unknown; status: number };
      assert.equal(response.status, 400);
      assert.deepEqual(response.body, { error: 'invalid_request' });
    }
  });
});

const forbiddenKeys = /owner|account|user|membership|member|email|name|label|role/i;

function assertPrivacySafe(value: unknown): void {
  if (Array.isArray(value)) {
    for (const item of value) assertPrivacySafe(item);
    return;
  }
  if (value == null || typeof value !== 'object') return;
  for (const [key, child] of Object.entries(value)) {
    assert.equal(
      key !== 'displayName' && forbiddenKeys.test(key),
      false,
      `forbidden response key: ${key}`,
    );
    assertPrivacySafe(child);
  }
}
