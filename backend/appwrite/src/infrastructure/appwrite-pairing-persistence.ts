import { Query, TablesDB, type Models } from 'node-appwrite';

import type { PairingClaimRecord } from '../domain/pairing-claim.js';
import type { MountedRobotAccessRecord } from '../domain/mounted-robot-access.js';
import type {
  PairingAttemptRecord,
  PairingPersistence,
  PairingTransaction,
} from './transactional-pairing-store.js';
import { isNotFound } from './appwrite-errors.js';

export type PairingRow = Readonly<Record<string, unknown>> & {
  readonly $id: string;
};

// Keeps Appwrite row/query details out of the pairing application layer.
export interface PairingRowsApi {
  beginTransaction(): Promise<string>;
  commitTransaction(transactionId: string): Promise<void>;
  rollbackTransaction(transactionId: string): Promise<void>;
  deactivateRobotClaims(
    robotId: string,
    transactionId: string,
  ): Promise<void>;
  createClaim(row: PairingRow, transactionId: string): Promise<void>;
  findClaimsByDigest(
    codeDigest: string,
    transactionId: string,
  ): Promise<readonly PairingRow[]>;
  updateClaim(
    rowId: string,
    data: PairingRow,
    transactionId: string,
  ): Promise<void>;
  getAttempt(
    deviceAccountId: string,
    transactionId: string,
  ): Promise<PairingRow | null>;
  upsertAttempt(row: PairingRow, transactionId: string): Promise<void>;
  findMountedAccessByDevice(
    deviceAccountId: string,
    transactionId: string,
  ): Promise<readonly PairingRow[]>;
  getMountedAccessByRobot(
    robotId: string,
    transactionId: string,
  ): Promise<PairingRow | null>;
  createMountedAccess(row: PairingRow, transactionId: string): Promise<void>;
  updateMountedAccess(rowId: string, data: PairingRow, transactionId: string): Promise<void>;
}

export interface AppwritePairingTableConfiguration {
  readonly databaseId: string;
  readonly pairingClaimsTableId: string;
  readonly pairingAttemptsTableId: string;
  readonly mountedRobotAccessTableId?: string;
}

export class PairingTransactionConflictError extends Error {
  constructor() {
    super('The pairing transaction conflicted with another request.');
    this.name = 'PairingTransactionConflictError';
  }
}

export class AppwritePairingRowsApi implements PairingRowsApi {
  constructor(
    private readonly tables: TablesDB,
    private readonly configuration: AppwritePairingTableConfiguration,
  ) {}

  async beginTransaction(): Promise<string> {
    const transaction = await this.tables.createTransaction();
    return transaction.$id;
  }

  async commitTransaction(transactionId: string): Promise<void> {
    await this.tables.updateTransaction({ transactionId, commit: true });
  }

  async rollbackTransaction(transactionId: string): Promise<void> {
    await this.tables.updateTransaction({ transactionId, rollback: true });
  }

  async deactivateRobotClaims(
    robotId: string,
    transactionId: string,
  ): Promise<void> {
    await this.tables.updateRows({
      databaseId: this.configuration.databaseId,
      tableId: this.configuration.pairingClaimsTableId,
      data: { active: false },
      queries: [Query.equal('robotId', [robotId]), Query.equal('active', [true])],
      transactionId,
    });
  }

  async createClaim(row: PairingRow, transactionId: string): Promise<void> {
    await this.tables.createRow({
      databaseId: this.configuration.databaseId,
      tableId: this.configuration.pairingClaimsTableId,
      rowId: row.$id,
      data: withoutId(row),
      transactionId,
    });
  }

  async findClaimsByDigest(
    codeDigest: string,
    transactionId: string,
  ): Promise<readonly PairingRow[]> {
    const result = await this.tables.listRows({
      databaseId: this.configuration.databaseId,
      tableId: this.configuration.pairingClaimsTableId,
      queries: [
        Query.equal('codeDigest', [codeDigest]),
        Query.equal('active', [true]),
        Query.limit(2),
      ],
      transactionId,
    });
    return result.rows.map(rowFromAppwrite);
  }

  async updateClaim(
    rowId: string,
    data: PairingRow,
    transactionId: string,
  ): Promise<void> {
    await this.tables.updateRow({
      databaseId: this.configuration.databaseId,
      tableId: this.configuration.pairingClaimsTableId,
      rowId,
      data: withoutId(data),
      transactionId,
    });
  }

  async getAttempt(
    deviceAccountId: string,
    transactionId: string,
  ): Promise<PairingRow | null> {
    try {
      const row = await this.tables.getRow({
        databaseId: this.configuration.databaseId,
        tableId: this.configuration.pairingAttemptsTableId,
        rowId: deviceAccountId,
        transactionId,
      });
      return rowFromAppwrite(row);
    } catch (error) {
      if (isNotFound(error)) return null;
      throw error;
    }
  }

  async upsertAttempt(row: PairingRow, transactionId: string): Promise<void> {
    await this.tables.upsertRow({
      databaseId: this.configuration.databaseId,
      tableId: this.configuration.pairingAttemptsTableId,
      rowId: row.$id,
      data: withoutId(row),
      transactionId,
    });
  }

  async findMountedAccessByDevice(
    deviceAccountId: string,
    transactionId: string,
  ): Promise<readonly PairingRow[]> {
    const result = await this.tables.listRows({
      databaseId: this.configuration.databaseId,
      tableId: mountedAccessTableId(this.configuration),
      queries: [Query.equal('mountedDeviceAccountId', [deviceAccountId]), Query.limit(2)],
      transactionId,
    });
    return result.rows.map(rowFromAppwrite);
  }

  async getMountedAccessByRobot(
    robotId: string,
    transactionId: string,
  ): Promise<PairingRow | null> {
    try {
      const row = await this.tables.getRow({
        databaseId: this.configuration.databaseId,
        tableId: mountedAccessTableId(this.configuration),
        rowId: robotId,
        transactionId,
      });
      return rowFromAppwrite(row);
    } catch (error) {
      if (isNotFound(error)) return null;
      throw error;
    }
  }

  async createMountedAccess(row: PairingRow, transactionId: string): Promise<void> {
    await this.tables.createRow({
      databaseId: this.configuration.databaseId,
      tableId: mountedAccessTableId(this.configuration),
      rowId: row.$id,
      data: withoutId(row),
      transactionId,
    });
  }

  async updateMountedAccess(
    rowId: string,
    data: PairingRow,
    transactionId: string,
  ): Promise<void> {
    await this.tables.updateRow({
      databaseId: this.configuration.databaseId,
      tableId: mountedAccessTableId(this.configuration),
      rowId,
      data: withoutId(data),
      transactionId,
    });
  }
}

export class AppwritePairingPersistence implements PairingPersistence {
  constructor(
    private readonly rows: PairingRowsApi,
    private readonly reportRollbackFailure: (error: unknown) => void = () => {},
  ) {}

  async transaction<T>(
    operation: (transaction: PairingTransaction) => Promise<T>,
  ): Promise<T> {
    const transactionId = await this.rows.beginTransaction();
    const transaction = new AppwritePairingTransaction(this.rows, transactionId);
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
      if (isConflict(error)) throw new PairingTransactionConflictError();
      throw error;
    }
  }

  async resolveClaimConflict(input: {
    codeDigest: string;
    robotId: string;
    mountedDeviceAccountId: string;
  }): Promise<'accepted' | 'consumed' | 'device_already_mounted' | 'unknown'> {
    const transactionId = await this.rows.beginTransaction();
    const transaction = new AppwritePairingTransaction(this.rows, transactionId);
    try {
      const deviceAccess = await transaction.findMountedAccessByDevice(
        input.mountedDeviceAccountId,
      );
      if (deviceAccess.length > 1) {
        throw new Error('Multiple mounted robot access rows share one device.');
      }
      if (deviceAccess[0] != null && deviceAccess[0].robotId !== input.robotId) {
        return 'device_already_mounted';
      }

      const claim = await transaction.findActiveClaimByDigest(input.codeDigest);
      if (claim?.consumedAt == null) return 'unknown';
      if (claim.mountedDeviceAccountId == null) return 'unknown';
      if (claim.mountedDeviceAccountId !== input.mountedDeviceAccountId) {
        return 'consumed';
      }
      const robotAccess = await transaction.getMountedAccessByRobot(input.robotId);
      if (
        robotAccess?.mountedDeviceAccountId === input.mountedDeviceAccountId &&
        robotAccess.pairingClaimId === claim.id
      ) {
        return 'accepted';
      }
      return 'unknown';
    } finally {
      try {
        await this.rows.rollbackTransaction(transactionId);
      } catch (error) {
        this.reportRollbackFailure(error);
      }
    }
  }
}

function isConflict(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error != null &&
    'code' in error &&
    error.code === 409
  );
}

class AppwritePairingTransaction implements PairingTransaction {
  constructor(
    private readonly rows: PairingRowsApi,
    private readonly transactionId: string,
  ) {}

  deactivateRobotClaims(robotId: string): Promise<void> {
    return this.rows.deactivateRobotClaims(robotId, this.transactionId);
  }

  createClaim(record: PairingClaimRecord): Promise<void> {
    return this.rows.createClaim(claimToRow(record), this.transactionId);
  }

  async findActiveClaimByDigest(
    codeDigest: string,
  ): Promise<PairingClaimRecord | null> {
    const rows = await this.rows.findClaimsByDigest(
      codeDigest,
      this.transactionId,
    );
    if (rows.length > 1) {
      throw new Error('Multiple active pairing claims share one digest.');
    }
    return rows.length === 0 ? null : claimFromRow(rows[0]!);
  }

  saveClaim(record: PairingClaimRecord): Promise<void> {
    return this.rows.updateClaim(
      record.id,
      claimToRow(record),
      this.transactionId,
    );
  }

  async getAttempt(
    deviceAccountId: string,
  ): Promise<PairingAttemptRecord | null> {
    const row = await this.rows.getAttempt(deviceAccountId, this.transactionId);
    return row == null ? null : attemptFromRow(row);
  }

  saveAttempt(record: PairingAttemptRecord): Promise<void> {
    return this.rows.upsertAttempt(attemptToRow(record), this.transactionId);
  }

  async findMountedAccessByDevice(
    deviceAccountId: string,
  ): Promise<readonly MountedRobotAccessRecord[]> {
    return (await this.rows.findMountedAccessByDevice(deviceAccountId, this.transactionId))
      .map((row) => mountedAccessFromRow(row, undefined, deviceAccountId));
  }

  async getMountedAccessByRobot(robotId: string): Promise<MountedRobotAccessRecord | null> {
    const row = await this.rows.getMountedAccessByRobot(robotId, this.transactionId);
    return row == null ? null : mountedAccessFromRow(row, robotId);
  }

  createMountedAccess(record: MountedRobotAccessRecord): Promise<void> {
    return this.rows.createMountedAccess(mountedAccessToRow(record), this.transactionId);
  }

  updateMountedAccess(record: MountedRobotAccessRecord): Promise<void> {
    return this.rows.updateMountedAccess(
      record.robotId,
      mountedAccessToRow(record),
      this.transactionId,
    );
  }
}

function claimToRow(record: PairingClaimRecord): PairingRow {
  return {
    $id: record.id,
    robotId: record.robotId,
    codeDigest: record.codeDigest,
    expiresAt: record.expiresAt.toISOString(),
    consumedAt: record.consumedAt?.toISOString() ?? null,
    mountedDeviceAccountId: record.mountedDeviceAccountId ?? null,
    // Legacy live-schema field. Per-device attempt rows are authoritative.
    failedAttempts: 0,
    active: true,
  };
}

function claimFromRow(row: PairingRow): PairingClaimRecord {
  const mountedDeviceAccountId = optionalString(
    row,
    'mountedDeviceAccountId',
  );
  return {
    id: row.$id,
    robotId: requiredString(row, 'robotId'),
    codeDigest: requiredString(row, 'codeDigest'),
    expiresAt: requiredDate(row, 'expiresAt'),
    consumedAt: optionalDate(row, 'consumedAt'),
    ...(mountedDeviceAccountId == null ? {} : { mountedDeviceAccountId }),
  };
}

function attemptToRow(record: PairingAttemptRecord): PairingRow {
  return {
    $id: record.deviceAccountId,
    deviceAccountId: record.deviceAccountId,
    failedAttempts: record.failedAttempts,
    blockedUntil: record.blockedUntil?.toISOString() ?? null,
  };
}

function attemptFromRow(row: PairingRow): PairingAttemptRecord {
  return {
    deviceAccountId: requiredString(row, 'deviceAccountId'),
    failedAttempts: requiredNumber(row, 'failedAttempts'),
    blockedUntil: optionalDate(row, 'blockedUntil'),
  };
}

function mountedAccessToRow(record: MountedRobotAccessRecord): PairingRow {
  return {
    $id: record.robotId,
    robotId: record.robotId,
    mountedDeviceAccountId: record.mountedDeviceAccountId,
    pairingClaimId: record.pairingClaimId,
    createdAt: record.createdAt.toISOString(),
    updatedAt: record.updatedAt.toISOString(),
  };
}

function mountedAccessFromRow(
  row: PairingRow,
  expectedRobotId?: string,
  expectedDeviceAccountId?: string,
): MountedRobotAccessRecord {
  const record = {
    robotId: requiredString(row, 'robotId'),
    mountedDeviceAccountId: requiredString(row, 'mountedDeviceAccountId'),
    pairingClaimId: requiredString(row, 'pairingClaimId'),
    createdAt: requiredDate(row, 'createdAt'),
    updatedAt: requiredDate(row, 'updatedAt'),
  };
  if (row.$id !== record.robotId || (expectedRobotId != null && row.$id !== expectedRobotId)) {
    throw new Error('Mounted robot access row ID does not match robotId.');
  }
  if (
    expectedDeviceAccountId != null &&
    record.mountedDeviceAccountId !== expectedDeviceAccountId
  ) {
    throw new Error('Mounted robot access row device does not match the requested account.');
  }
  return record;
}

function mountedAccessTableId(
  configuration: AppwritePairingTableConfiguration,
): string {
  if (configuration.mountedRobotAccessTableId == null) {
    throw new Error('Mounted robot access table is required for claim operations.');
  }
  return configuration.mountedRobotAccessTableId;
}

function requiredString(row: PairingRow, key: string): string {
  const value = row[key];
  if (typeof value !== 'string' || value.length === 0) {
    throw new Error(`Invalid pairing row field: ${key}.`);
  }
  return value;
}

function optionalString(row: PairingRow, key: string): string | undefined {
  const value = row[key];
  if (value == null) return undefined;
  if (typeof value !== 'string' || value.length === 0) {
    throw new Error(`Invalid pairing row field: ${key}.`);
  }
  return value;
}

function requiredNumber(row: PairingRow, key: string): number {
  const value = row[key];
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 0) {
    throw new Error(`Invalid pairing row field: ${key}.`);
  }
  return value;
}

function requiredDate(row: PairingRow, key: string): Date {
  const value = requiredString(row, key);
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new Error(`Invalid pairing row field: ${key}.`);
  }
  return parsed;
}

function optionalDate(row: PairingRow, key: string): Date | null {
  if (row[key] == null) return null;
  return requiredDate(row, key);
}

function withoutId(row: PairingRow): Record<string, unknown> {
  const { $id: _, ...data } = row;
  return data;
}

function rowFromAppwrite(row: Models.Row): PairingRow {
  return { ...row, $id: row.$id };
}
