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
});
