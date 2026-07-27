import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  createPairingCode,
  normalizePairingCode,
  pairingCodeAlphabet,
} from '../src/domain/pairing-code.js';

describe('pairing codes', () => {
  test('creates a 10-character code without ambiguous characters', () => {
    const code = createPairingCode((maximum) => maximum - 1);

    assert.equal(code.length, 10);
    assert.match(code, /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{10}$/);
    assert.equal(code, pairingCodeAlphabet.at(-1)?.repeat(10));
  });

  test('normalizes lowercase and a display separator', () => {
    assert.equal(normalizePairingCode('abcd2-efgh3'), 'ABCD2EFGH3');
  });

  test('rejects malformed codes', () => {
    assert.throws(() => normalizePairingCode('ABCD-O12345'), {
      name: 'InvalidPairingCodeError',
    });
  });
});
