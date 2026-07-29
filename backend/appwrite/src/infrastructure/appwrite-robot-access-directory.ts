import { Teams, type Models } from 'node-appwrite';

import type { RobotAccessDirectory } from '../application/pairing-services.js';

const robotMarkerKey = 'doseyRobot';
const ownerAccountIdKey = 'ownerAccountId';

export interface RobotTeam {
  readonly id: string;
  readonly isDoseyRobot: boolean;
  readonly ownerAccountId: string | null;
  readonly teamMemberAccountIds: readonly string[];
}

export interface RobotTeamsApi {
  getRobot(robotId: string): Promise<RobotTeam | null>;
}

export class AppwriteRobotAccessDirectory implements RobotAccessDirectory {
  constructor(private readonly teams: RobotTeamsApi) {}

  async isOwner(input: {
    robotId: string;
    accountId: string;
  }): Promise<boolean> {
    const robot = await this.teams.getRobot(input.robotId);
    return (
      robot?.isDoseyRobot === true && robot.ownerAccountId === input.accountId
    );
  }

  async canMountDevice(input: {
    robotId: string;
    accountId: string;
  }): Promise<boolean> {
    const robot = await this.teams.getRobot(input.robotId);
    return (
      robot?.isDoseyRobot === true &&
      robot.ownerAccountId !== input.accountId &&
      !robot.teamMemberAccountIds.includes(input.accountId)
    );
  }

}

export class AppwriteRobotTeamsApi implements RobotTeamsApi {
  constructor(private readonly teams: Teams) {}

  async getRobot(robotId: string): Promise<RobotTeam | null> {
    try {
      const team = await this.teams.get({ teamId: robotId });
      const preferences = preferencesOf(team);
      const memberships = await this.teams.listMemberships({ teamId: robotId });
      return {
        id: team.$id,
        isDoseyRobot: preferences[robotMarkerKey] === true,
        ownerAccountId: stringPreference(preferences, ownerAccountIdKey),
        teamMemberAccountIds: memberships.memberships.map(
          (membership) => membership.userId,
        ),
      };
    } catch (error) {
      if (isNotFound(error)) return null;
      throw error;
    }
  }

}

function preferencesOf(team: Models.Team): Record<string, unknown> {
  return team.prefs as Record<string, unknown>;
}

function stringPreference(
  preferences: Readonly<Record<string, unknown>>,
  key: string,
): string | null {
  const value = preferences[key];
  return typeof value === 'string' && value.length > 0 ? value : null;
}

function isNotFound(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error != null &&
    'code' in error &&
    error.code === 404
  );
}
