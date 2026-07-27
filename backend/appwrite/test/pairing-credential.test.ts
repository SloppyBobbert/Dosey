import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { describe, test } from 'node:test';

import {
  issuePairingCredential,
  pairingCodeLifetimeMs,
} from '../src/application/pairing-credential.js';

describe('pairing credential issuance', () => {
  test('stores a keyed digest and expires after 10 minutes', () => {
    const now = new Date('2026-07-26T12:00:00.000Z');
    const secret = 'server-only-secret-at-least-32-bytes';
    const credential = issuePairingCredential({
      robotId: 'robot-1',
      claimId: 'claim-1',
      secret,
      now,
      selectIndex: () => 0,
    });

    const expectedDigest = createHmac('sha256', secret)
      .update(credential.code)
      .digest('hex');
    assert.equal(credential.record.codeDigest, expectedDigest);
    assert.notEqual(credential.record.codeDigest, credential.code);
    assert.equal(
      credential.record.expiresAt.getTime(),
      now.getTime() + pairingCodeLifetimeMs,
    );
    assert.equal(credential.record.consumedAt, null);
  });
});
