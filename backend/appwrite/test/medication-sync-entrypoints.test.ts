import assert from 'node:assert/strict';
import { test } from 'node:test';

import medicationSyncPull from '../src/entrypoints/medication-sync-pull.js';
import medicationSyncPush from '../src/entrypoints/medication-sync-push.js';

test('exports concrete medication sync Function entrypoints', () => {
  assert.equal(typeof medicationSyncPush, 'function');
  assert.equal(typeof medicationSyncPull, 'function');
});
