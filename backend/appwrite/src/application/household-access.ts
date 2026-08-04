import type { HouseholdRole } from '../domain/household.js';

export interface HouseholdAccessLink {
  readonly accountId: string;
  readonly robotId: string;
  readonly role: HouseholdRole;
  readonly status: 'provisioning' | 'active' | 'revoking';
}

export interface HouseholdLinkLookup {
  getLink(accountId: string, robotId: string): Promise<HouseholdAccessLink | null>;
}

export interface AuthorizedHouseholdAccess {
  readonly robotId: string;
  readonly role: HouseholdRole;
}

export type MedicationSyncActorType = 'human' | 'device';
export type MedicationSyncActorRole = HouseholdRole | 'device';

interface MountedDeviceAccessLookup {
  findByDevice(accountId: string): Promise<readonly {
    readonly robotId: string;
    readonly mountedDeviceAccountId: string;
    readonly registeredPatientDeviceId?: string | null;
  }[]>;
  getRobotInstallation(robotId: string): Promise<{
    readonly robotId: string;
    readonly status: 'active' | 'provisioning';
  } | null>;
}

export type AuthorizedMedicationSyncAccess =
  | {
      readonly robotId: string;
      readonly role: HouseholdRole;
      readonly authority: 'human';
      readonly registeredPatientDeviceId: null;
    }
  | {
      readonly robotId: string;
      readonly role: 'device';
      readonly authority: 'patient_device';
      readonly registeredPatientDeviceId: string | null;
    };

export class HouseholdAccessAuthorizer {
  constructor(private readonly links: HouseholdLinkLookup) {}

  async authorize(input: {
    accountId: string;
    robotId: string;
  }): Promise<AuthorizedHouseholdAccess | null> {
    const link = await this.links.getLink(input.accountId, input.robotId);
    if (link == null || link.status !== 'active' || link.robotId !== input.robotId) {
      return null;
    }
    return { robotId: link.robotId, role: link.role };
  }
}

export class MedicationSyncAccessAuthorizer {
  constructor(
    private readonly humans: HouseholdAccessAuthorizer,
    private readonly mountedDevices: MountedDeviceAccessLookup,
  ) {}

  async authorize(input: {
    readonly accountId: string;
    readonly actorType: MedicationSyncActorType;
    readonly robotId: string;
  }): Promise<AuthorizedMedicationSyncAccess | null> {
    if (input.actorType === 'human') {
      const authorized = await this.humans.authorize(input);
      return authorized == null ? null : {
        ...authorized,
        authority: 'human',
        registeredPatientDeviceId: null,
      };
    }
    try {
      const records = await this.mountedDevices.findByDevice(input.accountId);
      const record = records[0];
      if (
        records.length !== 1 ||
        record?.robotId !== input.robotId ||
        record.mountedDeviceAccountId !== input.accountId
      ) return null;
      const installation = await this.mountedDevices.getRobotInstallation(input.robotId);
      if (
        installation == null ||
        installation.robotId !== input.robotId ||
        installation.status !== 'active'
      ) return null;
      return {
        robotId: input.robotId,
        role: 'device',
        authority: 'patient_device',
        registeredPatientDeviceId: record.registeredPatientDeviceId ?? null,
      };
    } catch {
      return null;
    }
  }
}
