import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  parsePullPage,
  parsePushResponse,
} from '../src/domain/medication-sync-contract.js';
import {
  medicationSyncContractParser,
  serializeMedicationSyncPullPage,
  serializeMedicationSyncPushResponse,
} from '../src/functions/medication-sync-contract-adapter.js';

describe('Medication sync contract adapter', () => {
  test('maps normalized wire mutations to application operations', () => {
    const parsed = medicationSyncContractParser.parsePush({
      contractVersion: 1,
      robotId: 'robot-1',
      operations: [{
        contractVersion: 1,
        mutationId: 'mutation-1',
        deviceId: 'phone-1',
        idempotencyKey: 'phone-1:mutation-1',
        entityType: 'dose_event',
        operation: 'append',
        entityId: 'event-1',
        baseRevision: null,
        payload: {
          medicationId: 'medication-1',
          occurrence: {
            contractVersion: 1,
            occurrenceId: 'schedule-1:2:2026-07-29T15:30:00.000Z',
            scheduleId: 'schedule-1',
            scheduleRevision: 2,
            scheduledAt: '2026-07-29T15:30:00Z',
            localDate: '2026-07-29',
            timezoneId: 'America/Los_Angeles',
          },
          kind: 'taken_confirmed',
          occurredAt: '2026-07-29T15:34:12Z',
        },
      }],
    });

    assert.equal(parsed.ok, true);
    if (!parsed.ok) return;
    assert.equal(parsed.value.operations[0]?.operationId, 'mutation-1');
    assert.equal(parsed.value.operations[0]?.idempotencyKey, 'phone-1:mutation-1');
    assert.equal(parsed.value.operations[0]?.canonicalHashInput.includes('"robotId":"robot-1"'), true);
    assert.equal(parsed.value.operations[0]?.type, 'appendEvent');
  });

  test('returns only contract validation errors as parse results', () => {
    assert.deepEqual(medicationSyncContractParser.parsePull({}), {
      ok: false,
      code: 'MISSING_FIELD',
    });
  });

  test('serializes parser-valid push acknowledgements', () => {
    const response = serializeMedicationSyncPushResponse('robot-1', [{
      operationId: 'mutation-1',
      status: 'applied',
      sequence: 7,
      resourceVersion: 2,
    }]);

    assert.deepEqual(parsePushResponse(response), response);
    assert.deepEqual(response, {
      contractVersion: 1,
      robotId: 'robot-1',
      acknowledgements: [{
        contractVersion: 1,
        mutationId: 'mutation-1',
        outcome: 'applied',
        revision: 2,
        cursor: '7',
        errorCode: null,
        conflict: null,
      }],
    });
  });

  test('serializes an authorized CAS conflict with its authoritative record', () => {
    const response = serializeMedicationSyncPushResponse('robot-1', [{
      operationId: 'mutation-1',
      status: 'conflict',
      code: 'version_conflict',
      resourceType: 'medication',
      resourceId: 'medication-1',
      baseVersion: 1,
      currentVersion: 2,
      currentDocument: {
        robotId: 'robot-1', resourceType: 'medication', resourceId: 'medication-1',
        version: 2, archived: false,
        payload: JSON.stringify({
          contractVersion: 1, id: 'medication-1', householdId: 'robot-1',
          name: 'Morning tablet', pillType: 'tablet', instructions: null,
          revision: 2, deletedAt: null, updatedAt: '2026-07-29T10:00:00.000Z',
        }),
        createdAt: new Date('2026-07-28T10:00:00Z'), createdByAccountId: 'owner-1',
        updatedAt: new Date('2026-07-29T10:00:00Z'), updatedByAccountId: 'owner-1',
      },
    }]);

    assert.deepEqual(parsePushResponse(response), response);
    assert.equal(response.acknowledgements[0]?.outcome, 'conflict');
    assert.equal(response.acknowledgements[0]?.conflict?.actualRevision, 2);
  });

  test('serializes full records and tombstones in parser-valid pull pages', () => {
    const response = serializeMedicationSyncPullPage({
      robotId: 'robot-1',
      cursor: null,
      changes: [{
        robotId: 'robot-1',
        sequence: 1,
        resourceType: 'medication',
        resourceId: 'medication-1',
        resourceVersion: 1,
        operation: 'upsert',
        payload: JSON.stringify({
          contractVersion: 1,
          id: 'medication-1',
          householdId: 'robot-1',
          name: 'Morning tablet',
          pillType: 'tablet',
          instructions: null,
          revision: 1,
          deletedAt: null,
          updatedAt: '2026-07-29T10:00:00.000Z',
        }),
        actorAccountId: 'owner-1',
        actorRole: 'owner',
        changedAt: new Date('2026-07-29T10:00:00Z'),
        operationId: 'key-1',
        operationHash: 'hash',
      }],
      nextCursor: 1,
      checkpoint: 1,
      complete: true,
    });

    assert.deepEqual(parsePullPage(response), response);
    assert.equal(response.changes[0]?.operation, 'upsert');
  });
});
