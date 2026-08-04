import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import type { MedicationSyncRequestParser } from '../src/functions/medication-sync-handlers.js';
import {
  configuredHumanProviders,
  createMedicationSyncRuntime,
} from '../src/runtime/medication-sync-runtime.js';

const environment = {
  APPWRITE_FUNCTION_API_ENDPOINT: 'https://cloud.example/v1',
  APPWRITE_FUNCTION_PROJECT_ID: 'project-1',
  DOSEY_DATABASE_ID: 'database-1',
  DOSEY_HUMAN_ROBOT_LINKS_TABLE_ID: 'links',
  DOSEY_MOUNTED_ROBOT_ACCESS_TABLE_ID: 'mounted-access',
  DOSEY_ROBOT_INSTALLATIONS_TABLE_ID: 'robot-installations',
  DOSEY_MEDICATION_SYNC_DOCUMENTS_TABLE_ID: 'sync-documents',
  DOSEY_MEDICATION_SYNC_EVENTS_TABLE_ID: 'sync-events',
  DOSEY_MEDICATION_SYNC_HELP_REQUESTS_TABLE_ID: 'sync-help-requests',
  DOSEY_MEDICATION_SYNC_RECEIPTS_TABLE_ID: 'sync-receipts',
  DOSEY_MEDICATION_SYNC_STATE_TABLE_ID: 'sync-state',
  DOSEY_MEDICATION_SYNC_CHANGES_TABLE_ID: 'sync-changes',
  DOSEY_MEDICATION_SYNC_TERMINAL_OCCURRENCES_TABLE_ID: 'sync-terminal-occurrences',
  DOSEY_MEDICATION_SYNC_TERMINAL_CONFLICTS_TABLE_ID: 'sync-terminal-conflicts',
};

const parser: MedicationSyncRequestParser = {
  parsePush: () => ({ ok: true, value: { robotId: 'robot-1', operations: [] } }),
  parsePull: () => ({ ok: true, value: { robotId: 'robot-1', cursor: 0, limit: 50 } }),
};

describe('Medication sync runtime', () => {
  test('constructs push and pull dependencies from environment-only table IDs', () => {
    const runtime = createMedicationSyncRuntime(
      { 'x-appwrite-key': 'dynamic-key', 'x-appwrite-user-jwt': 'user-jwt' },
      parser,
      environment,
    );

    assert.ok(runtime.identity);
    assert.ok(runtime.push);
    assert.ok(runtime.pull);
    assert.equal(runtime.parser, parser);
  });

  test('requires every medication sync table ID', () => {
    for (const key of [
      'DOSEY_MEDICATION_SYNC_TERMINAL_OCCURRENCES_TABLE_ID',
      'DOSEY_MEDICATION_SYNC_TERMINAL_CONFLICTS_TABLE_ID',
    ] as const) {
      const { [key]: _, ...missing } = environment;
      assert.throws(
        () => createMedicationSyncRuntime({ 'x-appwrite-key': 'dynamic-key' }, parser, missing),
        new RegExp(key),
      );
      assert.throws(
        () => createMedicationSyncRuntime(
          { 'x-appwrite-key': 'dynamic-key' },
          parser,
          { ...environment, [key]: ' ' },
        ),
        new RegExp(key),
      );
    }
  });

  test('requires server-side mounted access configuration for anonymous devices', () => {
    const { DOSEY_MOUNTED_ROBOT_ACCESS_TABLE_ID: _, ...missing } = environment;
    assert.throws(
      () => createMedicationSyncRuntime(
        { 'x-appwrite-key': 'dynamic-key' }, parser, missing,
      ),
      /DOSEY_MOUNTED_ROBOT_ACCESS_TABLE_ID/,
    );
  });

  test('requires server-side robot installation configuration for anonymous devices', () => {
    const { DOSEY_ROBOT_INSTALLATIONS_TABLE_ID: _, ...missing } = environment;
    assert.throws(
      () => createMedicationSyncRuntime(
        { 'x-appwrite-key': 'dynamic-key' }, parser, missing,
      ),
      /DOSEY_ROBOT_INSTALLATIONS_TABLE_ID/,
    );
  });

  test('keeps Google as the default and rejects unsafe provider configuration', () => {
    assert.deepEqual(configuredHumanProviders(undefined), ['google']);
    assert.deepEqual(configuredHumanProviders(' google, email '), ['google', 'email']);
    assert.throws(() => configuredHumanProviders('anonymous'), /Unsupported human provider/);
    assert.throws(() => configuredHumanProviders(''), /human provider/);
  });
});
