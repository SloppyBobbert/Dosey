import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { createHouseholdRuntime } from '../src/runtime/household-runtime.js';

const environment = {
  APPWRITE_FUNCTION_API_ENDPOINT: 'https://cloud.example/v1',
  APPWRITE_FUNCTION_PROJECT_ID: 'project-1',
  DOSEY_DATABASE_ID: 'database-1',
  DOSEY_ROBOT_INSTALLATIONS_TABLE_ID: 'robots',
  DOSEY_HUMAN_ROBOT_LINKS_TABLE_ID: 'links',
  DOSEY_HOUSEHOLD_INVITATIONS_TABLE_ID: 'invitations',
  DOSEY_HOUSEHOLD_INVITATION_HMAC_SECRET: 'household-secret-at-least-32-bytes',
};

describe('household runtime', () => {
  test('reports rollback failures without provider error details', async () => {
    const secret = 'APPWRITE_KEY=rollback-secret-user-id-123';
    const reported: string[] = [];
    const runtime = createHouseholdRuntime(
      { 'x-appwrite-key': 'dynamic-key' },
      environment,
      (message) => reported.push(message),
    );
    const persistence = (runtime.createInvitation as unknown as {
      dependencies: { registry: { persistence: RuntimePersistence } };
    }).dependencies.registry.persistence;
    persistence.rows = {
      beginTransaction: async () => 'transaction-1',
      rollbackTransaction: async () => { throw new Error(secret); },
    };
    const original = new Error('operation failed');

    await assert.rejects(
      persistence.transaction(async () => { throw original; }),
      (error: unknown) => error === original,
    );

    assert.deepEqual(reported, ['Household transaction rollback failed.']);
    assert.equal(reported.some((message) => message.includes(secret)), false);
  });

  test('constructs all four services from server-only configuration', () => {
    const runtime = createHouseholdRuntime(
      {
        'x-appwrite-key': 'dynamic-key',
        'x-appwrite-user-jwt': 'user-jwt',
      },
      environment,
    );

    assert.ok(runtime.identity);
    assert.ok(runtime.createRobot);
    assert.ok(runtime.createInvitation);
    assert.ok(runtime.acceptInvitation);
    assert.ok(runtime.removeMember);
  });

  test('requires the separate household invitation secret', () => {
    const { DOSEY_HOUSEHOLD_INVITATION_HMAC_SECRET: _, ...missingSecret } = environment;

    assert.throws(
      () => createHouseholdRuntime(
        { 'x-appwrite-key': 'dynamic-key', 'x-appwrite-user-jwt': 'user-jwt' },
        missingSecret,
      ),
      /DOSEY_HOUSEHOLD_INVITATION_HMAC_SECRET/,
    );
  });

  test('constructs without a user JWT so identity verification can return 401', async () => {
    const runtime = createHouseholdRuntime({ 'x-appwrite-key': 'dynamic-key' }, environment);

    assert.equal(await runtime.identity.verifyHuman({
      'x-appwrite-user-id': 'owner-1',
    }), null);
  });
});

type RuntimePersistence = {
  rows: {
    beginTransaction(): Promise<string>;
    rollbackTransaction(transactionId: string): Promise<void>;
  };
  transaction<T>(operation: () => Promise<T>): Promise<T>;
};
