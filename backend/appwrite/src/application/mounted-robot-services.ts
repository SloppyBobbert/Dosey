import type {
  MountedRobotAccessRecord,
  RobotInstallationRecord,
} from '../domain/mounted-robot-access.js';

export interface MountedRobotLookup {
  findByDevice(accountId: string): Promise<readonly MountedRobotAccessRecord[]>;
  getRobotInstallation(robotId: string): Promise<RobotInstallationRecord | null>;
}

export class GetMountedRobotService {
  constructor(private readonly lookup: MountedRobotLookup) {}

  async get(accountId: string): Promise<{
    readonly robot: { readonly robotId: string; readonly displayName: string } | null;
  }> {
    const accesses = await this.lookup.findByDevice(accountId);
    if (accesses.length > 1) {
      throw new Error('Multiple mounted robot access rows share one device.');
    }
    const access = accesses[0];
    if (access == null) return { robot: null };

    const installation = await this.lookup.getRobotInstallation(access.robotId);
    if (installation == null || installation.status !== 'active') {
      return { robot: null };
    }
    return {
      robot: {
        robotId: installation.robotId,
        displayName: installation.displayName,
      },
    };
  }
}
