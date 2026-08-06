import { createHash } from "node:crypto";

import { AppwriteException, Query, TablesDB, type Models } from "node-appwrite";

import type {
  TerminalLedgerChange,
  TerminalLedgerConflict,
  TerminalLedgerPersistence,
  TerminalLedgerRow,
  TerminalLedgerState,
  TerminalLedgerTransaction,
  TransactionStatus,
} from "./transactional-terminal-ledger-store.js";

export type TerminalLedgerTable =
  "ledger" | "changes" | "state" | "terminalConflicts";
export type TerminalLedgerAppwriteRow = Readonly<Record<string, unknown>> & {
  readonly $id: string;
};

export interface TerminalLedgerRowsApi {
  beginTransaction(): Promise<string>;
  commitTransaction(transactionId: string): Promise<void>;
  rollbackTransaction(transactionId: string): Promise<void>;
  getTransaction(transactionId: string): Promise<TransactionStatus>;
  getRow(
    table: TerminalLedgerTable,
    rowId: string,
    transactionId: string,
  ): Promise<TerminalLedgerAppwriteRow | null>;
  listRows(
    table: TerminalLedgerTable,
    queries: readonly string[],
    transactionId: string,
  ): Promise<readonly TerminalLedgerAppwriteRow[]>;
  createRow(
    table: TerminalLedgerTable,
    row: TerminalLedgerAppwriteRow,
    transactionId: string,
  ): Promise<void>;
  upsertRow(
    table: TerminalLedgerTable,
    row: TerminalLedgerAppwriteRow,
    transactionId: string,
  ): Promise<void>;
}

export interface AppwriteTerminalLedgerTableConfiguration {
  readonly databaseId: string;
  readonly terminalLedgerTableId: string;
  readonly stateTableId: string;
  readonly changesTableId: string;
  readonly terminalConflictsTableId: string;
}

export class AppwriteTerminalLedgerRowsApi implements TerminalLedgerRowsApi {
  constructor(
    private readonly tables: TablesDB,
    private readonly configuration: AppwriteTerminalLedgerTableConfiguration,
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
  async getTransaction(transactionId: string): Promise<TransactionStatus> {
    const status = (await this.tables.getTransaction({ transactionId })).status;
    if (!isStatus(status))
      throw new Error("Unknown Appwrite transaction status.");
    return status;
  }
  async getRow(
    table: TerminalLedgerTable,
    rowId: string,
    transactionId: string,
  ): Promise<TerminalLedgerAppwriteRow | null> {
    try {
      return fromRow(
        await this.tables.getRow({
          databaseId: this.configuration.databaseId,
          tableId: this.tableId(table),
          rowId,
          transactionId,
        }),
      );
    } catch (error) {
      if (isNotFound(error)) return null;
      throw error;
    }
  }
  async listRows(
    table: TerminalLedgerTable,
    queries: readonly string[],
    transactionId: string,
  ): Promise<readonly TerminalLedgerAppwriteRow[]> {
    const result = await this.tables.listRows({
      databaseId: this.configuration.databaseId,
      tableId: this.tableId(table),
      queries: [...queries, Query.limit(2)],
      transactionId,
    });
    return result.rows.map(fromRow);
  }
  async createRow(
    table: TerminalLedgerTable,
    row: TerminalLedgerAppwriteRow,
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
    table: TerminalLedgerTable,
    row: TerminalLedgerAppwriteRow,
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
  private tableId(table: TerminalLedgerTable): string {
    switch (table) {
      case "ledger":
        return this.configuration.terminalLedgerTableId;
      case "state":
        return this.configuration.stateTableId;
      case "changes":
        return this.configuration.changesTableId;
      case "terminalConflicts":
        return this.configuration.terminalConflictsTableId;
    }
  }
}

export class AppwriteTerminalLedgerPersistence implements TerminalLedgerPersistence {
  constructor(
    private readonly rows: TerminalLedgerRowsApi,
    private readonly reportRollbackFailure: (error: unknown) => void = () => {},
    private readonly maximumAttempts = 5,
    private readonly delay: (
      milliseconds: number,
    ) => Promise<void> = defaultDelay,
    private readonly random: () => number = Math.random,
  ) {
    if (!Number.isSafeInteger(maximumAttempts) || maximumAttempts < 1)
      throw new Error("maximumAttempts must be a positive safe integer.");
  }
  async transaction<T>(
    operation: (transaction: TerminalLedgerTransaction) => Promise<T>,
  ) {
    for (let attempt = 1; ; attempt += 1) {
      let transactionId: string;
      try {
        transactionId = await this.rows.beginTransaction();
      } catch (error) {
        return { outcome: "not_committed" as const, status: "failed" as const, error };
      }
      try {
        const value = await operation(
          new AppwriteTerminalLedgerTransaction(this.rows, transactionId),
        );
        try {
          await this.rows.commitTransaction(transactionId);
        } catch (error) {
          const result = await this.resolveCommit<T>(
            transactionId,
            value,
            error,
          );
          if (
            result.outcome === "not_committed" &&
            isConflict(error) &&
            attempt < this.maximumAttempts
          ) {
            await this.delay(retryDelay(attempt, this.random));
            continue;
          }
          return result;
        }
        return this.resolveCommit<T>(transactionId, value);
      } catch (error) {
        await this.rollback(transactionId);
        if (isConflict(error) && attempt < this.maximumAttempts) {
          await this.delay(retryDelay(attempt, this.random));
          continue;
        }
        return {
          outcome: "not_committed" as const,
          status: "failed" as const,
          error,
        };
      }
    }
  }
  private async resolveCommit<T>(
    transactionId: string,
    value: T,
    error?: unknown,
  ) {
    try {
      const status = await this.rows.getTransaction(transactionId);
      if (status === "committed")
        return { outcome: "committed" as const, value };
      if (status === "rolled_back" || status === "failed")
        return {
          outcome: "not_committed" as const,
          status,
          ...(error === undefined ? {} : { error }),
        };
      return {
        outcome: "indeterminate" as const,
        transactionId,
        observedStatus: status,
        ...(error === undefined ? {} : { error }),
      };
    } catch (statusError) {
      return {
        outcome: "indeterminate" as const,
        transactionId,
        ...(error === undefined ? { error: statusError } : { error }),
      };
    }
  }
  private async rollback(transactionId: string): Promise<void> {
    try {
      await this.rows.rollbackTransaction(transactionId);
    } catch (error) {
      this.reportRollbackFailure(error);
    }
  }
}

class AppwriteTerminalLedgerTransaction implements TerminalLedgerTransaction {
  constructor(
    private readonly rows: TerminalLedgerRowsApi,
    private readonly transactionId: string,
  ) {}
  async getAcceptedOccurrence(robotId: string, occurrenceId: string) {
    return this.one(
      "ledger",
      [
        Query.equal("robotId", [robotId]),
        Query.equal("occurrenceId", [occurrenceId]),
      ],
      ledgerFromRow,
    );
  }
  async getIdempotency(robotId: string, idempotencyKey: string) {
    return this.one(
      "ledger",
      [
        Query.equal("robotId", [robotId]),
        Query.equal("idempotencyKey", [idempotencyKey]),
      ],
      ledgerFromRow,
    );
  }
  async getEvent(robotId: string, eventId: string) {
    return this.one(
      "ledger",
      [Query.equal("robotId", [robotId]), Query.equal("eventId", [eventId])],
      ledgerFromRow,
    );
  }
  async getConflict(id: string): Promise<TerminalLedgerConflict | null> {
    const row = await this.rows.getRow(
      "terminalConflicts",
      id,
      this.transactionId,
    );
    return row === null ? null : await this.conflictFromRow(row);
  }
  async getState(robotId: string): Promise<TerminalLedgerState | null> {
    const row = await this.rows.getRow(
      "state",
      rowId("state", robotId),
      this.transactionId,
    );
    return row === null ? null : stateFromRow(row);
  }
  stageAccepted(row: TerminalLedgerRow): Promise<void> {
    return this.rows.createRow("ledger", ledgerToRow(row), this.transactionId);
  }
  stageChange(change: TerminalLedgerChange): Promise<void> {
    return this.rows.createRow(
      "changes",
      changeToRow(change),
      this.transactionId,
    );
  }
  stageState(state: TerminalLedgerState): Promise<void> {
    return this.rows.upsertRow("state", stateToRow(state), this.transactionId);
  }
  async stageConflict(conflict: TerminalLedgerConflict): Promise<void> {
    const accepted = await this.rows.getRow(
      "ledger",
      conflict.acceptedLedgerId,
      this.transactionId,
    );
    if (accepted === null)
      throw new Error("Accepted terminal ledger row is missing.");
    const parsed = ledgerFromRow(accepted);
    if (
      parsed.id !== conflict.acceptedLedgerId ||
      parsed.robotId !== conflict.robotId ||
      parsed.occurrenceId !== conflict.occurrenceId ||
      parsed.operationHash !== conflict.acceptedOperationHash
    ) throw new Error("Accepted terminal ledger row does not match conflict.");
    await this.rows.createRow(
      "terminalConflicts",
      conflictToRow(conflict, parsed),
      this.transactionId,
    );
  }
  private async one<T>(
    table: TerminalLedgerTable,
    queries: readonly string[],
    parse: (row: TerminalLedgerAppwriteRow) => T,
  ): Promise<T | null> {
    const rows = await this.rows.listRows(table, queries, this.transactionId);
    if (rows.length > 1) throw new Error("Duplicate terminal ledger rows.");
    return rows.length === 0 ? null : parse(rows[0]!);
  }
  private async conflictFromRow(
    row: TerminalLedgerAppwriteRow,
  ): Promise<TerminalLedgerConflict> {
    const robotId = requiredString(row, "robotId");
    const occurrenceId = requiredString(row, "occurrenceId");
    const accepted = await this.one(
      "ledger",
      [Query.equal("robotId", [robotId]), Query.equal("occurrenceId", [occurrenceId])],
      ledgerFromRow,
    );
    if (accepted === null)
      throw new Error("Accepted terminal ledger row is missing.");
    return conflictFromRow(row, accepted);
  }
}

function ledgerToRow(row: TerminalLedgerRow): TerminalLedgerAppwriteRow {
  const { id, ...data } = row;
  return { $id: id, ...data, acceptedAt: timestamp(row.acceptedAt) };
}
function ledgerFromRow(row: TerminalLedgerAppwriteRow): TerminalLedgerRow {
  return {
    id: row.$id,
    robotId: requiredString(row, "robotId"),
    occurrenceId: requiredString(row, "occurrenceId"),
    eventId: requiredString(row, "eventId"),
    idempotencyKey: requiredString(row, "idempotencyKey"),
    operationHash: requiredString(row, "operationHash"),
    canonicalMutation: requiredString(row, "canonicalMutation"),
    kind: enumValue(row, "kind", ["taken_confirmed", "skipped"]),
    actorAccountId: requiredString(row, "actorAccountId"),
    deviceId: requiredString(row, "deviceId"),
    sequence: positiveInteger(row, "sequence"),
    acceptedAt: timestamp(requiredString(row, "acceptedAt")),
  };
}
function changeToRow(row: TerminalLedgerChange): TerminalLedgerAppwriteRow {
  return {
    $id: rowId("change", row.robotId, String(row.sequence)),
    ...row,
    changedAt: timestamp(row.changedAt),
  };
}
function stateToRow(row: TerminalLedgerState): TerminalLedgerAppwriteRow {
  if (!Number.isSafeInteger(row.highWatermark) || row.highWatermark < 0)
    throw new Error("Invalid terminal ledger state high watermark.");
  return {
    $id: rowId("state", row.robotId),
    ...row,
    updatedAt: timestamp(row.updatedAt),
  };
}
function stateFromRow(row: TerminalLedgerAppwriteRow): TerminalLedgerState {
  return {
    robotId: requiredString(row, "robotId"),
    highWatermark: nonnegativeInteger(row, "highWatermark"),
    updatedAt: timestamp(requiredString(row, "updatedAt")),
  };
}
function conflictToRow(
  row: TerminalLedgerConflict,
  accepted: TerminalLedgerRow,
): TerminalLedgerAppwriteRow {
  return {
    $id: row.id,
    robotId: row.robotId,
    occurrenceId: row.occurrenceId,
    conflictCode: codeToStorage(row.code),
    acceptedEventId: accepted.eventId,
    acceptedOperationHash: accepted.operationHash,
    acceptedKind: accepted.kind,
    acceptedSequence: accepted.sequence,
    incomingEventId: row.eventId,
    incomingOperationHash: row.incomingOperationHash,
    incomingKind: row.kind,
    incomingIdempotencyKey: row.idempotencyKey,
    incomingDeviceId: row.deviceId,
    incomingActorAccountId: row.actorAccountId,
    incomingPayload: row.canonicalMutation,
    incomingOccurredAt: timestamp(row.occurredAt),
    recordedAt: timestamp(row.recordedAt),
  };
}
function conflictFromRow(
  row: TerminalLedgerAppwriteRow,
  accepted: TerminalLedgerRow,
): TerminalLedgerConflict {
  const code = enumValue(row, "conflictCode", [
    "TERMINAL_OUTCOME_REPLAY_MISMATCH",
    "TERMINAL_OUTCOME_CONFLICT",
  ]);
  const robotId = requiredString(row, "robotId");
  const occurrenceId = requiredString(row, "occurrenceId");
  const acceptedEventId = requiredString(row, "acceptedEventId");
  const acceptedOperationHash = requiredString(row, "acceptedOperationHash");
  const acceptedKind = enumValue(row, "acceptedKind", ["taken_confirmed", "skipped"]);
  const acceptedSequence = positiveInteger(row, "acceptedSequence");
  if (
    accepted.robotId !== robotId || accepted.occurrenceId !== occurrenceId ||
    accepted.eventId !== acceptedEventId || accepted.operationHash !== acceptedOperationHash ||
    accepted.kind !== acceptedKind || accepted.sequence !== acceptedSequence
  ) throw new Error("Stored terminal conflict does not match accepted ledger.");
  return {
    id: row.$id,
    robotId,
    occurrenceId,
    acceptedLedgerId: accepted.id,
    acceptedOperationHash,
    incomingOperationHash: requiredString(row, "incomingOperationHash"),
    canonicalMutation: requiredString(row, "incomingPayload"),
    eventId: requiredString(row, "incomingEventId"),
    idempotencyKey: requiredString(row, "incomingIdempotencyKey"),
    deviceId: requiredString(row, "incomingDeviceId"),
    actorAccountId: requiredString(row, "incomingActorAccountId"),
    kind: enumValue(row, "incomingKind", ["taken_confirmed", "skipped"]),
    occurredAt: timestamp(requiredString(row, "incomingOccurredAt")),
    code:
      code === "TERMINAL_OUTCOME_CONFLICT"
        ? "terminal_outcome_conflict"
        : "terminal_outcome_replay_mismatch",
    recordedAt: timestamp(requiredString(row, "recordedAt")),
  };
}
function requiredString(row: TerminalLedgerAppwriteRow, key: string): string {
  const value = row[key];
  if (typeof value !== "string" || value.length === 0)
    throw new Error(`Invalid terminal ledger row field: ${key}.`);
  return value;
}
function nonnegativeInteger(
  row: TerminalLedgerAppwriteRow,
  key: string,
): number {
  const value = row[key];
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0)
    throw new Error(`Invalid terminal ledger row field: ${key}.`);
  return value;
}
function positiveInteger(row: TerminalLedgerAppwriteRow, key: string): number {
  const value = nonnegativeInteger(row, key);
  if (value === 0)
    throw new Error(`Invalid terminal ledger row field: ${key}.`);
  return value;
}
function enumValue<const T extends string>(
  row: TerminalLedgerAppwriteRow,
  key: string,
  values: readonly T[],
): T {
  const value = requiredString(row, key);
  if (!values.includes(value as T))
    throw new Error(`Invalid terminal ledger row field: ${key}.`);
  return value as T;
}
function timestamp(value: string): string {
  const date = new Date(value);
  if (!Number.isFinite(date.getTime()) || date.toISOString() !== value)
    throw new Error("Invalid terminal ledger timestamp.");
  return date.toISOString();
}
function codeToStorage(
  code: TerminalLedgerConflict["code"],
): "TERMINAL_OUTCOME_CONFLICT" | "TERMINAL_OUTCOME_REPLAY_MISMATCH" {
  return code === "terminal_outcome_conflict"
    ? "TERMINAL_OUTCOME_CONFLICT"
    : "TERMINAL_OUTCOME_REPLAY_MISMATCH";
}
function rowId(...parts: string[]): string {
  return createHash("sha256")
    .update(parts.join("\u0000"))
    .digest("hex")
    .slice(0, 36);
}
function withoutId(row: TerminalLedgerAppwriteRow): Record<string, unknown> {
  const { $id: _, ...data } = row;
  return data;
}
function fromRow(row: Models.Row): TerminalLedgerAppwriteRow {
  return { ...row, $id: row.$id };
}
function isNotFound(error: unknown): boolean {
  return (
    error instanceof AppwriteException &&
    error.code === 404 &&
    error.type === "row_not_found"
  );
}
function isConflict(error: unknown): boolean {
  return (
    error instanceof AppwriteException &&
    error.code === 409 &&
    (error.type === "transaction_conflict" ||
      error.type === "row_update_conflict")
  );
}
function isStatus(value: string): value is TransactionStatus {
  return (
    value === "pending" ||
    value === "committing" ||
    value === "committed" ||
    value === "rolled_back" ||
    value === "failed"
  );
}
function retryDelay(attempt: number, random: () => number): number {
  const base = 10 * 2 ** (attempt - 1);
  return base + Math.floor(Math.max(0, Math.min(1, random())) * (base + 1));
}
function defaultDelay(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
