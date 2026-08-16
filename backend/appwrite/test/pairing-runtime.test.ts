import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { createPairingRuntime } from '../src/runtime/pairing-runtime.js';

const environment = {
  APPWRITE_FUNCTION_API_ENDPOINT: 'https://cloud.example/v1',
  APPWRITE_FUNCTION_PROJECT_ID: 'project-1',
  DOSEY_DATABASE_ID: 'database-1',
  DOSEY_PAIRING_CLAIMS_TABLE_ID: 'claims',
  DOSEY_PAIRING_ATTEMPTS_TABLE_ID: 'attempts',
  DOSEY_MOUNTED_ROBOT_ACCESS_TABLE_ID: 'mounted-access',
  DOSEY_PAIRING_HMAC_SECRET: 'pairing-secret-at-least-32-bytes',
};

describe('pairing runtime account adapter', () => {
  test('reports rollback failures without provider error details', async () => {
    const secret = 'APPWRITE_KEY=rollback-secret-user-id-123';
    const reported: string[] = [];
    const runtime = createPairingRuntime(
      { 'x-appwrite-key': 'dynamic-key' },
      environment,
      (message) => reported.push(message),
    );
    const persistence = (runtime.createPairingCode as unknown as {
      dependencies: { store: { persistence: RuntimePersistence } };
    }).dependencies.store.persistence;
    persistence.rows = {
      beginTransaction: async () => 'transaction-1',
      rollbackTransaction: async () => { throw new Error(secret); },
    };
    const original = new Error('operation failed');

    await assert.rejects(
      persistence.transaction(async () => { throw original; }),
      (error: unknown) => error === original,
    );

    assert.deepEqual(reported, ['Pairing transaction rollback failed.']);
    assert.equal(reported.some((message) => message.includes(secret)), false);
  });

  test('requires mounted access configuration only for claim runtime use', () => {
    const { DOSEY_MOUNTED_ROBOT_ACCESS_TABLE_ID: _, ...withoutMountedAccess } = environment;
    assert.doesNotThrow(() => createPairingRuntime(
      { 'x-appwrite-key': 'dynamic-key' },
      withoutMountedAccess,
      () => {},
      undefined,
      false,
    ));
    assert.throws(() => createPairingRuntime(
      { 'x-appwrite-key': 'dynamic-key' },
      withoutMountedAccess,
    ), /DOSEY_MOUNTED_ROBOT_ACCESS_TABLE_ID/);
  });

  test('uses the forwarded JWT for both account and current-session proof', async () => {
    let received: { endpoint: string; projectId: string; jwt: string } | null = null;
    const calls: string[] = [];
    const runtime = createPairingRuntime(
      {
        'x-appwrite-key': 'dynamic-key',
        'x-appwrite-user-jwt': 'forwarded-user-jwt',
      },
      environment,
      () => {},
      (endpoint, projectId, jwt) => {
        received = { endpoint, projectId, jwt };
        return {
          get: async () => {
            calls.push('account.get');
            return { $id: 'device-1' };
          },
          getSession: async (input: { sessionId: string }) => {
            calls.push(`account.getSession:${input.sessionId}`);
            return { userId: 'device-1', provider: 'anonymous' };
          },
        };
      },
    );

    assert.equal(
      await runtime.identity.verifyAnonymous({
        'x-appwrite-user-id': 'device-1',
        'x-appwrite-user-jwt': 'forwarded-user-jwt',
      }),
      'device-1',
    );
    assert.deepEqual(received, {
      endpoint: environment.APPWRITE_FUNCTION_API_ENDPOINT,
      projectId: environment.APPWRITE_FUNCTION_PROJECT_ID,
      jwt: 'forwarded-user-jwt',
    });
    assert.deepEqual(calls.sort(), ['account.get', 'account.getSession:current']);
  });
});

type RuntimePersistence = {
  rows: {
    beginTransaction(): Promise<string>;
    rollbackTransaction(transactionId: string): Promise<void>;
  };
  transaction<T>(operation: () => Promise<T>): Promise<T>;
};
