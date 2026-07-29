import type {
  PairingClaimStore,
  PairingCredentialStore,
} from '../application/pairing-services.js';
import type { MountedRobotAccessRecord } from '../domain/mounted-robot-access.js';
import {
  evaluatePairingClaim,
  maximumPairingAttempts,
  type PairingClaimRecord,
} from '../domain/pairing-claim.js';
import { PairingCodeConflictError } from '../application/pairing-services.js';
import { PairingTransactionConflictError } from './appwrite-pairing-persistence.js';

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
  findMountedAccessByDevice(deviceAccountId: string): Promise<readonly MountedRobotAccessRecord[]>;
  getMountedAccessByRobot(robotId: string): Promise<MountedRobotAccessRecord | null>;
  createMountedAccess(record: MountedRobotAccessRecord): Promise<void>;
  updateMountedAccess(record: MountedRobotAccessRecord): Promise<void>;
}

export interface PairingPersistence {
  transaction<T>(operation: (transaction: PairingTransaction) => Promise<T>): Promise<T>;
  resolveClaimConflict?(input: {
    codeDigest: string;
    robotId: string;
    mountedDeviceAccountId: string;
  }): Promise<'accepted' | 'consumed' | 'device_already_mounted' | 'unknown'>;
}

export class TransactionalPairingStore
  implements PairingCredentialStore, PairingClaimStore
{
  constructor(private readonly persistence: PairingPersistence) {}

  async replaceActive(record: PairingClaimRecord): Promise<void> {
    try {
      await this.persistence.transaction(async (transaction) => {
        await transaction.deactivateRobotClaims(record.robotId);
        await transaction.createClaim(record);
      });
    } catch (error) {
      if (error instanceof PairingTransactionConflictError) {
        throw new PairingCodeConflictError();
      }
      throw error;
    }
  }

  async claimAtomically(input: {
    codeDigest: string;
    mountedDeviceAccountId: string;
    now: Date;
    canClaim: (robotId: string) => Promise<boolean>;
  }) {
    let conflictRobotId: string | null = null;
    try {
      return await this.persistence.transaction(async (transaction) => {
        const attempts = await transaction.getAttempt(
          input.mountedDeviceAccountId,
        );
        if (attempts?.blockedUntil != null && input.now < attempts.blockedUntil) {
          return rejected('attempts_exhausted');
        }

        const claim = await transaction.findActiveClaimByDigest(
          input.codeDigest,
        );
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
        conflictRobotId = claim.robotId;

        const result = evaluatePairingClaim({
          record: claim,
          mountedDeviceAccountId: input.mountedDeviceAccountId,
          now: input.now,
        });
        if (result.status === 'rejected') return rejected(result.reason);
        if (!(await input.canClaim(claim.robotId))) return rejected('invalid');

        const deviceAccess = await transaction.findMountedAccessByDevice(
          input.mountedDeviceAccountId,
        );
        if (deviceAccess.length > 1) {
          throw new Error('Multiple mounted robot access rows share one device.');
        }
        const existingDeviceAccess = deviceAccess[0] ?? null;
        if (
          existingDeviceAccess != null &&
          existingDeviceAccess.robotId !== claim.robotId
        ) {
          return rejected('device_already_mounted');
        }
        const robotAccess = await transaction.getMountedAccessByRobot(claim.robotId);
        if (existingDeviceAccess != null && robotAccess == null) {
          throw new Error('Mounted robot access rows are inconsistent.');
        }

        if (result.alreadyConsumed) {
          if (
            existingDeviceAccess == null ||
            existingDeviceAccess.robotId !== claim.robotId ||
            existingDeviceAccess.pairingClaimId !== claim.id
          ) {
            throw new Error('Consumed pairing claim has no matching mounted access.');
          }
          await transaction.saveAttempt({
            deviceAccountId: input.mountedDeviceAccountId,
            failedAttempts: 0,
            blockedUntil: null,
          });
          return { status: 'accepted' as const, robotId: claim.robotId };
        }

        await transaction.saveClaim(result.record);
        const access = {
          robotId: claim.robotId,
          mountedDeviceAccountId: input.mountedDeviceAccountId,
          pairingClaimId: claim.id,
          createdAt: robotAccess?.createdAt ?? input.now,
          updatedAt: input.now,
        };
        if (robotAccess == null) {
          await transaction.createMountedAccess(access);
        } else {
          await transaction.updateMountedAccess(access);
        }
        await transaction.saveAttempt({
          deviceAccountId: input.mountedDeviceAccountId,
          failedAttempts: 0,
          blockedUntil: null,
        });
        return { status: 'accepted' as const, robotId: claim.robotId };
      });
    } catch (error) {
      if (error instanceof PairingTransactionConflictError) {
        const resolution = await this.persistence.resolveClaimConflict?.({
          codeDigest: input.codeDigest,
          robotId: conflictRobotId ?? '',
          mountedDeviceAccountId: input.mountedDeviceAccountId,
        });
        if (resolution === 'accepted' && conflictRobotId != null) {
          return { status: 'accepted' as const, robotId: conflictRobotId };
        }
        if (resolution === 'consumed' || resolution === 'device_already_mounted') {
          return rejected(resolution);
        }
        throw error;
      }
      throw error;
    }
  }
}

function rejected(
  reason: 'invalid' | 'expired' | 'consumed' | 'attempts_exhausted' | 'device_already_mounted',
) {
  return { status: 'rejected' as const, reason };
}
