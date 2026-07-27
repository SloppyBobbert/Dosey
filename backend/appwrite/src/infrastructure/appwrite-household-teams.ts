import { AppwriteException, Query, Teams, type Models } from 'node-appwrite';

import type { HouseholdTeams } from '../application/household-services.js';
import type { HouseholdRole, HouseholdSnapshot } from '../domain/household.js';

const robotDeviceRole = 'robot-device';

export interface HouseholdTeam {
  readonly id: string;
  readonly name: string;
  readonly preferences: Readonly<Record<string, unknown>>;
}

export interface HouseholdTeamMembership {
  readonly id: string;
  readonly accountId: string;
  readonly roles: readonly string[];
  readonly confirmed: boolean;
  readonly userName: string;
  readonly userEmail: string;
}

export interface HouseholdTeamsApi {
  getTeam(robotId: string): Promise<HouseholdTeam | null>;
  createTeam(robotId: string, name: string): Promise<HouseholdTeam>;
  updateTeamName(robotId: string, name: string): Promise<void>;
  updatePreferences(robotId: string, preferences: Readonly<Record<string, unknown>>): Promise<void>;
  listMemberships(robotId: string): Promise<readonly HouseholdTeamMembership[]>;
  getMembership(robotId: string, membershipId: string): Promise<HouseholdTeamMembership | null>;
  createMembership(
    robotId: string,
    accountId: string,
    roles: readonly string[],
  ): Promise<HouseholdTeamMembership>;
  deleteMembership(robotId: string, membershipId: string): Promise<void>;
}

export class AppwriteHouseholdTeams implements HouseholdTeams {
  constructor(private readonly api: HouseholdTeamsApi) {}

  async ensureRobot(input: {
    robotId: string;
    displayName: string;
    ownerAccountId: string;
    resumeProvisioning: boolean;
  }): Promise<void> {
    let team = await this.api.getTeam(input.robotId);
    if (team == null) {
      team = await this.api.createTeam(input.robotId, input.displayName);
    } else {
      const marker = team.preferences.doseyRobot;
      const owner = optionalString(team.preferences.ownerAccountId);
      const isUnmarkedReservation =
        input.resumeProvisioning && Object.keys(team.preferences).length === 0;
      if (!isUnmarkedReservation && (marker !== true || owner !== input.ownerAccountId)) {
        throw new Error('Existing Team is not the reserved Dosey robot.');
      }
      if (team.name !== input.displayName) {
        await this.api.updateTeamName(input.robotId, input.displayName);
      }
    }

    const preferences = {
      ...team.preferences,
      doseyRobot: true,
      householdSchemaVersion: 1,
      ownerAccountId: input.ownerAccountId,
      mountedDeviceId: optionalString(team.preferences.mountedDeviceId),
    };
    await this.api.updatePreferences(input.robotId, preferences);
  }

  async ensureHumanMembership(input: {
    robotId: string;
    accountId: string;
    role: HouseholdRole;
    membershipId: string | null;
  }): Promise<string> {
    if (input.membershipId != null) {
      const membership = await this.api.getMembership(input.robotId, input.membershipId);
      if (membership != null) {
        validateHumanMembership(membership, input.accountId, input.role);
        return membership.id;
      }
    }

    const memberships = await this.api.listMemberships(input.robotId);
    const existing = memberships.find((membership) => membership.accountId === input.accountId);
    if (existing != null) {
      validateHumanMembership(existing, input.accountId, input.role);
      return existing.id;
    }
    const created = await this.api.createMembership(input.robotId, input.accountId, [input.role]);
    validateHumanMembership(created, input.accountId, input.role);
    return created.id;
  }

  async deleteHumanMembership(input: {
    robotId: string;
    accountId: string;
    membershipId: string | null;
  }): Promise<void> {
    let membership = input.membershipId == null
      ? null
      : await this.api.getMembership(input.robotId, input.membershipId);
    if (membership == null) {
      const memberships = await this.api.listMemberships(input.robotId);
      membership = memberships.find((candidate) => candidate.accountId === input.accountId) ?? null;
    }
    if (membership == null) return;
    if (membership.accountId !== input.accountId || !membership.confirmed) {
      throw new Error('The recorded membership does not match the household member.');
    }
    if (hasRobotDeviceRole(membership.roles)) {
      throw new Error('The household lifecycle cannot delete a robot-device membership.');
    }
    if (!membership.roles.some(isHumanRole)) {
      throw new Error('The recorded membership is not a household human.');
    }
    await this.api.deleteMembership(input.robotId, membership.id);
  }

  async snapshot(robotId: string, currentAccountId: string): Promise<HouseholdSnapshot> {
    const team = await this.api.getTeam(robotId);
    if (team?.preferences.doseyRobot !== true) throw new Error('Dosey robot Team not found.');
    const ownerAccountId = optionalString(team.preferences.ownerAccountId);
    if (ownerAccountId == null) throw new Error('Dosey robot owner preference is missing.');

    const memberships = (await this.api.listMemberships(robotId)).filter(
      (membership) =>
        membership.confirmed &&
        !hasRobotDeviceRole(membership.roles) &&
        membership.roles.some(isHumanRole),
    );
    const current = memberships.find((membership) => membership.accountId === currentAccountId);
    if (current == null) throw new Error('Current account is not an accepted household member.');

    return {
      robotId,
      displayName: team.name,
      ownerAccountId,
      mountedDeviceId: optionalString(team.preferences.mountedDeviceId),
      currentRole: current.accountId === ownerAccountId ? 'owner' : 'member',
      members: memberships.map((membership) => ({
        accountId: membership.accountId,
        label: firstNonblank(membership.userName, membership.userEmail, membership.accountId),
        role: membership.accountId === ownerAccountId ? 'owner' : 'member',
      })),
    };
  }
}

export class AppwriteHouseholdTeamsApi implements HouseholdTeamsApi {
  constructor(private readonly teams: Teams) {}

  async getTeam(robotId: string): Promise<HouseholdTeam | null> {
    try {
      return teamFromAppwrite(await this.teams.get({ teamId: robotId }));
    } catch (error) {
      if (isNotFound(error)) return null;
      throw error;
    }
  }

  async createTeam(robotId: string, name: string): Promise<HouseholdTeam> {
    return teamFromAppwrite(await this.teams.create({ teamId: robotId, name }));
  }

  async updateTeamName(robotId: string, name: string): Promise<void> {
    await this.teams.updateName({ teamId: robotId, name });
  }

  async updatePreferences(
    robotId: string,
    preferences: Readonly<Record<string, unknown>>,
  ): Promise<void> {
    await this.teams.updatePrefs({ teamId: robotId, prefs: preferences });
  }

  async listMemberships(robotId: string): Promise<readonly HouseholdTeamMembership[]> {
    const result = await this.teams.listMemberships({
      teamId: robotId,
      queries: [Query.limit(100)],
    });
    return result.memberships.map(membershipFromAppwrite);
  }

  async getMembership(
    robotId: string,
    membershipId: string,
  ): Promise<HouseholdTeamMembership | null> {
    try {
      return membershipFromAppwrite(
        await this.teams.getMembership({ teamId: robotId, membershipId }),
      );
    } catch (error) {
      if (isNotFound(error)) return null;
      throw error;
    }
  }

  async createMembership(
    robotId: string,
    accountId: string,
    roles: readonly string[],
  ): Promise<HouseholdTeamMembership> {
    return membershipFromAppwrite(
      await this.teams.createMembership({
        teamId: robotId,
        userId: accountId,
        roles: [...roles],
      }),
    );
  }

  async deleteMembership(robotId: string, membershipId: string): Promise<void> {
    try {
      await this.teams.deleteMembership({ teamId: robotId, membershipId });
    } catch (error) {
      if (!isNotFound(error)) throw error;
    }
  }
}

function validateHumanMembership(
  membership: HouseholdTeamMembership,
  accountId: string,
  role: HouseholdRole,
): void {
  if (
    membership.accountId !== accountId ||
    !membership.confirmed ||
    !membership.roles.includes(role) ||
    hasRobotDeviceRole(membership.roles)
  ) {
    throw new Error('Existing Team membership does not match the household link.');
  }
}

function hasRobotDeviceRole(roles: readonly string[]): boolean {
  return roles.includes(robotDeviceRole);
}

function isHumanRole(role: string): boolean {
  return role === 'owner' || role === 'member';
}

function optionalString(value: unknown): string | null {
  return typeof value === 'string' && value.trim().length > 0 ? value : null;
}

function firstNonblank(...values: readonly string[]): string {
  return values.find((value) => value.trim().length > 0) ?? 'Household member';
}

function teamFromAppwrite(team: Models.Team): HouseholdTeam {
  return {
    id: team.$id,
    name: team.name,
    preferences: team.prefs as Readonly<Record<string, unknown>>,
  };
}

function membershipFromAppwrite(membership: Models.Membership): HouseholdTeamMembership {
  return {
    id: membership.$id,
    accountId: membership.userId,
    roles: membership.roles,
    confirmed: membership.confirm,
    userName: membership.userName,
    userEmail: membership.userEmail,
  };
}

function isNotFound(error: unknown): boolean {
  return (
    (error instanceof AppwriteException && error.code === 404) ||
    (typeof error === 'object' && error != null && 'code' in error && error.code === 404)
  );
}
