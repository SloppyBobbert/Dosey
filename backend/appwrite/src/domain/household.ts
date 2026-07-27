export type HouseholdRole = 'owner' | 'member';

export interface HouseholdMember {
  readonly accountId: string;
  readonly label: string;
  readonly role: HouseholdRole;
}

export interface HouseholdSnapshot {
  readonly robotId: string;
  readonly displayName: string;
  readonly ownerAccountId: string;
  readonly mountedDeviceId: string | null;
  readonly currentRole: HouseholdRole;
  readonly members: readonly HouseholdMember[];
}

export const maximumHouseholdHumans = 7;
