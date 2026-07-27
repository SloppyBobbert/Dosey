import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  evaluatePairingClaim,
  type PairingClaimRecord,
} from '../src/domain/pairing-claim.js';

const now = new Date('2026-07-26T12:00:00.000Z');

function claim(overrides: Partial<PairingClaimRecord> = {}): PairingClaimRecord {
  return {
    id: 'claim-1',
    robotId: 'robot-1',
    codeDigest: 'expected-digest',
    expiresAt: new Date('2026-07-26T12:10:00.000Z'),
    failedAttempts: 0,
    consumedAt: null,
    ...overrides,
  };
}

describe('pairing claim evaluation', () => {
  test('consumes a matching unexpired code once', () => {
    const result = evaluatePairingClaim({
      record: claim(),
      presentedDigest: 'expected-digest',
      mountedDeviceAccountId: 'device-1',
      now,
    });

    assert.equal(result.status, 'accepted');
    assert.equal(result.record.consumedAt?.toISOString(), now.toISOString());
    assert.equal(result.record.mountedDeviceAccountId, 'device-1');
  });

  test('increments failed attempts without consuming a mismatched code', () => {
    const result = evaluatePairingClaim({
      record: claim({ failedAttempts: 2 }),
      presentedDigest: 'wrong-digest',
      mountedDeviceAccountId: 'device-1',
      now,
    });

    assert.equal(result.status, 'rejected');
    assert.equal(result.reason, 'invalid');
    assert.equal(result.record.failedAttempts, 3);
    assert.equal(result.record.consumedAt, null);
  });

  test('rejects expired, consumed, and attempt-exhausted claims', () => {
    const cases: Array<{
      record: PairingClaimRecord;
      reason: 'expired' | 'consumed' | 'attempts_exhausted';
    }> = [
      {
        record: claim({ expiresAt: now }),
        reason: 'expired',
      },
      {
        record: claim({ consumedAt: new Date('2026-07-26T11:59:00.000Z') }),
        reason: 'consumed',
      },
      {
        record: claim({ failedAttempts: 5 }),
        reason: 'attempts_exhausted',
      },
    ];

    for (const testCase of cases) {
      const result = evaluatePairingClaim({
        record: testCase.record,
        presentedDigest: 'expected-digest',
        mountedDeviceAccountId: 'device-1',
        now,
      });
      assert.equal(result.status, 'rejected');
      assert.equal(result.reason, testCase.reason);
    }
  });

  test('allows the same mounted device to retry after consumption', () => {
    const consumedAt = new Date('2026-07-26T11:59:00.000Z');
    const result = evaluatePairingClaim({
      record: claim({ consumedAt, mountedDeviceAccountId: 'device-1' }),
      presentedDigest: 'expected-digest',
      mountedDeviceAccountId: 'device-1',
      now,
    });

    assert.equal(result.status, 'accepted');
    assert.equal(result.alreadyConsumed, true);
    assert.equal(result.record.consumedAt, consumedAt);
  });
});
