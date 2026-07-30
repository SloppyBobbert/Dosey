import { createHash } from 'node:crypto';

import { AppwriteException, Query, TablesDB, type Models } from 'node-appwrite';

import type {
  MedicationSyncChangeRecord,
  MedicationSyncDocumentRecord,
  MedicationSyncEventRecord,
  MedicationSyncHelpRequestRecord,
  MedicationSyncPersistence,
  MedicationSyncReceiptRecord,
  MedicationSyncResourceType,
  MedicationSyncStateRecord,
  MedicationSyncTransaction,
} from './transactional-medication-sync-store.js';

export type MedicationSyncTable =
  | 'documents'
  | 'events'
  | 'helpRequests'
  | 'receipts'
  | 'state'
  | 'changes';
export type MedicationSyncRow = Readonly<Record<string, unknown>> & { readonly $id: string };

export interface MedicationSyncRowsApi {
  beginTransaction(): Promise<string>;
  commitTransaction(transactionId: string): Promise<void>;
  rollbackTransaction(transactionId: string): Promise<void>;
  getRow(
    table: MedicationSyncTable,
    rowId: string,
    transactionId: string,
  ): Promise<MedicationSyncRow | null>;
  createRow(
    table: MedicationSyncTable,
    row: MedicationSyncRow,
    transactionId: string,
  ): Promise<void>;
  upsertRow(
    table: MedicationSyncTable,
    row: MedicationSyncRow,
    transactionId: string,
  ): Promise<void>;
  listChanges(
    robotId: string,
    afterSequence: number,
    throughSequence: number,
    limit: number,
    transactionId: string,
  ): Promise<readonly MedicationSyncRow[]>;
}

export interface AppwriteMedicationSyncTableConfiguration {
  readonly databaseId: string;
  readonly documentsTableId: string;
  readonly eventsTableId: string;
  readonly helpRequestsTableId: string;
  readonly receiptsTableId: string;
  readonly stateTableId: string;
  readonly changesTableId: string;
}

export class AppwriteMedicationSyncRowsApi implements MedicationSyncRowsApi {
  constructor(
    private readonly tables: TablesDB,
    private readonly configuration: AppwriteMedicationSyncTableConfiguration,
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
    table: MedicationSyncTable,
    rowId: string,
    transactionId: string,
  ): Promise<MedicationSyncRow | null> {
    try {
      return fromAppwriteRow(await this.tables.getRow({
        databaseId: this.configuration.databaseId,
        tableId: this.tableId(table),
        rowId,
        transactionId,
      }));
    } catch (error) {
      if (
        error instanceof AppwriteException &&
        error.code === 404 &&
        error.type === 'row_not_found'
      ) return null;
      throw error;
    }
  }

  async createRow(
    table: MedicationSyncTable,
    row: MedicationSyncRow,
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
    table: MedicationSyncTable,
    row: MedicationSyncRow,
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

  async listChanges(
    robotId: string,
    afterSequence: number,
    throughSequence: number,
    limit: number,
    transactionId: string,
  ): Promise<readonly MedicationSyncRow[]> {
    const result = await this.tables.listRows({
      databaseId: this.configuration.databaseId,
      tableId: this.configuration.changesTableId,
      queries: [
        Query.equal('robotId', [robotId]),
        Query.greaterThan('sequence', afterSequence),
        Query.lessThanEqual('sequence', throughSequence),
        Query.orderAsc('sequence'),
        Query.limit(limit),
      ],
      transactionId,
    });
    return result.rows.map(fromAppwriteRow);
  }

  private tableId(table: MedicationSyncTable): string {
    switch (table) {
      case 'documents': return this.configuration.documentsTableId;
      case 'events': return this.configuration.eventsTableId;
      case 'helpRequests': return this.configuration.helpRequestsTableId;
      case 'receipts': return this.configuration.receiptsTableId;
      case 'state': return this.configuration.stateTableId;
      case 'changes': return this.configuration.changesTableId;
    }
  }
}

export class AppwriteMedicationSyncPersistence implements MedicationSyncPersistence {
  constructor(
    private readonly rows: MedicationSyncRowsApi,
    private readonly reportRollbackFailure: (error: unknown) => void = () => {},
    private readonly maximumAttempts = 5,
    private readonly delay: (milliseconds: number) => Promise<void> = defaultDelay,
    private readonly random: () => number = Math.random,
  ) {
    if (!Number.isSafeInteger(maximumAttempts) || maximumAttempts < 1) {
      throw new Error('maximumAttempts must be a positive safe integer.');
    }
  }

  async transaction<T>(operation: (transaction: MedicationSyncTransaction) => Promise<T>): Promise<T> {
    for (let attempt = 1; ; attempt += 1) {
      const transactionId = await this.rows.beginTransaction();
      const transaction = new AppwriteMedicationSyncTransaction(this.rows, transactionId);
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
        if (isConflict(error) && attempt < this.maximumAttempts) {
          await this.delay(retryDelay(attempt, this.random));
          continue;
        }
        throw error;
      }
    }
  }
}

class AppwriteMedicationSyncTransaction implements MedicationSyncTransaction {
  constructor(
    private readonly rows: MedicationSyncRowsApi,
    private readonly transactionId: string,
  ) {}

  async getDocument(
    robotId: string,
    resourceType: MedicationSyncResourceType,
    resourceId: string,
  ): Promise<MedicationSyncDocumentRecord | null> {
    const row = await this.rows.getRow(
      'documents',
      rowId('document', robotId, resourceType, resourceId),
      this.transactionId,
    );
    return row == null ? null : documentFromRow(row);
  }

  saveDocument(record: MedicationSyncDocumentRecord): Promise<void> {
    return this.rows.upsertRow('documents', documentToRow(record), this.transactionId);
  }

  async getEvent(robotId: string, eventId: string): Promise<MedicationSyncEventRecord | null> {
    const row = await this.rows.getRow(
      'events',
      rowId('event', robotId, eventId),
      this.transactionId,
    );
    return row == null ? null : eventFromRow(row);
  }

  createEvent(record: MedicationSyncEventRecord): Promise<void> {
    return this.rows.createRow('events', eventToRow(record), this.transactionId);
  }

  createHelpRequest(record: MedicationSyncHelpRequestRecord): Promise<void> {
    return this.rows.createRow('helpRequests', helpRequestToRow(record), this.transactionId);
  }

  async getReceipt(robotId: string, idempotencyKey: string): Promise<MedicationSyncReceiptRecord | null> {
    const row = await this.rows.getRow(
      'receipts',
      rowId('receipt', robotId, idempotencyKey),
      this.transactionId,
    );
    return row == null ? null : receiptFromRow(row);
  }

  saveReceipt(record: MedicationSyncReceiptRecord): Promise<void> {
    return this.rows.upsertRow('receipts', receiptToRow(record), this.transactionId);
  }

  async getState(robotId: string): Promise<MedicationSyncStateRecord | null> {
    const row = await this.rows.getRow('state', rowId('state', robotId), this.transactionId);
    return row == null ? null : stateFromRow(row);
  }

  saveState(record: MedicationSyncStateRecord): Promise<void> {
    return this.rows.upsertRow('state', stateToRow(record), this.transactionId);
  }

  createChange(record: MedicationSyncChangeRecord): Promise<void> {
    return this.rows.createRow('changes', changeToRow(record), this.transactionId);
  }

  async listChanges(
    robotId: string,
    afterSequence: number,
    throughSequence: number,
    limit: number,
  ): Promise<readonly MedicationSyncChangeRecord[]> {
    return (await this.rows.listChanges(
      robotId,
      afterSequence,
      throughSequence,
      limit,
      this.transactionId,
    )).map(changeFromRow);
  }
}

function documentToRow(record: MedicationSyncDocumentRecord): MedicationSyncRow {
  return {
    $id: rowId('document', record.robotId, record.resourceType, record.resourceId),
    ...record,
    createdAt: record.createdAt.toISOString(),
    updatedAt: record.updatedAt.toISOString(),
  };
}

function documentFromRow(row: MedicationSyncRow): MedicationSyncDocumentRecord {
  return {
    robotId: requiredString(row, 'robotId'),
    resourceType: requiredEnum(row, 'resourceType', ['medication', 'schedule']),
    resourceId: requiredString(row, 'resourceId'),
    version: requiredInteger(row, 'version'),
    archived: requiredBoolean(row, 'archived'),
    payload: requiredString(row, 'payload'),
    createdAt: requiredDate(row, 'createdAt'),
    createdByAccountId: requiredString(row, 'createdByAccountId'),
    updatedAt: requiredDate(row, 'updatedAt'),
    updatedByAccountId: requiredString(row, 'updatedByAccountId'),
  };
}

function eventToRow(record: MedicationSyncEventRecord): MedicationSyncRow {
  return {
    $id: rowId('event', record.robotId, record.eventId),
    ...record,
    occurredAt: record.occurredAt.toISOString(),
    receivedAt: record.receivedAt.toISOString(),
  };
}

function eventFromRow(row: MedicationSyncRow): MedicationSyncEventRecord {
  return {
    robotId: requiredString(row, 'robotId'),
    eventId: requiredString(row, 'eventId'),
    eventHash: requiredString(row, 'eventHash'),
    kind: requiredEnum(row, 'kind', ['taken_confirmed', 'skipped', 'snoozed', 'help_requested']),
    doseId: requiredString(row, 'doseId'),
    scheduleId: requiredString(row, 'scheduleId'),
    payload: requiredString(row, 'payload'),
    occurredAt: requiredDate(row, 'occurredAt'),
    receivedAt: requiredDate(row, 'receivedAt'),
    actorAccountId: requiredString(row, 'actorAccountId'),
    sequence: requiredInteger(row, 'sequence'),
  };
}

function helpRequestToRow(record: MedicationSyncHelpRequestRecord): MedicationSyncRow {
  return {
    $id: rowId('helpRequest', record.robotId, record.helpRequestId),
    ...record,
    openedAt: record.openedAt.toISOString(),
    updatedAt: record.updatedAt.toISOString(),
  };
}

function receiptToRow(record: MedicationSyncReceiptRecord): MedicationSyncRow {
  return {
    $id: rowId('receipt', record.robotId, record.idempotencyKey),
    ...record,
    createdAt: record.createdAt.toISOString(),
  };
}

function receiptFromRow(row: MedicationSyncRow): MedicationSyncReceiptRecord {
  return {
    robotId: requiredString(row, 'robotId'),
    idempotencyKey: requiredString(row, 'idempotencyKey'),
    operationHash: requiredString(row, 'operationHash'),
    sequence: requiredInteger(row, 'sequence'),
    resourceVersion: optionalInteger(row, 'resourceVersion'),
    createdAt: requiredDate(row, 'createdAt'),
  };
}

function stateToRow(record: MedicationSyncStateRecord): MedicationSyncRow {
  return {
    $id: rowId('state', record.robotId),
    ...record,
    updatedAt: record.updatedAt.toISOString(),
  };
}

function stateFromRow(row: MedicationSyncRow): MedicationSyncStateRecord {
  return {
    robotId: requiredString(row, 'robotId'),
    highWatermark: requiredInteger(row, 'highWatermark'),
    updatedAt: requiredDate(row, 'updatedAt'),
  };
}

function changeToRow(record: MedicationSyncChangeRecord): MedicationSyncRow {
  return {
    $id: rowId('change', record.robotId, String(record.sequence)),
    ...record,
    changedAt: record.changedAt.toISOString(),
  };
}

function changeFromRow(row: MedicationSyncRow): MedicationSyncChangeRecord {
  return {
    robotId: requiredString(row, 'robotId'),
    sequence: requiredInteger(row, 'sequence'),
    resourceType: requiredEnum(
      row,
      'resourceType',
      ['medication', 'schedule', 'doseEvent'],
    ),
    resourceId: requiredString(row, 'resourceId'),
    resourceVersion: optionalInteger(row, 'resourceVersion'),
    operation: requiredEnum(row, 'operation', ['upsert', 'archive', 'event']),
    payload: requiredString(row, 'payload'),
    actorAccountId: requiredString(row, 'actorAccountId'),
    actorRole: requiredEnum(row, 'actorRole', ['owner', 'member', 'device']),
    changedAt: requiredDate(row, 'changedAt'),
    idempotencyKey: requiredString(row, 'idempotencyKey'),
    operationHash: requiredString(row, 'operationHash'),
  };
}

function rowId(...parts: readonly string[]): string {
  return createHash('sha256').update(parts.join('\u0000')).digest('hex').slice(0, 36);
}

function requiredString(row: MedicationSyncRow, key: string): string {
  const value = row[key];
  if (typeof value !== 'string' || value.length === 0) {
    throw new Error(`Invalid medication sync row field: ${key}.`);
  }
  return value;
}

function requiredInteger(row: MedicationSyncRow, key: string): number {
  const value = row[key];
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < 0) {
    throw new Error(`Invalid medication sync row field: ${key}.`);
  }
  return value;
}

function optionalInteger(row: MedicationSyncRow, key: string): number | null {
  return row[key] == null ? null : requiredInteger(row, key);
}

function requiredBoolean(row: MedicationSyncRow, key: string): boolean {
  const value = row[key];
  if (typeof value !== 'boolean') {
    throw new Error(`Invalid medication sync row field: ${key}.`);
  }
  return value;
}

function requiredDate(row: MedicationSyncRow, key: string): Date {
  const value = new Date(requiredString(row, key));
  if (Number.isNaN(value.getTime())) {
    throw new Error(`Invalid medication sync row field: ${key}.`);
  }
  return value;
}

function requiredEnum<const T extends string>(
  row: MedicationSyncRow,
  key: string,
  values: readonly T[],
): T {
  const value = requiredString(row, key);
  if (!values.includes(value as T)) {
    throw new Error(`Invalid medication sync row field: ${key}.`);
  }
  return value as T;
}

function fromAppwriteRow(row: Models.Row): MedicationSyncRow {
  return { ...row, $id: row.$id };
}

function withoutId(row: MedicationSyncRow): Record<string, unknown> {
  const { $id: _, ...data } = row;
  return data;
}

function isConflict(error: unknown): boolean {
  return error instanceof AppwriteException &&
    error.code === 409 &&
    (error.type === 'transaction_conflict' || error.type === 'row_update_conflict');
}

function retryDelay(attempt: number, random: () => number): number {
  const base = 10 * 2 ** (attempt - 1);
  return base + Math.floor(Math.max(0, Math.min(1, random())) * (base + 1));
}

function defaultDelay(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
