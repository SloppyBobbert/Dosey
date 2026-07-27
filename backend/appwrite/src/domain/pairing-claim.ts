import { timingSafeEqual } from 'node:crypto';

export const maximumPairingAttempts = 5;

export interface PairingClaimRecord {
  readonly id: string;
  readonly robotId: string;
  readonly codeDigest: string;
  readonly expiresAt: Date;
  readonly failedAttempts: number;
  readonly consumedAt: Date | null;
  readonly mountedDeviceAccountId?: string;
}

export type PairingClaimRejectionReason =
  | 'invalid'
  | 'expired'
  | 'consumed'
  | 'attempts_exhausted';

export type PairingClaimResult =
  | {
      readonly status: 'accepted';
      readonly alreadyConsumed: boolean;
      readonly record: PairingClaimRecord;
    }
  | {
      readonly status: 'rejected';
      readonly reason: PairingClaimRejectionReason;
      readonly record: PairingClaimRecord;
    };

export function evaluatePairingClaim(input: {
  record: PairingClaimRecord;
  presentedDigest: string;
  mountedDeviceAccountId: string;
  now: Date;
}): PairingClaimResult {
  const { record, presentedDigest, mountedDeviceAccountId, now } = input;
  if (record.consumedAt != null) {
    if (record.mountedDeviceAccountId === mountedDeviceAccountId) {
      return { status: 'accepted', alreadyConsumed: true, record };
    }
    return { status: 'rejected', reason: 'consumed', record };
  }
  if (record.failedAttempts >= maximumPairingAttempts) {
    return { status: 'rejected', reason: 'attempts_exhausted', record };
  }
  if (now >= record.expiresAt) {
    return { status: 'rejected', reason: 'expired', record };
  }
  if (!digestsMatch(record.codeDigest, presentedDigest)) {
    const failedAttempts = record.failedAttempts + 1;
    return {
      status: 'rejected',
      reason: failedAttempts >= maximumPairingAttempts ? 'attempts_exhausted' : 'invalid',
      record: { ...record, failedAttempts },
    };
  }
  return {
    status: 'accepted',
    alreadyConsumed: false,
    record: {
      ...record,
      consumedAt: now,
      mountedDeviceAccountId,
    },
  };
}

function digestsMatch(expected: string, presented: string): boolean {
  const expectedBytes = Buffer.from(expected, 'utf8');
  const presentedBytes = Buffer.from(presented, 'utf8');
  return (
    expectedBytes.length === presentedBytes.length &&
    timingSafeEqual(expectedBytes, presentedBytes)
  );
}
