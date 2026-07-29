import { Query, TablesDB, type Models } from 'node-appwrite';

import type {
  MountedRobotAccessRecord,
  RobotInstallationRecord,
} from '../domain/mounted-robot-access.js';
import type { MountedRobotLookup } from '../application/mounted-robot-services.js';
import { isNotFound } from './appwrite-errors.js';

export interface AppwriteMountedRobotAccessConfiguration {
  readonly databaseId: string;
  readonly mountedRobotAccessTableId: string;
  readonly robotInstallationsTableId: string;
}

export class AppwriteMountedRobotAccessReader implements MountedRobotLookup {
  constructor(
    private readonly tables: TablesDB,
    private readonly configuration: AppwriteMountedRobotAccessConfiguration,
  ) {}

  async findByDevice(accountId: string): Promise<readonly MountedRobotAccessRecord[]> {
    const result = await this.tables.listRows({
      databaseId: this.configuration.databaseId,
      tableId: this.configuration.mountedRobotAccessTableId,
      queries: [Query.equal('mountedDeviceAccountId', [accountId]), Query.limit(2)],
    });
    return result.rows.map((row) => mountedAccessFromRow(row, accountId));
  }

  async getRobotInstallation(robotId: string): Promise<RobotInstallationRecord | null> {
    try {
      const row = await this.tables.getRow({
        databaseId: this.configuration.databaseId,
        tableId: this.configuration.robotInstallationsTableId,
        rowId: robotId,
      });
      return installationFromRow(row, robotId);
    } catch (error) {
      if (isNotFound(error)) return null;
      throw error;
    }
  }
}

function mountedAccessFromRow(
  row: Models.Row,
  expectedDeviceAccountId: string,
): MountedRobotAccessRecord {
  const record = {
    robotId: requiredString(row, 'robotId'),
    mountedDeviceAccountId: requiredString(row, 'mountedDeviceAccountId'),
    pairingClaimId: requiredString(row, 'pairingClaimId'),
    createdAt: requiredDate(row, 'createdAt'),
    updatedAt: requiredDate(row, 'updatedAt'),
  };
  if (row.$id !== record.robotId) {
    throw new Error('Mounted robot access row ID does not match robotId.');
  }
  if (record.mountedDeviceAccountId !== expectedDeviceAccountId) {
    throw new Error('Mounted robot access row device does not match the requested account.');
  }
  return record;
}

function installationFromRow(row: Models.Row, expectedRobotId: string): RobotInstallationRecord {
  if (row.$id !== expectedRobotId) {
    throw new Error('Robot installation row ID does not match robotId.');
  }
  const status = requiredString(row, 'status');
  if (status !== 'active' && status !== 'provisioning') {
    throw new Error('Invalid robot installation status.');
  }
  return {
    robotId: row.$id,
    displayName: requiredString(row, 'displayName'),
    status,
  };
}

function requiredString(row: Models.Row, key: string): string {
  const value = (row as Record<string, unknown>)[key];
  if (typeof value !== 'string' || value.length === 0) {
    throw new Error(`Invalid mounted robot row field: ${key}.`);
  }
  return value;
}

function requiredDate(row: Models.Row, key: string): Date {
  const value = requiredString(row, key);
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new Error(`Invalid mounted robot row field: ${key}.`);
  }
  return date;
}
