import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

type Table = {
  $id: string;
  $permissions: string[];
  databaseId: string;
  enabled: boolean;
  rowSecurity: boolean;
  columns: Array<{
    key: string;
    type: string;
    required: boolean;
    array: boolean;
    default: null;
    size?: number;
    min?: number;
    max?: number;
    elements?: string[];
    format?: string;
  }>;
  indexes: Array<{ key: string; type: string; columns: string[]; orders?: string[] }>;
};

type FunctionDefinition = {
  $id: string;
  execute: string[];
  entrypoint: string;
  scopes: string[];
  vars: Array<{ key: string; value: string }>;
};

test('defines additive server-only sync tables and callable human function deployments', () => {
  const path = new URL('../appwrite.medication-sync.template.json', import.meta.url);
  const config = JSON.parse(readFileSync(path, 'utf8')) as {
    tables: Table[];
    functions: FunctionDefinition[];
  };
  const tables = new Map(config.tables.map((table) => [table.$id, table]));
  assert.deepEqual([...tables.keys()], [
    'dosey_sync_documents_v1',
    'dosey_sync_events_v1',
    'dosey_sync_help_requests_v1',
    'dosey_sync_receipts_v1',
    'dosey_sync_state_v1',
    'dosey_sync_changes_v1',
    'dosey_sync_terminal_occurrences_v1',
    'dosey_sync_terminal_conflicts_v1',
  ]);
  for (const table of tables.values()) {
    assert.deepEqual(table.$permissions, []);
    assert.equal(table.rowSecurity, false);
  }
  assert.deepEqual(
    tables.get('dosey_sync_documents_v1')?.columns.map(({ key }) => key),
    [
      'robotId', 'resourceType', 'resourceId', 'version', 'archived', 'payload',
      'createdAt', 'createdByAccountId', 'updatedAt', 'updatedByAccountId',
    ],
  );
  assertTerminalTable(tables.get('dosey_sync_terminal_occurrences_v1'), {
    columns: [
      varchar('robotId', 128),
      varchar('occurrenceId', 256),
      enumColumn('acceptedKind', 16, ['taken_confirmed', 'skipped', 'missed']),
      varchar('acceptedEventId', 128),
      varchar('acceptedOperationHash', 64),
      varchar('acceptedIdempotencyKey', 128),
      varchar('acceptedDeviceId', 128),
      varchar('acceptedActorAccountId', 128),
      bigint('acceptedSequence'),
      datetime('occurredAt'),
      datetime('acceptedAt'),
    ],
    indexes: [
      {key: 'robot_occurrence', type: 'unique', columns: ['robotId', 'occurrenceId'], orders: ['ASC', 'ASC']},
      {key: 'robot_accepted_sequence', type: 'key', columns: ['robotId', 'acceptedSequence'], orders: ['ASC', 'ASC']},
    ],
  });
  assertTerminalTable(tables.get('dosey_sync_terminal_conflicts_v1'), {
    columns: [
      varchar('robotId', 128),
      varchar('occurrenceId', 256),
      enumColumn('conflictCode', 40, ['TERMINAL_OUTCOME_REPLAY_MISMATCH', 'TERMINAL_OUTCOME_CONFLICT']),
      varchar('acceptedEventId', 128),
      varchar('acceptedOperationHash', 64),
      enumColumn('acceptedKind', 16, ['taken_confirmed', 'skipped', 'missed']),
      bigint('acceptedSequence'),
      varchar('incomingEventId', 128),
      varchar('incomingOperationHash', 64),
      enumColumn('incomingKind', 16, ['taken_confirmed', 'skipped', 'missed']),
      varchar('incomingIdempotencyKey', 128),
      varchar('incomingDeviceId', 128),
      varchar('incomingActorAccountId', 128),
      text('incomingPayload'),
      datetime('incomingOccurredAt'),
      datetime('recordedAt'),
    ],
    indexes: [
      {key: 'robot_incoming_hash', type: 'unique', columns: ['robotId', 'incomingOperationHash'], orders: ['ASC', 'ASC']},
      {key: 'robot_occurrence', type: 'key', columns: ['robotId', 'occurrenceId'], orders: ['ASC', 'ASC']},
    ],
  });
  assert.deepEqual(
    tables.get('dosey_sync_events_v1')?.columns.map(({ key }) => key),
    [
      'robotId', 'eventId', 'eventHash', 'kind', 'doseId', 'scheduleId', 'payload',
      'occurredAt', 'receivedAt', 'actorAccountId', 'sequence',
    ],
  );
  assert.deepEqual(
    tables.get('dosey_sync_receipts_v1')?.columns.map(({ key }) => key),
    ['robotId', 'idempotencyKey', 'operationHash', 'sequence', 'resourceVersion', 'createdAt'],
  );
  assert.deepEqual(
    tables.get('dosey_sync_changes_v1')?.indexes,
    [{
      key: 'robot_sequence', type: 'unique', columns: ['robotId', 'sequence'],
      orders: ['ASC', 'ASC'],
    }],
  );
  assert.deepEqual(
    tables.get('dosey_sync_changes_v1')?.columns.map(({ key }) => key),
    [
      'robotId', 'sequence', 'resourceType', 'resourceId', 'resourceVersion', 'operation',
      'payload', 'actorAccountId', 'actorRole', 'changedAt', 'idempotencyKey', 'operationHash',
    ],
  );
  assert.deepEqual(
    config.tables.find((table) => table.$id === 'dosey_sync_changes_v1')?.columns
      .find((column) => column.key === 'actorRole')?.elements,
    ['owner', 'member', 'device'],
  );

  assert.deepEqual(config.functions.map((definition) => ({
    id: definition.$id,
    execute: definition.execute,
    entrypoint: definition.entrypoint,
    scopes: definition.scopes,
  })), [
    {
      id: 'medication-sync-push-v1', execute: ['users'],
      entrypoint: 'dist/entrypoints/medication-sync-push.js',
      scopes: ['rows.read', 'rows.write'],
    },
    {
      id: 'medication-sync-pull-v1', execute: ['users'],
      entrypoint: 'dist/entrypoints/medication-sync-pull.js',
      scopes: ['rows.read', 'rows.write'],
    },
  ]);
  for (const definition of config.functions) {
    const variables = new Map(definition.vars.map(({ key, value }) => [key, value]));
    assert.equal(variables.get('DOSEY_DATABASE_ID'), '<DOSEY_DATABASE_ID>');
    assert.equal(variables.get('DOSEY_HUMAN_ROBOT_LINKS_TABLE_ID'), '<DOSEY_HUMAN_ROBOT_LINKS_TABLE_ID>');
    assert.equal(variables.get('DOSEY_MOUNTED_ROBOT_ACCESS_TABLE_ID'), '<DOSEY_MOUNTED_ROBOT_ACCESS_TABLE_ID>');
    assert.equal(variables.get('DOSEY_ROBOT_INSTALLATIONS_TABLE_ID'), '<DOSEY_ROBOT_INSTALLATIONS_TABLE_ID>');
    assert.equal(
      variables.get('DOSEY_MEDICATION_SYNC_CHANGES_TABLE_ID'),
      'dosey_sync_changes_v1',
    );
    assert.deepEqual([...variables.entries()], [
      ['DOSEY_DATABASE_ID', '<DOSEY_DATABASE_ID>'],
      ['DOSEY_HUMAN_ROBOT_LINKS_TABLE_ID', '<DOSEY_HUMAN_ROBOT_LINKS_TABLE_ID>'],
      ['DOSEY_MOUNTED_ROBOT_ACCESS_TABLE_ID', '<DOSEY_MOUNTED_ROBOT_ACCESS_TABLE_ID>'],
      ['DOSEY_ROBOT_INSTALLATIONS_TABLE_ID', '<DOSEY_ROBOT_INSTALLATIONS_TABLE_ID>'],
      ['DOSEY_MEDICATION_SYNC_DOCUMENTS_TABLE_ID', 'dosey_sync_documents_v1'],
      ['DOSEY_MEDICATION_SYNC_EVENTS_TABLE_ID', 'dosey_sync_events_v1'],
      ['DOSEY_MEDICATION_SYNC_HELP_REQUESTS_TABLE_ID', 'dosey_sync_help_requests_v1'],
      ['DOSEY_MEDICATION_SYNC_RECEIPTS_TABLE_ID', 'dosey_sync_receipts_v1'],
      ['DOSEY_MEDICATION_SYNC_STATE_TABLE_ID', 'dosey_sync_state_v1'],
      ['DOSEY_MEDICATION_SYNC_CHANGES_TABLE_ID', 'dosey_sync_changes_v1'],
      ['DOSEY_HUMAN_AUTH_PROVIDERS', 'google'],
    ]);
  }
});

function assertTerminalTable(table: Table | undefined, expected: {
  columns: Table['columns'];
  indexes: Table['indexes'];
}): void {
  assert.ok(table);
  assert.equal(table.databaseId, '<DOSEY_DATABASE_ID>');
  assert.equal(table.enabled, true);
  assert.deepEqual(table.$permissions, []);
  assert.equal(table.rowSecurity, false);
  assert.deepEqual(table.columns, expected.columns);
  assert.deepEqual(table.indexes, expected.indexes);
}

function varchar(key: string, size: number): Table['columns'][number] {
  return {key, type: 'varchar', size, required: true, array: false, default: null};
}

function enumColumn(key: string, size: number, elements: string[]): Table['columns'][number] {
  return {key, type: 'varchar', size, required: true, array: false, elements, format: 'enum', default: null};
}

function bigint(key: string): Table['columns'][number] {
  return {key, type: 'bigint', required: true, array: false, min: 1, max: 9007199254740991, default: null};
}

function datetime(key: string): Table['columns'][number] {
  return {key, type: 'datetime', required: true, array: false, format: '', default: null};
}

function text(key: string): Table['columns'][number] {
  return {key, type: 'text', required: true, array: false, default: null};
}
