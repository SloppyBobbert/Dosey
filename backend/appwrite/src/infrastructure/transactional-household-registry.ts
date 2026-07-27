import {
  HouseholdFailure,
  type HouseholdFailureCode,
  type HouseholdRegistry,
} from '../application/household-services.js';
import { maximumHouseholdHumans, type HouseholdRole } from '../domain/household.js';

export type HouseholdLifecycleStatus = 'provisioning' | 'active' | 'revoking';

export interface HouseholdRobotRecord {
  readonly id: string;
  readonly ownerAccountId: string;
  readonly displayName: string;
  readonly humanCount: number;
  readonly status: 'provisioning' | 'active';
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export interface HouseholdLinkRecord {
  readonly accountId: string;
  readonly robotId: string;
  readonly role: HouseholdRole;
  readonly membershipId: string | null;
  readonly status: HouseholdLifecycleStatus;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export interface HouseholdInvitationRecord {
  readonly id: string;
  readonly robotId: string;
  readonly invitedEmail: string;
  readonly codeDigest: string;
  readonly expiresAt: Date;
  readonly createdByAccountId: string;
  readonly consumedAt: Date | null;
  readonly acceptedAccountId: string | null;
  readonly revokedAt: Date | null;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export interface HouseholdTransaction {
  getRobot(robotId: string): Promise<HouseholdRobotRecord | null>;
  createRobot(record: HouseholdRobotRecord): Promise<void>;
  saveRobot(record: HouseholdRobotRecord): Promise<void>;
  getLink(accountId: string): Promise<HouseholdLinkRecord | null>;
  createLink(record: HouseholdLinkRecord): Promise<void>;
  saveLink(record: HouseholdLinkRecord): Promise<void>;
  deleteLink(accountId: string): Promise<void>;
  getInvitation(id: string): Promise<HouseholdInvitationRecord | null>;
  findInvitationByDigest(codeDigest: string): Promise<HouseholdInvitationRecord | null>;
  saveInvitation(record: HouseholdInvitationRecord): Promise<void>;
}

export interface HouseholdPersistence {
  transaction<T>(operation: (transaction: HouseholdTransaction) => Promise<T>): Promise<T>;
}

export class TransactionalHouseholdRegistry implements HouseholdRegistry {
  constructor(private readonly persistence: HouseholdPersistence) {}

  reserveOwner(input: {
    robotId: string;
    accountId: string;
    displayName: string;
    now: Date;
  }) {
    return this.persistence.transaction(async (transaction) => {
      const existingLink = await transaction.getLink(input.accountId);
      if (existingLink != null) {
        if (existingLink.role === 'owner' && existingLink.status === 'provisioning') {
          return {
            status: 'resume' as const,
            robotId: existingLink.robotId,
            membershipId: existingLink.membershipId,
          };
        }
        return { status: 'already_linked' as const };
      }

      await transaction.createRobot({
        id: input.robotId,
        ownerAccountId: input.accountId,
        displayName: input.displayName,
        humanCount: 1,
        status: 'provisioning',
        createdAt: input.now,
        updatedAt: input.now,
      });
      await transaction.createLink({
        accountId: input.accountId,
        robotId: input.robotId,
        role: 'owner',
        membershipId: null,
        status: 'provisioning',
        createdAt: input.now,
        updatedAt: input.now,
      });
      return { status: 'reserved' as const, robotId: input.robotId, membershipId: null };
    });
  }

  activateLink(input: {
    robotId: string;
    accountId: string;
    membershipId: string;
    now: Date;
  }): Promise<void> {
    return this.persistence.transaction(async (transaction) => {
      const link = await transaction.getLink(input.accountId);
      if (link == null || link.robotId !== input.robotId || link.status === 'revoking') {
        throw new Error('Household link cannot be activated.');
      }
      if (link.status !== 'active' || link.membershipId !== input.membershipId) {
        await transaction.saveLink({
          ...link,
          membershipId: input.membershipId,
          status: 'active',
          updatedAt: input.now,
        });
      }
      if (link.role === 'owner') {
        const robot = await requiredRobot(transaction, input.robotId);
        if (robot.status !== 'active') {
          await transaction.saveRobot({ ...robot, status: 'active', updatedAt: input.now });
        }
      }
    });
  }

  replaceInvitation(input: {
    id: string;
    robotId: string;
    ownerAccountId: string;
    invitedEmail: string;
    codeDigest: string;
    expiresAt: Date;
    now: Date;
  }): Promise<void> {
    return this.persistence.transaction(async (transaction) => {
      const owner = await transaction.getLink(input.ownerAccountId);
      if (
        owner == null ||
        owner.robotId !== input.robotId ||
        owner.role !== 'owner' ||
        owner.status !== 'active'
      ) {
        throw new HouseholdFailure('owner_required');
      }
      const previous = await transaction.getInvitation(input.id);
      if (previous?.consumedAt != null && previous.acceptedAccountId != null) {
        const acceptedLink = await transaction.getLink(previous.acceptedAccountId);
        if (acceptedLink != null) throw new HouseholdFailure('already_linked');
      }
      await transaction.saveInvitation({
        id: input.id,
        robotId: input.robotId,
        invitedEmail: input.invitedEmail,
        codeDigest: input.codeDigest,
        expiresAt: input.expiresAt,
        createdByAccountId: input.ownerAccountId,
        consumedAt: null,
        acceptedAccountId: null,
        revokedAt: null,
        createdAt: previous?.createdAt ?? input.now,
        updatedAt: input.now,
      });
    });
  }

  reserveAcceptance(input: {
    codeDigest: string;
    accountId: string;
    email: string;
    now: Date;
  }) {
    return this.persistence.transaction(async (transaction) => {
      const invitation = await transaction.findInvitationByDigest(input.codeDigest);
      if (invitation == null || invitation.revokedAt != null) {
        return rejected('invalid_invitation');
      }
      if (invitation.invitedEmail !== input.email) return rejected('email_mismatch');

      const existingLink = await transaction.getLink(input.accountId);
      if (invitation.consumedAt != null) {
        if (
          invitation.acceptedAccountId === input.accountId &&
          existingLink?.robotId === invitation.robotId &&
          existingLink.status !== 'revoking'
        ) {
          return {
            status: 'resume' as const,
            robotId: invitation.robotId,
            membershipId: existingLink.membershipId,
          };
        }
        return rejected('invalid_invitation');
      }
      if (input.now >= invitation.expiresAt) return rejected('invitation_expired');
      if (existingLink != null) return rejected('already_linked');

      const robot = await requiredRobot(transaction, invitation.robotId);
      if (robot.status !== 'active') return rejected('invalid_invitation');
      if (robot.humanCount >= maximumHouseholdHumans) return rejected('household_full');

      await transaction.createLink({
        accountId: input.accountId,
        robotId: robot.id,
        role: 'member',
        membershipId: null,
        status: 'provisioning',
        createdAt: input.now,
        updatedAt: input.now,
      });
      await transaction.saveInvitation({
        ...invitation,
        consumedAt: input.now,
        acceptedAccountId: input.accountId,
        updatedAt: input.now,
      });
      await transaction.saveRobot({
        ...robot,
        humanCount: robot.humanCount + 1,
        updatedAt: input.now,
      });
      return { status: 'reserved' as const, robotId: robot.id, membershipId: null };
    });
  }

  beginRevocation(input: {
    robotId: string;
    actorAccountId: string;
    targetAccountId: string;
    now: Date;
  }) {
    return this.persistence.transaction(async (transaction) => {
      const actor = await transaction.getLink(input.actorAccountId);
      const target = await transaction.getLink(input.targetAccountId);

      if (input.actorAccountId === input.targetAccountId) {
        if (actor == null) return { status: 'already_removed' as const };
        if (actor.robotId !== input.robotId) return rejectedRevocation('member_not_found');
        if (actor.role === 'owner') return rejectedRevocation('owner_cannot_leave');
      } else if (
        actor == null ||
        actor.robotId !== input.robotId ||
        actor.role !== 'owner' ||
        actor.status !== 'active'
      ) {
        return rejectedRevocation('owner_required');
      }

      if (target == null) return { status: 'already_removed' as const };
      if (target.robotId !== input.robotId || target.role === 'owner') {
        return rejectedRevocation('member_not_found');
      }
      if (target.membershipId == null) {
        throw new Error('Household member has no Team membership to revoke.');
      }
      if (target.status !== 'revoking') {
        await transaction.saveLink({ ...target, status: 'revoking', updatedAt: input.now });
      }
      return { status: 'ready' as const, membershipId: target.membershipId };
    });
  }

  finalizeRevocation(input: {
    robotId: string;
    targetAccountId: string;
    now: Date;
  }): Promise<void> {
    return this.persistence.transaction(async (transaction) => {
      const target = await transaction.getLink(input.targetAccountId);
      if (target == null) return;
      if (target.robotId !== input.robotId || target.status !== 'revoking' || target.role === 'owner') {
        throw new Error('Household link is not ready for revocation.');
      }
      const robot = await requiredRobot(transaction, input.robotId);
      if (robot.humanCount <= 1) throw new Error('Household owner slot cannot be removed.');
      await transaction.deleteLink(input.targetAccountId);
      await transaction.saveRobot({
        ...robot,
        humanCount: robot.humanCount - 1,
        updatedAt: input.now,
      });
    });
  }
}

async function requiredRobot(
  transaction: HouseholdTransaction,
  robotId: string,
): Promise<HouseholdRobotRecord> {
  const robot = await transaction.getRobot(robotId);
  if (robot == null) throw new Error('Household robot registry row is missing.');
  return robot;
}

function rejected(reason: HouseholdFailureCode) {
  return { status: 'rejected' as const, reason };
}

function rejectedRevocation(reason: HouseholdFailureCode) {
  return { status: 'rejected' as const, reason };
}
