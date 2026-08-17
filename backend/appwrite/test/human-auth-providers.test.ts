import assert from 'node:assert/strict';
import { test } from 'node:test';

import { parseHumanAuthProviders } from '../src/runtime/human-auth-providers.js';

test('parses the default and explicitly configured human providers', () => {
  assert.deepEqual(parseHumanAuthProviders(undefined), ['google']);
  assert.deepEqual(parseHumanAuthProviders('google'), ['google']);
  assert.deepEqual(parseHumanAuthProviders('email'), ['email']);
  assert.deepEqual(parseHumanAuthProviders('google,email'), ['google', 'email']);
  assert.deepEqual(parseHumanAuthProviders('email,google'), ['email', 'google']);
});

test('rejects blank, duplicate, and unsupported human provider configuration', () => {
  for (const value of ['', ' ', 'google,google', 'email,', ',email', 'google,,email', 'github']) {
    assert.throws(() => parseHumanAuthProviders(value), /human provider/i);
  }
});
