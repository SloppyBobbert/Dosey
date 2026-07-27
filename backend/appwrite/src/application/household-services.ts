import { randomBytes as secureRandomBytes } from 'node:crypto';

import type { HouseholdRole, HouseholdSnapshot } from '../domain/household.js';
import {
  digestHouseholdInvitationCode,
  householdInvitationId,
  householdInvitationLifetimeMs,
  issueHouseholdInvitationCode,
  normalizeHouseholdInvitationCode,
} from '../domain/household-invitation.js';

export type HouseholdFailureCode =
  | 'already_linked'
  | 'household_full'
  | 'invalid_invitation'
  | 'invitation_expired'
  | 'email_mismatch'
  | 'owner_required'
  | 'owner_cannot_leave'
  | 'member_not_found';

export class HouseholdFailure extends Error {
  constructor(readonly code: HouseholdFailureCode) {
    super(code);
    this.name = 'HouseholdFailure';
  }
}

export interface HouseholdRegistry {
  reserveOwner(input: {
    robotId: string;
    accountId: string;
    displayName: string;
    now: Date;
  }): Promise<
    | { status: 'reserved' | 'resume'; robotId: string; membershipId: string | null }
    | { status: 'already_linked' }
  >;
  activateLink(input: {
    robotId: string;
    accountId: string;
    membershipId: string;
    now: Date;
  }): Promise<void>;
  replaceInvitation(input: {
    id: string;
    robotId: string;
    ownerAccountId: string;
    invitedEmail: string;
    codeDigest: string;
    expiresAt: Date;
    now: Date;
  }): Promise<void>;
  reserveAcceptance(input: {
    codeDigest: string;
    accountId: string;
    email: string;
    now: Date;
  }): Promise<
    | { status: 'reserved' | 'resume'; robotId: string; membershipId: string | null }
    | { status: 'rejected'; reason: HouseholdFailureCode }
  >;
  beginRevocation(input: {
    robotId: string;
    actorAccountId: string;
    targetAccountId: string;
    now: Date;
  }): Promise<
    | { status: 'ready'; membershipId: string }
    | { status: 'already_removed' }
    | { status: 'rejected'; reason: HouseholdFailureCode }
  >;
  finalizeRevocation(input: {
    robotId: string;
    targetAccountId: string;
    now: Date;
  }): Promise<void>;
}

export interface HouseholdTeams {
  ensureRobot(input: { robotId: string; displayName: string; ownerAccountId: string }): Promise<void>;
  ensureHumanMembership(input: {
    robotId: string;
    accountId: string;
    role: HouseholdRole;
    membershipId: string | null;
  }): Promise<string>;
  deleteHumanMembership(input: { robotId: string; membershipId: string }): Promise<void>;
  snapshot(robotId: string, currentAccountId: string): Promise<HouseholdSnapshot>;
}

export class CreateRobotService {
  constructor(private readonly dependencies: {
    registry: HouseholdRegistry;
    teams: HouseholdTeams;
    createId: () => string;
    now: () => Date;
  }) {}

  async create(input: { accountId: string; displayName: string }): Promise<HouseholdSnapshot> {
    const displayName = input.displayName.trim();
    if (displayName.length === 0) throw new TypeError('Robot display name is required.');
    const reservation = await this.dependencies.registry.reserveOwner({
      robotId: this.dependencies.createId(),
      accountId: input.accountId,
      displayName,
      now: this.dependencies.now(),
    });
    if (reservation.status === 'already_linked') throw new HouseholdFailure('already_linked');
    await this.dependencies.teams.ensureRobot({
      robotId: reservation.robotId,
      displayName,
      ownerAccountId: input.accountId,
    });
    const membershipId = await this.dependencies.teams.ensureHumanMembership({
      robotId: reservation.robotId,
      accountId: input.accountId,
      role: 'owner',
      membershipId: reservation.membershipId,
    });
    await this.dependencies.registry.activateLink({
      robotId: reservation.robotId,
      accountId: input.accountId,
      membershipId,
      now: this.dependencies.now(),
    });
    return this.dependencies.teams.snapshot(reservation.robotId, input.accountId);
  }
}

export class CreateHouseholdInvitationService {
  constructor(private readonly dependencies: {
    registry: HouseholdRegistry;
    secret: string;
    now: () => Date;
    randomBytes?: () => Buffer;
  }) {}

  async create(input: { robotId: string; ownerAccountId: string; invitedEmail: string }) {
    const invitedEmail = normalizeEmail(input.invitedEmail);
    const now = this.dependencies.now();
    const code = issueHouseholdInvitationCode(
      this.dependencies.randomBytes?.() ?? secureRandomBytes(12),
    );
    const expiresAt = new Date(now.getTime() + householdInvitationLifetimeMs);
    await this.dependencies.registry.replaceInvitation({
      id: householdInvitationId(input.robotId, invitedEmail),
      robotId: input.robotId,
      ownerAccountId: input.ownerAccountId,
      invitedEmail,
      codeDigest: digestHouseholdInvitationCode(code, this.dependencies.secret),
      expiresAt,
      now,
    });
    return { code, expiresAt };
  }
}

export class AcceptHouseholdInvitationService {
  constructor(private readonly dependencies: {
    registry: HouseholdRegistry;
    teams: HouseholdTeams;
    secret: string;
    now: () => Date;
  }) {}

  async accept(input: { accountId: string; email: string; code: string }): Promise<HouseholdSnapshot> {
    const result = await this.dependencies.registry.reserveAcceptance({
      codeDigest: digestHouseholdInvitationCode(normalizeHouseholdInvitationCode(input.code), this.dependencies.secret),
      accountId: input.accountId,
      email: normalizeEmail(input.email),
      now: this.dependencies.now(),
    });
    if (result.status === 'rejected') throw new HouseholdFailure(result.reason);
    const membershipId = await this.dependencies.teams.ensureHumanMembership({
      robotId: result.robotId,
      accountId: input.accountId,
      role: 'member',
      membershipId: result.membershipId,
    });
    await this.dependencies.registry.activateLink({
      robotId: result.robotId,
      accountId: input.accountId,
      membershipId,
      now: this.dependencies.now(),
    });
    return this.dependencies.teams.snapshot(result.robotId, input.accountId);
  }
}

export class RemoveHouseholdMemberService {
  constructor(private readonly dependencies: {
    registry: HouseholdRegistry;
    teams: HouseholdTeams;
    now: () => Date;
  }) {}

  async remove(input: {
    robotId: string;
    actorAccountId: string;
    targetAccountId: string;
  }): Promise<HouseholdSnapshot | null> {
    const result = await this.dependencies.registry.beginRevocation({
      ...input,
      now: this.dependencies.now(),
    });
    if (result.status === 'rejected') throw new HouseholdFailure(result.reason);
    if (result.status === 'already_removed') {
      return input.actorAccountId === input.targetAccountId
        ? null
        : this.dependencies.teams.snapshot(input.robotId, input.actorAccountId);
    }
    await this.dependencies.teams.deleteHumanMembership({
      robotId: input.robotId,
      membershipId: result.membershipId,
    });
    await this.dependencies.registry.finalizeRevocation({
      robotId: input.robotId,
      targetAccountId: input.targetAccountId,
      now: this.dependencies.now(),
    });
    return input.actorAccountId === input.targetAccountId
      ? null
      : this.dependencies.teams.snapshot(input.robotId, input.actorAccountId);
  }
}

function normalizeEmail(value: string): string {
  const email = value.trim().toLowerCase();
  if (email.length === 0 || !email.includes('@')) throw new TypeError('A valid email is required.');
  return email;
}
