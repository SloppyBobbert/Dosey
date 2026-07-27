import { Query, Teams, type Models } from 'node-appwrite';

import type { RobotAccessDirectory } from '../application/pairing-services.js';

const robotMarkerKey = 'doseyRobot';
const ownerAccountIdKey = 'ownerAccountId';
const mountedDeviceIdKey = 'mountedDeviceId';
const robotDeviceRole = 'robot-device';

export interface RobotTeam {
  readonly id: string;
  readonly isDoseyRobot: boolean;
  readonly ownerAccountId: string | null;
  readonly mountedDeviceAccountId: string | null;
}

export interface RobotTeamsApi {
  getRobot(robotId: string): Promise<RobotTeam | null>;
  replaceMountedDevice(
    robotId: string,
    mountedDeviceAccountId: string,
  ): Promise<void>;
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

  async mountDevice(input: {
    robotId: string;
    mountedDeviceAccountId: string;
  }): Promise<void> {
    const robot = await this.teams.getRobot(input.robotId);
    if (robot?.isDoseyRobot !== true) {
      throw new Error('Dosey robot not found.');
    }
    await this.teams.replaceMountedDevice(
      input.robotId,
      input.mountedDeviceAccountId,
    );
  }
}

export class AppwriteRobotTeamsApi implements RobotTeamsApi {
  constructor(private readonly teams: Teams) {}

  async getRobot(robotId: string): Promise<RobotTeam | null> {
    try {
      const team = await this.teams.get({ teamId: robotId });
      const preferences = preferencesOf(team);
      return {
        id: team.$id,
        isDoseyRobot: preferences[robotMarkerKey] === true,
        ownerAccountId: stringPreference(preferences, ownerAccountIdKey),
        mountedDeviceAccountId: stringPreference(
          preferences,
          mountedDeviceIdKey,
        ),
      };
    } catch (error) {
      if (isNotFound(error)) return null;
      throw error;
    }
  }

  async replaceMountedDevice(
    robotId: string,
    mountedDeviceAccountId: string,
  ): Promise<void> {
    const team = await this.teams.get({ teamId: robotId });
    const preferences = preferencesOf(team);
    if (preferences[robotMarkerKey] !== true) {
      throw new Error('Dosey robot not found.');
    }

    const oldDeviceId = stringPreference(preferences, mountedDeviceIdKey);
    if (oldDeviceId === mountedDeviceAccountId) return;

    const memberships = await this.teams.listMemberships({
      teamId: robotId,
      queries: [
        Query.equal('userId', [
          ...new Set(
            [oldDeviceId, mountedDeviceAccountId].filter(
              (value): value is string => value != null,
            ),
          ),
        ]),
      ],
    });
    let newMembership = memberships.memberships.find(
      (membership) => membership.userId === mountedDeviceAccountId,
    );
    const createdMembership = newMembership == null;
    if (newMembership == null) {
      newMembership = await this.teams.createMembership({
        teamId: robotId,
        roles: [robotDeviceRole],
        userId: mountedDeviceAccountId,
      });
    }

    const oldMembership = memberships.memberships.find(
      (membership) => membership.userId === oldDeviceId,
    );
    try {
      // Revoke the old credential before making the replacement authoritative.
      // If the preference update then fails, the consumed code can safely retry.
      if (oldMembership != null) {
        await this.teams.deleteMembership({
          teamId: robotId,
          membershipId: oldMembership.$id,
        });
      }
      await this.teams.updatePrefs({
        teamId: robotId,
        prefs: { ...preferences, [mountedDeviceIdKey]: mountedDeviceAccountId },
      });
    } catch (error) {
      if (createdMembership) {
        await ignoreFailure(
          this.teams.deleteMembership({
            teamId: robotId,
            membershipId: newMembership.$id,
          }),
        );
      }
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

async function ignoreFailure(operation: Promise<unknown>): Promise<void> {
  try {
    await operation;
  } catch (_) {
    // Preserve the preference update failure that triggered cleanup.
  }
}
