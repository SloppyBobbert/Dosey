import { AppwriteException, Query, TablesDB, type Models } from 'node-appwrite';

import type {
  HouseholdInvitationRecord,
  HouseholdLinkRecord,
  HouseholdPersistence,
  HouseholdRobotRecord,
  HouseholdTransaction,
} from './transactional-household-registry.js';

export type HouseholdTable = 'robots' | 'links' | 'invitations';
export type HouseholdRow = Readonly<Record<string, unknown>> & { readonly $id: string };

export interface HouseholdRowsApi {
  beginTransaction(): Promise<string>;
  commitTransaction(transactionId: string): Promise<void>;
  rollbackTransaction(transactionId: string): Promise<void>;
  getRow(table: HouseholdTable, rowId: string, transactionId: string): Promise<HouseholdRow | null>;
  createRow(table: HouseholdTable, row: HouseholdRow, transactionId: string): Promise<void>;
  upsertRow(table: HouseholdTable, row: HouseholdRow, transactionId: string): Promise<void>;
  updateRow(table: HouseholdTable, row: HouseholdRow, transactionId: string): Promise<void>;
  deleteRow(table: HouseholdTable, rowId: string, transactionId: string): Promise<void>;
  findInvitationsByDigest(codeDigest: string, transactionId: string): Promise<readonly HouseholdRow[]>;
}

export interface AppwriteHouseholdTableConfiguration {
  readonly databaseId: string;
  readonly robotInstallationsTableId: string;
  readonly humanRobotLinksTableId: string;
  readonly householdInvitationsTableId: string;
}

export class AppwriteHouseholdRowsApi implements HouseholdRowsApi {
  constructor(
    private readonly tables: TablesDB,
    private readonly configuration: AppwriteHouseholdTableConfiguration,
  ) {}

  async beginTransaction(): Promise<string> {
    return (await this.tables.createTransaction()).$id;
  }

  async commitTransaction(transactionId: string): Promise<void> {
    await this.tables.updateTransaction({ transactionId, commit: true });
  }

  async rollbackTransaction(transactionId: string): Promise<void> {
    await this.tables.updateTransaction({ transactionId, rollback: true });
  }

  async getRow(
    table: HouseholdTable,
    rowId: string,
    transactionId: string,
  ): Promise<HouseholdRow | null> {
    try {
      const row = await this.tables.getRow({
        databaseId: this.configuration.databaseId,
        tableId: this.tableId(table),
        rowId,
        transactionId,
      });
      return fromAppwriteRow(row);
    } catch (error) {
      if (error instanceof AppwriteException && error.code === 404) return null;
      throw error;
    }
  }

  async createRow(
    table: HouseholdTable,
    row: HouseholdRow,
    transactionId: string,
  ): Promise<void> {
    await this.tables.createRow({
      databaseId: this.configuration.databaseId,
      tableId: this.tableId(table),
      rowId: row.$id,
      data: withoutId(row),
      transactionId,
    });
  }

  async upsertRow(
    table: HouseholdTable,
    row: HouseholdRow,
    transactionId: string,
  ): Promise<void> {
    await this.tables.upsertRow({
      databaseId: this.configuration.databaseId,
      tableId: this.tableId(table),
      rowId: row.$id,
      data: withoutId(row),
      transactionId,
    });
  }

  async updateRow(
    table: HouseholdTable,
    row: HouseholdRow,
    transactionId: string,
  ): Promise<void> {
    await this.tables.updateRow({
      databaseId: this.configuration.databaseId,
      tableId: this.tableId(table),
      rowId: row.$id,
      data: withoutId(row),
      transactionId,
    });
  }

  async deleteRow(
    table: HouseholdTable,
    rowId: string,
    transactionId: string,
  ): Promise<void> {
    await this.tables.deleteRow({
      databaseId: this.configuration.databaseId,
      tableId: this.tableId(table),
      rowId,
      transactionId,
    });
  }

  async findInvitationsByDigest(
    codeDigest: string,
    transactionId: string,
  ): Promise<readonly HouseholdRow[]> {
    const result = await this.tables.listRows({
      databaseId: this.configuration.databaseId,
      tableId: this.configuration.householdInvitationsTableId,
      queries: [Query.equal('codeDigest', [codeDigest]), Query.limit(2)],
      transactionId,
    });
    return result.rows.map(fromAppwriteRow);
  }

  private tableId(table: HouseholdTable): string {
    switch (table) {
      case 'robots': return this.configuration.robotInstallationsTableId;
      case 'links': return this.configuration.humanRobotLinksTableId;
      case 'invitations': return this.configuration.householdInvitationsTableId;
    }
  }
}

export class AppwriteHouseholdPersistence implements HouseholdPersistence {
  constructor(
    private readonly rows: HouseholdRowsApi,
    private readonly reportRollbackFailure: (error: unknown) => void = () => {},
    private readonly maximumAttempts = 3,
  ) {}

  async transaction<T>(operation: (transaction: HouseholdTransaction) => Promise<T>): Promise<T> {
    for (let attempt = 1; ; attempt += 1) {
      const transactionId = await this.rows.beginTransaction();
      const transaction = new AppwriteHouseholdTransaction(this.rows, transactionId);
      try {
        const result = await operation(transaction);
        await this.rows.commitTransaction(transactionId);
        return result;
      } catch (error) {
        try {
          await this.rows.rollbackTransaction(transactionId);
        } catch (rollbackError) {
          this.reportRollbackFailure(rollbackError);
        }
        if (isConflict(error) && attempt < this.maximumAttempts) continue;
        throw error;
      }
    }
  }
}

class AppwriteHouseholdTransaction implements HouseholdTransaction {
  constructor(
    private readonly rows: HouseholdRowsApi,
    private readonly transactionId: string,
  ) {}

  async getRobot(robotId: string): Promise<HouseholdRobotRecord | null> {
    const row = await this.rows.getRow('robots', robotId, this.transactionId);
    return row == null ? null : robotFromRow(row);
  }

  createRobot(record: HouseholdRobotRecord): Promise<void> {
    return this.rows.createRow('robots', robotToRow(record), this.transactionId);
  }

  saveRobot(record: HouseholdRobotRecord): Promise<void> {
    return this.rows.updateRow('robots', robotToRow(record), this.transactionId);
  }

  async getLink(accountId: string): Promise<HouseholdLinkRecord | null> {
    const row = await this.rows.getRow('links', accountId, this.transactionId);
    return row == null ? null : linkFromRow(row);
  }

  createLink(record: HouseholdLinkRecord): Promise<void> {
    return this.rows.createRow('links', linkToRow(record), this.transactionId);
  }

  saveLink(record: HouseholdLinkRecord): Promise<void> {
    return this.rows.updateRow('links', linkToRow(record), this.transactionId);
  }

  deleteLink(accountId: string): Promise<void> {
    return this.rows.deleteRow('links', accountId, this.transactionId);
  }

  async getInvitation(id: string): Promise<HouseholdInvitationRecord | null> {
    const row = await this.rows.getRow('invitations', id, this.transactionId);
    return row == null ? null : invitationFromRow(row);
  }

  async findInvitationByDigest(codeDigest: string): Promise<HouseholdInvitationRecord | null> {
    const rows = await this.rows.findInvitationsByDigest(codeDigest, this.transactionId);
    if (rows.length > 1) throw new Error('Multiple household invitations share one digest.');
    return rows.length === 0 ? null : invitationFromRow(rows[0]!);
  }

  saveInvitation(record: HouseholdInvitationRecord): Promise<void> {
    return this.rows.upsertRow('invitations', invitationToRow(record), this.transactionId);
  }
}

function robotToRow(record: HouseholdRobotRecord): HouseholdRow {
  return {
    $id: record.id,
    ownerAccountId: record.ownerAccountId,
    displayName: record.displayName,
    humanCount: record.humanCount,
    status: record.status,
    createdAt: record.createdAt.toISOString(),
    updatedAt: record.updatedAt.toISOString(),
  };
}

function robotFromRow(row: HouseholdRow): HouseholdRobotRecord {
  return {
    id: row.$id,
    ownerAccountId: requiredString(row, 'ownerAccountId'),
    displayName: requiredString(row, 'displayName'),
    humanCount: requiredInteger(row, 'humanCount'),
    status: requiredEnum(row, 'status', ['provisioning', 'active']),
    createdAt: requiredDate(row, 'createdAt'),
    updatedAt: requiredDate(row, 'updatedAt'),
  };
}

function linkToRow(record: HouseholdLinkRecord): HouseholdRow {
  return {
    $id: record.accountId,
    robotId: record.robotId,
    role: record.role,
    membershipId: record.membershipId,
    status: record.status,
    createdAt: record.createdAt.toISOString(),
    updatedAt: record.updatedAt.toISOString(),
  };
}

function linkFromRow(row: HouseholdRow): HouseholdLinkRecord {
  return {
    accountId: row.$id,
    robotId: requiredString(row, 'robotId'),
    role: requiredEnum(row, 'role', ['owner', 'member']),
    membershipId: optionalString(row, 'membershipId'),
    status: requiredEnum(row, 'status', ['provisioning', 'active', 'revoking']),
    createdAt: requiredDate(row, 'createdAt'),
    updatedAt: requiredDate(row, 'updatedAt'),
  };
}

function invitationToRow(record: HouseholdInvitationRecord): HouseholdRow {
  return {
    $id: record.id,
    robotId: record.robotId,
    invitedEmail: record.invitedEmail,
    codeDigest: record.codeDigest,
    expiresAt: record.expiresAt.toISOString(),
    createdByAccountId: record.createdByAccountId,
    consumedAt: record.consumedAt?.toISOString() ?? null,
    acceptedAccountId: record.acceptedAccountId,
    revokedAt: record.revokedAt?.toISOString() ?? null,
    createdAt: record.createdAt.toISOString(),
    updatedAt: record.updatedAt.toISOString(),
  };
}

function invitationFromRow(row: HouseholdRow): HouseholdInvitationRecord {
  return {
    id: row.$id,
    robotId: requiredString(row, 'robotId'),
    invitedEmail: requiredString(row, 'invitedEmail'),
    codeDigest: requiredString(row, 'codeDigest'),
    expiresAt: requiredDate(row, 'expiresAt'),
    createdByAccountId: requiredString(row, 'createdByAccountId'),
    consumedAt: optionalDate(row, 'consumedAt'),
    acceptedAccountId: optionalString(row, 'acceptedAccountId'),
    revokedAt: optionalDate(row, 'revokedAt'),
    createdAt: requiredDate(row, 'createdAt'),
    updatedAt: requiredDate(row, 'updatedAt'),
  };
}

function requiredString(row: HouseholdRow, key: string): string {
  const value = row[key];
  if (typeof value !== 'string' || value.length === 0) throw new Error(`Invalid household row field: ${key}.`);
  return value;
}

function optionalString(row: HouseholdRow, key: string): string | null {
  if (row[key] == null) return null;
  return requiredString(row, key);
}

function requiredInteger(row: HouseholdRow, key: string): number {
  const value = row[key];
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 0) {
    throw new Error(`Invalid household row field: ${key}.`);
  }
  return value;
}

function requiredDate(row: HouseholdRow, key: string): Date {
  const date = new Date(requiredString(row, key));
  if (Number.isNaN(date.getTime())) throw new Error(`Invalid household row field: ${key}.`);
  return date;
}

function optionalDate(row: HouseholdRow, key: string): Date | null {
  return row[key] == null ? null : requiredDate(row, key);
}

function requiredEnum<const T extends string>(
  row: HouseholdRow,
  key: string,
  values: readonly T[],
): T {
  const value = requiredString(row, key);
  if (!values.includes(value as T)) throw new Error(`Invalid household row field: ${key}.`);
  return value as T;
}

function withoutId(row: HouseholdRow): Record<string, unknown> {
  const { $id: _, ...data } = row;
  return data;
}

function fromAppwriteRow(row: Models.Row): HouseholdRow {
  return { ...row, $id: row.$id };
}

function isConflict(error: unknown): boolean {
  return typeof error === 'object' && error != null && 'code' in error && error.code === 409;
}
