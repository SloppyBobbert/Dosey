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
  test('maps create and update mutations to upserts and deletes to archives', () => {
    const parsed = medicationSyncContractParser.parsePush({
      contractVersion: 1,
      robotId: 'robot-1',
      operations: [{
        contractVersion: 1,
        mutationId: 'mutation-1',
        deviceId: 'phone-1',
        idempotencyKey: 'phone-1:mutation-1',
        entityType: 'medication',
        operation: 'upsert',
        entityId: 'medication-1',
        baseRevision: null,
        payload: { name: 'Morning tablet', pillType: 'tablet', instructions: null },
      }, {
        contractVersion: 1,
        mutationId: 'mutation-2',
        deviceId: 'phone-1',
        idempotencyKey: 'phone-1:mutation-2',
        entityType: 'schedule',
        operation: 'upsert',
        entityId: 'schedule-1',
        baseRevision: 2,
        payload: {
          medicationId: 'medication-1', label: 'Morning', hour: 8, minute: 30,
          timezoneId: 'America/Los_Angeles', enabled: true,
        },
      }, {
        contractVersion: 1,
        mutationId: 'mutation-3',
        deviceId: 'phone-1',
        idempotencyKey: 'phone-1:mutation-3',
        entityType: 'schedule',
        operation: 'delete',
        entityId: 'schedule-1',
        baseRevision: 3,
        payload: null,
      }, {
        contractVersion: 1,
        mutationId: 'mutation-4',
        deviceId: 'phone-1',
        idempotencyKey: 'phone-1:mutation-4',
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
    assert.equal(parsed.value.operations[0]?.type, 'upsertDocument');
    assert.equal(parsed.value.operations[0]?.baseVersion, 0);
    assert.equal(parsed.value.operations[1]?.type, 'upsertDocument');
    assert.equal(parsed.value.operations[1]?.baseVersion, 2);
    assert.equal(parsed.value.operations[2]?.type, 'archiveDocument');
    assert.equal(parsed.value.operations[2]?.baseVersion, 3);
    assert.equal(parsed.value.operations[3]?.operationId, 'mutation-4');
    assert.equal(parsed.value.operations[3]?.idempotencyKey, 'phone-1:mutation-4');
    assert.equal(parsed.value.operations[3]?.canonicalHashInput.includes('"robotId":"robot-1"'), true);
    assert.equal(parsed.value.operations[3]?.type, 'appendEvent');
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

  test('preserves duplicate acknowledgement mutation, revision, and cursor', () => {
    const response = serializeMedicationSyncPushResponse('robot-1', [{
      operationId: 'mutation-duplicate',
      status: 'duplicate',
      sequence: 7,
      resourceVersion: 2,
    }]);

    assert.deepEqual(response.acknowledgements[0], {
      contractVersion: 1,
      mutationId: 'mutation-duplicate',
      outcome: 'duplicate',
      revision: 2,
      cursor: '7',
      errorCode: null,
      conflict: null,
    });
  });

  test('serializes transient operation failures as retryable rejections', () => {
    const response = serializeMedicationSyncPushResponse('robot-1', [{
      operationId: 'mutation-1', status: 'rejected', code: 'retryable_internal_error',
    }]);

    assert.deepEqual(response.acknowledgements[0], {
      contractVersion: 1,
      mutationId: 'mutation-1',
      outcome: 'rejected',
      revision: null,
      cursor: null,
      errorCode: 'RETRYABLE_INTERNAL_ERROR',
      conflict: null,
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

  test('serializes a creation-race conflict with expected revision zero', () => {
    const response = serializeMedicationSyncPushResponse('robot-1', [{
      operationId: 'mutation-1', status: 'conflict', code: 'version_conflict',
      resourceType: 'medication', resourceId: 'medication-1', baseVersion: 0, currentVersion: 1,
      currentDocument: {
        robotId: 'robot-1', resourceType: 'medication', resourceId: 'medication-1',
        version: 1, archived: false,
        payload: JSON.stringify({
          contractVersion: 1, id: 'medication-1', householdId: 'robot-1',
          name: 'Morning tablet', pillType: 'tablet', instructions: null,
          revision: 1, deletedAt: null, updatedAt: '2026-07-29T10:00:00.000Z',
        }),
        createdAt: new Date('2026-07-28T10:00:00Z'), createdByAccountId: 'owner-1',
        updatedAt: new Date('2026-07-29T10:00:00Z'), updatedByAccountId: 'owner-1',
      },
    }]);

    assert.equal(response.acknowledgements[0]?.outcome, 'conflict');
    assert.equal(response.acknowledgements[0]?.conflict?.expectedRevision, 0);
    assert.equal(response.acknowledgements[0]?.conflict?.authoritativeRecord.revision, 1);
  });

  test('falls back to a rejection for incomplete version conflicts', () => {
    const response = serializeMedicationSyncPushResponse('robot-1', [{
      operationId: 'mutation-1', status: 'conflict', code: 'version_conflict',
      resourceType: 'medication', resourceId: 'medication-1', baseVersion: 0, currentVersion: 1,
    }]);

    assert.deepEqual(response.acknowledgements[0], {
      contractVersion: 1, mutationId: 'mutation-1', outcome: 'rejected',
      revision: null, cursor: null, errorCode: 'VERSION_CONFLICT', conflict: null,
    });
  });

  test('serializes full records, archives, and events in parser-valid pull pages', () => {
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
        idempotencyKey: 'key-1',
        operationHash: 'hash',
      }, {
        robotId: 'robot-1', sequence: 2, resourceType: 'schedule', resourceId: 'schedule-1',
        resourceVersion: 2, operation: 'archive',
        payload: JSON.stringify({
          contractVersion: 1, id: 'schedule-1', householdId: 'robot-1', medicationId: 'medication-1',
          label: 'Morning', hour: 8, minute: 30, timezoneId: 'America/Los_Angeles', enabled: false,
          revision: 2, deletedAt: '2026-07-29T10:00:00.000Z', updatedAt: '2026-07-29T10:00:00.000Z',
        }), actorAccountId: 'owner-1', actorRole: 'owner', changedAt: new Date('2026-07-29T10:00:00Z'),
        idempotencyKey: 'key-2', operationHash: 'hash',
      }, {
        robotId: 'robot-1', sequence: 3, resourceType: 'doseEvent', resourceId: 'event-1',
        resourceVersion: null, operation: 'event',
        payload: JSON.stringify({
          contractVersion: 1, id: 'event-1', householdId: 'robot-1', medicationId: 'medication-1',
          occurrence: {
            contractVersion: 1, occurrenceId: 'schedule-1:2:2026-07-29T15:30:00.000Z',
            scheduleId: 'schedule-1', scheduleRevision: 2, scheduledAt: '2026-07-29T15:30:00.000Z',
            localDate: '2026-07-29', timezoneId: 'America/Los_Angeles',
          }, kind: 'taken_confirmed', occurredAt: '2026-07-29T15:34:12.000Z', actorAccountId: 'owner-1',
        }), actorAccountId: 'owner-1', actorRole: 'owner', changedAt: new Date('2026-07-29T10:00:00Z'),
        idempotencyKey: 'key-3', operationHash: 'hash',
      }],
      nextCursor: 3,
      checkpoint: 3,
      complete: true,
    });

    assert.deepEqual(parsePullPage(response), response);
    assert.equal(response.changes[0]?.operation, 'upsert');
    assert.equal(response.changes[1]?.operation, 'delete');
    assert.equal(response.changes[2]?.entityType, 'dose_event');
    assert.equal(response.changes[2]?.operation, 'append');
  });
});
