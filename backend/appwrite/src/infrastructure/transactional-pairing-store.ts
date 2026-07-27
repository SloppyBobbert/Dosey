import type {
  PairingClaimStore,
  PairingCredentialStore,
} from '../application/pairing-services.js';
import {
  evaluatePairingClaim,
  maximumPairingAttempts,
  type PairingClaimRecord,
} from '../domain/pairing-claim.js';

export const pairingAttemptCooldownMs = 15 * 60 * 1000;

export interface PairingAttemptRecord {
  readonly deviceAccountId: string;
  readonly failedAttempts: number;
  readonly blockedUntil: Date | null;
}

export interface PairingTransaction {
  deactivateRobotClaims(robotId: string): Promise<void>;
  createClaim(record: PairingClaimRecord): Promise<void>;
  findActiveClaimByDigest(codeDigest: string): Promise<PairingClaimRecord | null>;
  saveClaim(record: PairingClaimRecord): Promise<void>;
  getAttempt(deviceAccountId: string): Promise<PairingAttemptRecord | null>;
  saveAttempt(record: PairingAttemptRecord): Promise<void>;
}

export interface PairingPersistence {
  transaction<T>(operation: (transaction: PairingTransaction) => Promise<T>): Promise<T>;
}

export class TransactionalPairingStore
  implements PairingCredentialStore, PairingClaimStore
{
  constructor(private readonly persistence: PairingPersistence) {}

  replaceActive(record: PairingClaimRecord): Promise<void> {
    return this.persistence.transaction(async (transaction) => {
      await transaction.deactivateRobotClaims(record.robotId);
      await transaction.createClaim(record);
    });
  }

  claimAtomically(input: {
    codeDigest: string;
    mountedDeviceAccountId: string;
    now: Date;
  }) {
    return this.persistence.transaction(async (transaction) => {
      const attempts = await transaction.getAttempt(input.mountedDeviceAccountId);
      if (attempts?.blockedUntil != null && input.now < attempts.blockedUntil) {
        return rejected('attempts_exhausted');
      }

      const claim = await transaction.findActiveClaimByDigest(input.codeDigest);
      if (claim == null) {
        const failedAttempts =
          attempts?.blockedUntil != null && input.now >= attempts.blockedUntil
            ? 1
            : (attempts?.failedAttempts ?? 0) + 1;
        const exhausted = failedAttempts >= maximumPairingAttempts;
        await transaction.saveAttempt({
          deviceAccountId: input.mountedDeviceAccountId,
          failedAttempts,
          blockedUntil: exhausted
            ? new Date(input.now.getTime() + pairingAttemptCooldownMs)
            : null,
        });
        return rejected(exhausted ? 'attempts_exhausted' : 'invalid');
      }

      const result = evaluatePairingClaim({
        record: claim,
        presentedDigest: input.codeDigest,
        mountedDeviceAccountId: input.mountedDeviceAccountId,
        now: input.now,
      });
      if (result.status === 'rejected') return rejected(result.reason);

      if (!result.alreadyConsumed) await transaction.saveClaim(result.record);
      await transaction.saveAttempt({
        deviceAccountId: input.mountedDeviceAccountId,
        failedAttempts: 0,
        blockedUntil: null,
      });
      return { status: 'accepted' as const, robotId: claim.robotId };
    });
  }
}

function rejected(
  reason: 'invalid' | 'expired' | 'consumed' | 'attempts_exhausted',
) {
  return { status: 'rejected' as const, reason };
}
