import { AppwriteException, TablesDB, type Models } from 'node-appwrite';

import type {
  HouseholdAccessLink,
  HouseholdLinkLookup,
} from '../application/household-access.js';

export type HouseholdAccessRow = Readonly<Record<string, unknown>> & {
  readonly $id: string;
};

export interface HouseholdAccessRowsApi {
  getHumanRobotLink(accountId: string): Promise<HouseholdAccessRow | null>;
}

export class AppwriteHouseholdAccessRowsApi implements HouseholdAccessRowsApi {
  constructor(
    private readonly tables: TablesDB,
    private readonly databaseId: string,
    private readonly humanRobotLinksTableId: string,
  ) {}

  async getHumanRobotLink(accountId: string): Promise<HouseholdAccessRow | null> {
    try {
      const row = await this.tables.getRow({
        databaseId: this.databaseId,
        tableId: this.humanRobotLinksTableId,
        rowId: accountId,
      });
      return fromAppwriteRow(row);
    } catch (error) {
      if (error instanceof AppwriteException && error.code === 404) return null;
      throw error;
    }
  }
}

export class AppwriteHouseholdLinkLookup implements HouseholdLinkLookup {
  constructor(private readonly rows: HouseholdAccessRowsApi) {}

  async getLink(accountId: string): Promise<HouseholdAccessLink | null> {
    const row = await this.rows.getHumanRobotLink(accountId);
    if (row == null) return null;
    return {
      accountId: row.$id,
      robotId: requiredString(row, 'robotId'),
      role: requiredEnum(row, 'role', ['owner', 'member']),
      status: requiredEnum(row, 'status', ['provisioning', 'active', 'revoking']),
    };
  }
}

function requiredString(row: HouseholdAccessRow, key: string): string {
  const value = row[key];
  if (typeof value !== 'string' || value.length === 0) {
    throw new Error(`Invalid human robot link field: ${key}.`);
  }
  return value;
}

function requiredEnum<const T extends string>(
  row: HouseholdAccessRow,
  key: string,
  values: readonly T[],
): T {
  const value = requiredString(row, key);
  if (!values.includes(value as T)) {
    throw new Error(`Invalid human robot link field: ${key}.`);
  }
  return value as T;
}

function fromAppwriteRow(row: Models.Row): HouseholdAccessRow {
  return { ...row, $id: row.$id };
}
