import assert from 'node:assert/strict';
import { test } from 'node:test';

import acceptHouseholdInvitation from '../src/entrypoints/accept-household-invitation.js';
import createHouseholdInvitation from '../src/entrypoints/create-household-invitation.js';
import createRobot from '../src/entrypoints/create-robot.js';
import removeHouseholdMember from '../src/entrypoints/remove-household-member.js';

test('exports four household lifecycle Function entrypoints', () => {
  assert.equal(typeof createRobot, 'function');
  assert.equal(typeof createHouseholdInvitation, 'function');
  assert.equal(typeof acceptHouseholdInvitation, 'function');
  assert.equal(typeof removeHouseholdMember, 'function');
});
