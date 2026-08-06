import assert from "node:assert/strict";
import { test } from "node:test";

import {
  AppwriteTerminalLedgerRowsApi,
  AppwriteTerminalLedgerPersistence,
  type TerminalLedgerRowsApi,
} from "../src/infrastructure/appwrite-terminal-ledger.js";
import { AppwriteException, Query } from "node-appwrite";

test("commits a completed callback only after a committed transaction status", async () => {
  const rows = new FakeRows();
  const persistence = new AppwriteTerminalLedgerPersistence(rows);
  assert.deepEqual(await persistence.transaction(async () => "saved"), {
    outcome: "committed",
    value: "saved",
  });
  assert.deepEqual(rows.calls, ["begin", "commit:tx-1", "status:tx-1"]);
});

test("resolves a lost commit response from the authoritative transaction status without replaying", async () => {
  for (const status of [
    "committed",
    "failed",
    "pending",
    "committing",
  ] as const) {
    const rows = new FakeRows();
    rows.status = status;
    rows.commitError = new Error("response lost");
    const result = await new AppwriteTerminalLedgerPersistence(
      rows,
    ).transaction(async () => "saved");
    if (status === "committed")
      assert.deepEqual(result, { outcome: "committed", value: "saved" });
    else if (status === "failed") assert.equal(result.outcome, "not_committed");
    else
      assert.deepEqual(result, {
        outcome: "indeterminate",
        transactionId: "tx-1",
        observedStatus: status,
        error: rows.commitError,
      });
    assert.equal(rows.calls.filter((call) => call === "commit:tx-1").length, 1);
  }
});

test("returns indeterminate when transaction status is unavailable after commit ambiguity", async () => {
  const rows = new FakeRows();
  rows.commitError = new Error("lost");
  rows.statusError = new Error("status unavailable");
  const result = await new AppwriteTerminalLedgerPersistence(rows).transaction(
    async () => "saved",
  );
  assert.deepEqual(result, {
    outcome: "indeterminate",
    transactionId: "tx-1",
    error: rows.commitError,
  });
});

test("rolls back callback failures and reports rollback failure without hiding the original result", async () => {
  const rows = new FakeRows();
  rows.rollbackError = new Error("rollback failed");
  const reported: unknown[] = [];
  const result = await new AppwriteTerminalLedgerPersistence(rows, (error) =>
    reported.push(error),
  ).transaction(async () => {
    throw new Error("stage failed");
  });
  assert.equal(result.outcome, "not_committed");
  assert.deepEqual(rows.calls, ["begin", "rollback:tx-1"]);
  assert.deepEqual(reported, [rows.rollbackError]);
});

test("reconstructs a stored conflict accepted ledger from its robot and occurrence", async () => {
  const rows = new FakeRows();
  rows.row = {
    $id: "conflict-1", robotId: "robot-1", occurrenceId: "occurrence-1",
    conflictCode: "TERMINAL_OUTCOME_CONFLICT", acceptedEventId: "event-1",
    acceptedOperationHash: "a".repeat(64), acceptedKind: "taken_confirmed",
    acceptedSequence: 1, incomingEventId: "event-2", incomingOperationHash: "b".repeat(64),
    incomingKind: "skipped", incomingIdempotencyKey: "key-2", incomingDeviceId: "device-2",
    incomingActorAccountId: "account-2", incomingPayload: "{}",
    incomingOccurredAt: "2026-08-01T08:00:00.000Z", recordedAt: "2026-08-01T08:01:00.000Z",
  };
  rows.listedRows = [{
    $id: "ledger-1", robotId: "robot-1", occurrenceId: "occurrence-1", eventId: "event-1",
    idempotencyKey: "key-1", operationHash: "a".repeat(64), canonicalMutation: "{}",
    kind: "taken_confirmed", actorAccountId: "account-1", deviceId: "device-1", sequence: 1,
    acceptedAt: "2026-08-01T08:00:00.000Z",
  }];
  const result = await new AppwriteTerminalLedgerPersistence(rows).transaction(async (transaction) => transaction.getConflict("conflict-1"));
  if (result.outcome !== "committed") throw result.error;
  if (result.outcome === "committed") assert.equal(result.value?.acceptedLedgerId, "ledger-1");
  assert.equal(rows.listCalls, 1);
});

test("returns failed without rollback when beginning the transaction fails", async () => {
  const rows = new FakeRows();
  rows.beginError = new Error("begin failed");
  const result = await new AppwriteTerminalLedgerPersistence(rows).transaction(async () => "never");
  assert.deepEqual(result, {outcome: "not_committed", status: "failed", error: rows.beginError});
  assert.deepEqual(rows.calls, ["begin"]);
});

test("routes every raw Appwrite row operation with its transaction and physical table", async () => {
  const tables = new TablesBoundary();
  const rows = new AppwriteTerminalLedgerRowsApi(tables as never, configuration);
  assert.equal(await rows.beginTransaction(), "tx-1");
  await rows.commitTransaction("tx-1"); await rows.rollbackTransaction("tx-1");
  assert.equal(await rows.getTransaction("tx-1"), "committed");
  await rows.getRow("ledger", "ledger-1", "tx-1");
  await rows.listRows("changes", [Query.equal("robotId", ["robot-1"])], "tx-1");
  await rows.createRow("terminalConflicts", {$id: "conflict-1", value: "x"}, "tx-1");
  await rows.upsertRow("state", {$id: "state-1", value: "x"}, "tx-1");
  assert.deepEqual(tables.calls, [
    ["begin"], ["update", {transactionId: "tx-1", commit: true}], ["update", {transactionId: "tx-1", rollback: true}],
    ["status", {transactionId: "tx-1"}], ["get", {databaseId: "db", tableId: "ledger", rowId: "ledger-1", transactionId: "tx-1"}],
    ["list", "db", "changes", "tx-1"], ["create", {databaseId: "db", tableId: "conflicts", rowId: "conflict-1", data: {value: "x"}, transactionId: "tx-1"}],
    ["upsert", {databaseId: "db", tableId: "state", rowId: "state-1", data: {value: "x"}, transactionId: "tx-1"}],
  ]);
  assert.equal(tables.listQueries.at(-1), Query.limit(2));
});

test("maps only exact row_not_found to null and rejects unknown transaction statuses", async () => {
  const tables = new TablesBoundary(); const rows = new AppwriteTerminalLedgerRowsApi(tables as never, configuration);
  tables.getError = new AppwriteException("missing", 404, "row_not_found");
  assert.equal(await rows.getRow("ledger", "x", "tx-1"), null);
  tables.getError = new AppwriteException("other", 404, "table_not_found");
  await assert.rejects(() => rows.getRow("ledger", "x", "tx-1"));
  tables.status = "mystery";
  await assert.rejects(() => rows.getTransaction("tx-1"));
});

test("retries classified callback conflicts with a fresh transaction and stops at its bound", async () => {
  const rows = new RetryRows(); let callbacks = 0;
  const result = await new AppwriteTerminalLedgerPersistence(rows, () => {}, 2, async () => {}, () => 0)
    .transaction(async () => { callbacks += 1; throw new AppwriteException("conflict", 409, "transaction_conflict"); });
  assert.equal(result.outcome, "not_committed");
  assert.equal(callbacks, 2);
  assert.deepEqual(rows.calls, ["begin:tx-1", "rollback:tx-1", "begin:tx-2", "rollback:tx-2"]);
});

test("retries each classified callback conflict through a fresh transaction and reports rollback failure", async () => {
  for (const type of ["transaction_conflict", "row_update_conflict"] as const) {
    const rows = new ScriptedRows(); rows.rollbackError = new Error("rollback"); const reports: unknown[] = []; let callbacks = 0; let delays = 0;
    const value = await new AppwriteTerminalLedgerPersistence(rows, error => reports.push(error), 3, async () => { delays += 1; }, () => 0)
      .transaction(async () => { callbacks += 1; if (callbacks === 1) throw new AppwriteException("conflict", 409, type); return "saved"; });
    assert.deepEqual(value, {outcome: "committed", value: "saved"});
    assert.equal(callbacks, 2); assert.equal(delays, 1); assert.deepEqual(reports, [rows.rollbackError]);
    assert.deepEqual(rows.calls, ["begin:tx-1", "rollback:tx-1", "begin:tx-2", "commit:tx-2", "status:tx-2"]);
  }
});

test("does not retry non-classified callback errors", async () => {
  for (const error of [new AppwriteException("other", 409, "unique_conflict"), new Error("ordinary")]) {
    const rows = new ScriptedRows(); let callbacks = 0; let delays = 0;
    const value = await new AppwriteTerminalLedgerPersistence(rows, () => {}, 3, async () => { delays += 1; })
      .transaction(async () => { callbacks += 1; throw error; });
    assert.equal(value.outcome, "not_committed"); assert.equal(callbacks, 1); assert.equal(delays, 0);
    assert.deepEqual(rows.calls, ["begin:tx-1", "rollback:tx-1"]);
  }
});

test("retries commit conflicts only after definitive failed or rolled back status", async () => {
  for (const [type, status] of [["transaction_conflict", "failed"], ["row_update_conflict", "rolled_back"]] as const) {
    const rows = new ScriptedRows(); rows.commitErrors = [new AppwriteException("conflict", 409, type)]; rows.statuses = [status, "committed"]; let callbacks = 0; let delays = 0;
    const value = await new AppwriteTerminalLedgerPersistence(rows, () => {}, 2, async () => { delays += 1; }, () => 0)
      .transaction(async () => `value-${++callbacks}`);
    assert.deepEqual(value, {outcome: "committed", value: "value-2"}); assert.equal(delays, 1);
    assert.deepEqual(rows.calls, ["begin:tx-1", "commit:tx-1", "status:tx-1", "begin:tx-2", "commit:tx-2", "status:tx-2"]);
  }
});

test("never replays ambiguous or non-conflict lost commits", async () => {
  for (const status of ["committed", "failed", "rolled_back", "pending", "committing", "unavailable"] as const) {
    const rows = new ScriptedRows(); rows.commitErrors = [new Error("lost")]; if (status === "unavailable") rows.statusError = new Error("unavailable"); else rows.statuses = [status]; let callbacks = 0;
    const value = await new AppwriteTerminalLedgerPersistence(rows, () => {}, 3, async () => { throw new Error("replayed"); })
      .transaction(async () => `value-${++callbacks}`);
    assert.equal(callbacks, 1); assert.deepEqual(rows.calls, ["begin:tx-1", "commit:tx-1", "status:tx-1"]);
    if (status === "committed") assert.deepEqual(value, {outcome: "committed", value: "value-1"});
    else if (status === "failed" || status === "rolled_back") assert.equal(value.outcome, "not_committed");
    else assert.equal(value.outcome, "indeterminate");
  }
});

test("returns indeterminate when commit succeeds but status cannot be read", async () => {
  const rows = new ScriptedRows();
  rows.statusError = new Error("status unavailable");
  let callbacks = 0;
  const value = await new AppwriteTerminalLedgerPersistence(rows).transaction(
    async () => `value-${++callbacks}`,
  );
  assert.deepEqual(value, {
    outcome: "indeterminate",
    transactionId: "tx-1",
    error: rows.statusError,
  });
  assert.equal(callbacks, 1);
  assert.deepEqual(rows.calls, ["begin:tx-1", "commit:tx-1", "status:tx-1"]);
});

test("stages accepted ledger rows through the active transaction", async () => {
  const rows = new LedgerRows();
  const result = await new AppwriteTerminalLedgerPersistence(rows).transaction(
    async (transaction) => transaction.stageAccepted(acceptedLedger()),
  );
  assert.equal(result.outcome, "committed");
  assert.deepEqual(rows.operations, [{
    kind: "create",
    table: "ledger",
    row: expectedAcceptedRow(),
    transactionId: "tx-1",
  }]);
});

const acceptedLedger = () => ({
  id: "ledger-1",
  robotId: "robot-1",
  occurrenceId: "occurrence-1",
  eventId: "event-1",
  idempotencyKey: "key-1",
  operationHash: "a".repeat(64),
  canonicalMutation: "{}",
  kind: "taken_confirmed",
  actorAccountId: "account-1",
  deviceId: "device-1",
  sequence: 1,
  acceptedAt: "2026-08-01T08:00:00.000Z",
});

const expectedAcceptedRow = () => ({
  $id: "ledger-1",
  robotId: "robot-1",
  occurrenceId: "occurrence-1",
  eventId: "event-1",
  idempotencyKey: "key-1",
  operationHash: "a".repeat(64),
  canonicalMutation: "{}",
  kind: "taken_confirmed",
  actorAccountId: "account-1",
  deviceId: "device-1",
  sequence: 1,
  acceptedAt: "2026-08-01T08:00:00.000Z",
});

test("maps accepted lookup queries, nulls, duplicates, and malformed rows", async () => {
  const rows = new LedgerRows();
  rows.listQueue = [[expectedAcceptedRow()], [expectedAcceptedRow()], [expectedAcceptedRow()]];
  const value = await committed(rows, async (transaction) => [
    await transaction.getAcceptedOccurrence("robot-1", "occurrence-1"),
    await transaction.getIdempotency("robot-1", "key-1"),
    await transaction.getEvent("robot-1", "event-1"),
  ]);
  assert.deepEqual(value, [acceptedLedger(), acceptedLedger(), acceptedLedger()]);
  assert.deepEqual(rows.operations.map(({table, queries, transactionId}) => ({table, queries, transactionId})), [
    {table: "ledger", queries: [Query.equal("robotId", ["robot-1"]), Query.equal("occurrenceId", ["occurrence-1"])], transactionId: "tx-1"},
    {table: "ledger", queries: [Query.equal("robotId", ["robot-1"]), Query.equal("idempotencyKey", ["key-1"])], transactionId: "tx-1"},
    {table: "ledger", queries: [Query.equal("robotId", ["robot-1"]), Query.equal("eventId", ["event-1"])], transactionId: "tx-1"},
  ]);

  for (const rowsForLookup of [[], [expectedAcceptedRow(), expectedAcceptedRow()]]) {
    const lookupRows = new LedgerRows(); lookupRows.listQueue = [rowsForLookup];
    const result = await new AppwriteTerminalLedgerPersistence(lookupRows).transaction((transaction) => transaction.getEvent("robot-1", "event-1"));
    if (rowsForLookup.length === 0) assert.deepEqual(result, {outcome: "committed", value: null});
    else assert.equal(result.outcome, "not_committed");
  }

  for (const [field, value] of [
    ["eventId", ""], ["kind", "unknown"], ["acceptedAt", "2026-08-01T08:00:00Z"],
    ["acceptedAt", "invalid"], ["sequence", 0], ["sequence", 1.5],
    ["sequence", Number.MAX_SAFE_INTEGER + 1],
  ] as const) {
    const malformed = {...expectedAcceptedRow(), [field]: value};
    const malformedRows = new LedgerRows(); malformedRows.listQueue = [[malformed]];
    const result = await new AppwriteTerminalLedgerPersistence(malformedRows).transaction((transaction) => transaction.getEvent("robot-1", "event-1"));
    assert.equal(result.outcome, "not_committed", `${field}=${value}`);
  }
});

test("maps changes and state rows through the active transaction", async () => {
  const rows = new LedgerRows();
  const change = changeRow(); const state = stateRow();
  const value = await committed(rows, async (transaction) => {
    await transaction.stageChange(change);
    const missing = await transaction.getState("robot-1");
    rows.row = {...state, $id: rows.operations[1]!.id};
    const found = await transaction.getState("robot-1");
    await transaction.stageState(state);
    return {missing, found};
  });
  assert.deepEqual(value, {missing: null, found: state});
  const [created, missing, found, upserted] = rows.operations;
  assert.equal(created!.kind, "create"); assert.equal(created!.table, "changes");
  assert.equal((created!.row!.$id as string).length, 36);
  assert.deepEqual(created!.row, {...change, $id: created!.row!.$id, changedAt: "2026-08-01T08:02:00.000Z"});
  const repeatRows = new LedgerRows();
  await committed(repeatRows, (transaction) => transaction.stageChange(change));
  assert.equal(repeatRows.operations[0]!.row!.$id, created!.row!.$id);
  assert.equal(missing!.id, found!.id); assert.equal(missing!.id!.length, 36);
  assert.equal(upserted!.kind, "upsert"); assert.equal(upserted!.table, "state");
  assert.deepEqual(upserted!.row, {...state, $id: missing!.id, updatedAt: "2026-08-01T08:03:00.000Z"});
  assert.ok(rows.operations.every((operation) => operation.transactionId === "tx-1"));

  for (const invalid of [
    {...state, highWatermark: -1}, {...state, highWatermark: 1.5},
    {...state, highWatermark: Number.MAX_SAFE_INTEGER + 1},
    {...state, updatedAt: "2026-08-01T08:03:00Z"}, {...state, updatedAt: "invalid"},
  ]) {
    const invalidRows = new LedgerRows(); invalidRows.row = {...invalid, $id: "state"};
    const result = await new AppwriteTerminalLedgerPersistence(invalidRows).transaction((transaction) => transaction.getState("robot-1"));
    assert.equal(result.outcome, "not_committed");
  }
});

test("rejects invalid state values before staging", async () => {
  const state = stateRow();
  for (const invalid of [
    {...state, highWatermark: -1}, {...state, highWatermark: 1.5},
    {...state, highWatermark: Number.MAX_SAFE_INTEGER + 1},
    {...state, updatedAt: "2026-08-01T08:03:00Z"}, {...state, updatedAt: "invalid"},
  ]) {
    const rows = new LedgerRows();
    const result = await new AppwriteTerminalLedgerPersistence(rows).transaction((transaction) => transaction.stageState(invalid));
    assert.equal(result.outcome, "not_committed");
    assert.equal(rows.operations.length, 0);
  }
});

test("serializes and reconstructs coherent conflicts through accepted ledger evidence", async () => {
  const rows = new LedgerRows(); rows.row = expectedAcceptedRow();
  const conflict = conflictRow();
  await committed(rows, (transaction) => transaction.stageConflict(conflict));
  const created = rows.operations.at(-1)!;
  assert.deepEqual(created, {kind: "create", table: "terminalConflicts", transactionId: "tx-1", row: expectedConflictRow()});
  const replayRows = new LedgerRows(); replayRows.row = expectedAcceptedRow();
  await committed(replayRows, (transaction) => transaction.stageConflict({...conflict, id: "conflict-2", code: "terminal_outcome_replay_mismatch"}));
  assert.equal(replayRows.operations.at(-1)!.row!.conflictCode, "TERMINAL_OUTCOME_REPLAY_MISMATCH");

  const readRows = new LedgerRows(); readRows.row = expectedConflictRow(); readRows.listQueue = [[expectedAcceptedRow()]];
  const value = await committed(readRows, (transaction) => transaction.getConflict("conflict-1"));
  assert.deepEqual(value, conflict);
  assert.deepEqual(readRows.operations.map(({kind, table, transactionId}) => ({kind, table, transactionId})), [
    {kind: "get", table: "terminalConflicts", transactionId: "tx-1"},
    {kind: "list", table: "ledger", transactionId: "tx-1"},
  ]);
  assert.deepEqual(readRows.operations[1]!.queries, [Query.equal("robotId", ["robot-1"]), Query.equal("occurrenceId", ["occurrence-1"])]);
});

test("rejects incoherent staged and stored conflicts", async () => {
  for (const accepted of [
    null, {...expectedAcceptedRow(), $id: "wrong"}, {...expectedAcceptedRow(), robotId: "wrong"},
    {...expectedAcceptedRow(), occurrenceId: "wrong"}, {...expectedAcceptedRow(), operationHash: "b".repeat(64)},
  ]) {
    const rows = new LedgerRows(); rows.row = accepted;
    const result = await new AppwriteTerminalLedgerPersistence(rows).transaction((transaction) => transaction.stageConflict(conflictRow()));
    assert.equal(result.outcome, "not_committed"); assert.equal(rows.operations.filter(({kind}) => kind === "create").length, 0);
  }
  for (const row of [
    {...expectedConflictRow(), conflictCode: "UNKNOWN"},
    {...expectedConflictRow(), incomingOccurredAt: "2026-08-01T08:04:00Z"},
    {...expectedConflictRow(), incomingOccurredAt: "invalid"},
    {...expectedConflictRow(), recordedAt: "2026-08-01T08:05:00Z"},
    {...expectedConflictRow(), recordedAt: "invalid"}, {...expectedConflictRow(), incomingEventId: ""},
  ]) {
    const rows = new LedgerRows(); rows.row = row; rows.listQueue = [[expectedAcceptedRow()]];
    const result = await new AppwriteTerminalLedgerPersistence(rows).transaction((transaction) => transaction.getConflict("conflict-1"));
    assert.equal(result.outcome, "not_committed");
  }
  for (const accepted of [null, [expectedAcceptedRow(), expectedAcceptedRow()],
    [{...expectedAcceptedRow(), eventId: "wrong"}], [{...expectedAcceptedRow(), operationHash: "b".repeat(64)}],
    [{...expectedAcceptedRow(), kind: "skipped"}], [{...expectedAcceptedRow(), sequence: 2}],
  ]) {
    const rows = new LedgerRows(); rows.row = expectedConflictRow(); rows.listQueue = [accepted === null ? [] : accepted];
    const result = await new AppwriteTerminalLedgerPersistence(rows).transaction((transaction) => transaction.getConflict("conflict-1"));
    assert.equal(result.outcome, "not_committed");
  }
});

const changeRow = () => ({robotId: "robot-1", sequence: 1, resourceType: "doseEvent" as const, resourceId: "event-1", resourceVersion: null, operation: "event" as const, payload: "{}", actorAccountId: "account-1", actorRole: "device" as const, changedAt: "2026-08-01T08:02:00.000Z", idempotencyKey: "key-1", operationHash: "a".repeat(64)});
const stateRow = () => ({robotId: "robot-1", highWatermark: 1, updatedAt: "2026-08-01T08:03:00.000Z"});
const conflictRow = () => ({id: "conflict-1", robotId: "robot-1", occurrenceId: "occurrence-1", acceptedLedgerId: "ledger-1", acceptedOperationHash: "a".repeat(64), incomingOperationHash: "b".repeat(64), canonicalMutation: "{}", eventId: "event-2", idempotencyKey: "key-2", deviceId: "device-2", actorAccountId: "account-2", kind: "skipped" as const, occurredAt: "2026-08-01T08:04:00.000Z", code: "terminal_outcome_conflict" as const, recordedAt: "2026-08-01T08:05:00.000Z"});
const expectedConflictRow = () => ({$id: "conflict-1", robotId: "robot-1", occurrenceId: "occurrence-1", conflictCode: "TERMINAL_OUTCOME_CONFLICT", acceptedEventId: "event-1", acceptedOperationHash: "a".repeat(64), acceptedKind: "taken_confirmed", acceptedSequence: 1, incomingEventId: "event-2", incomingOperationHash: "b".repeat(64), incomingKind: "skipped", incomingIdempotencyKey: "key-2", incomingDeviceId: "device-2", incomingActorAccountId: "account-2", incomingPayload: "{}", incomingOccurredAt: "2026-08-01T08:04:00.000Z", recordedAt: "2026-08-01T08:05:00.000Z"});

async function committed<T>(rows: LedgerRows, callback: (transaction: any) => Promise<T>) {
  const result = await new AppwriteTerminalLedgerPersistence(rows).transaction(callback);
  assert.equal(result.outcome, "committed");
  return result.value;
}

class FakeRows implements TerminalLedgerRowsApi {
  calls: string[] = [];
  status: "pending" | "committing" | "committed" | "rolled_back" | "failed" =
    "committed";
  commitError: Error | undefined;
  rollbackError: Error | undefined;
  statusError: Error | undefined;
  beginError: Error | undefined;
  row: any = null;
  listedRows: any[] = [];
  listCalls = 0;
  async beginTransaction() {
    this.calls.push("begin");
    if (this.beginError) throw this.beginError;
    return "tx-1";
  }
  async commitTransaction(id: string) {
    this.calls.push(`commit:${id}`);
    if (this.commitError) throw this.commitError;
  }
  async rollbackTransaction(id: string) {
    this.calls.push(`rollback:${id}`);
    if (this.rollbackError) throw this.rollbackError;
  }
  async getTransaction(id: string) {
    this.calls.push(`status:${id}`);
    if (this.statusError) throw this.statusError;
    return this.status;
  }
  async getRow() {
    return this.row;
  }
  async listRows() {
    this.listCalls += 1;
    return this.listedRows;
  }
  async createRow() {}
  async upsertRow() {}
}

class LedgerRows extends FakeRows {
  listQueue: any[][] = [];
  operations: Array<{
    kind: "get" | "list" | "create" | "upsert";
    table: string;
    row?: Record<string, unknown>;
    queries?: string[];
    id?: string;
    transactionId: string;
  }> = [];

  override async getRow(table: string, id: string, transactionId: string) {
    this.operations.push({kind: "get", table, id, transactionId});
    return this.row;
  }
  override async listRows(table: string, queries: string[], transactionId: string) {
    this.operations.push({kind: "list", table, queries, transactionId});
    return this.listQueue.shift() ?? this.listedRows;
  }
  override async createRow(table: string, row: Record<string, unknown>, transactionId: string) {
    this.operations.push({kind: "create", table, row, transactionId});
  }
  override async upsertRow(table: string, row: Record<string, unknown>, transactionId: string) {
    this.operations.push({kind: "upsert", table, row, transactionId});
  }
}

const configuration = {databaseId: "db", terminalLedgerTableId: "ledger", changesTableId: "changes", stateTableId: "state", terminalConflictsTableId: "conflicts"};
class TablesBoundary {
  calls: unknown[] = []; listQueries: string[] = []; status = "committed"; getError: Error | undefined;
  async createTransaction() { this.calls.push(["begin"]); return {$id: "tx-1"}; }
  async updateTransaction(value: unknown) { this.calls.push(["update", value]); return {}; }
  async getTransaction(value: unknown) { this.calls.push(["status", value]); return {status: this.status}; }
  async getRow(value: any) { this.calls.push(["get", value]); if (this.getError) throw this.getError; return {$id: value.rowId}; }
  async listRows(value: any) { this.calls.push(["list", value.databaseId, value.tableId, value.transactionId]); this.listQueries = value.queries; return {rows: []}; }
  async createRow(value: unknown) { this.calls.push(["create", value]); return {}; }
  async upsertRow(value: unknown) { this.calls.push(["upsert", value]); return {}; }
}
class RetryRows extends FakeRows {
  next = 0;
  override async beginTransaction() { const id = `tx-${++this.next}`; this.calls.push(`begin:${id}`); return id; }
}
class ScriptedRows extends FakeRows {
  next = 0; commitErrors: Error[] = []; statuses: Array<"pending" | "committing" | "committed" | "rolled_back" | "failed"> = [];
  override async beginTransaction() { const id = `tx-${++this.next}`; this.calls.push(`begin:${id}`); return id; }
  override async commitTransaction(id: string) { this.calls.push(`commit:${id}`); const error = this.commitErrors.shift(); if (error) throw error; }
  override async getTransaction(id: string) { this.calls.push(`status:${id}`); if (this.statusError) throw this.statusError; return this.statuses.shift() ?? this.status; }
}
