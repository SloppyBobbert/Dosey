import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

type Table = {
  $id: string;
  $permissions: string[];
  columns: Array<{ key: string }>;
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
  ]);
  for (const table of tables.values()) assert.deepEqual(table.$permissions, []);
  assert.deepEqual(
    tables.get('dosey_sync_documents_v1')?.columns.map(({ key }) => key),
    [
      'robotId', 'resourceType', 'resourceId', 'version', 'archived', 'payload',
      'createdAt', 'createdByAccountId', 'updatedAt', 'updatedByAccountId',
    ],
  );
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
