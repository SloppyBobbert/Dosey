export const maximumPairingAttempts = 5;

export interface PairingClaimRecord {
  readonly id: string;
  readonly robotId: string;
  readonly codeDigest: string;
  readonly expiresAt: Date;
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
  mountedDeviceAccountId: string;
  now: Date;
}): PairingClaimResult {
  const { record, mountedDeviceAccountId, now } = input;
  if (now >= record.expiresAt) {
    return { status: 'rejected', reason: 'expired', record };
  }
  if (record.consumedAt != null) {
    if (record.mountedDeviceAccountId === mountedDeviceAccountId) {
      return { status: 'accepted', alreadyConsumed: true, record };
    }
    return { status: 'rejected', reason: 'consumed', record };
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
