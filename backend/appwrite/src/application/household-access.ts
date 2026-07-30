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
