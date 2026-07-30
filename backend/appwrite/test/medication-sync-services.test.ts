import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  MedicationSyncAuthorizationError,
  MedicationSyncPullService,
  MedicationSyncPushService,
  type MedicationSyncApplicationStore,
} from '../src/application/medication-sync-services.js';

const now = new Date('2026-07-29T10:00:00Z');

function store(overrides: Partial<MedicationSyncApplicationStore> = {}): MedicationSyncApplicationStore {
  return {
    upsertDocument: async () => ({ status: 'applied', sequence: 1, resourceVersion: 1 }),
    archiveDocument: async () => ({ status: 'applied', sequence: 2, resourceVersion: 2 }),
    appendEvent: async () => ({ status: 'applied', sequence: 3 }),
    pull: async () => ({ changes: [], nextCursor: 0, checkpoint: 0, complete: true }),
    ...overrides,
  };
}

describe('Medication sync application services', () => {
  test('rejects the complete request when the active link does not authorize the robot', async () => {
    const service = new MedicationSyncPushService({
      authorize: async () => null,
    }, store(), () => now);

    await assert.rejects(
      service.push({ accountId: 'member-1', actorType: 'human', robotId: 'robot-1', operations: [] }),
      MedicationSyncAuthorizationError,
    );
  });

  test('lets members append events but rejects their document writes per operation', async () => {
    const appended: string[] = [];
    const service = new MedicationSyncPushService(
      { authorize: async () => ({ robotId: 'robot-1', role: 'member' }) },
      store({
        appendEvent: async (input) => {
          appended.push(input.eventId);
          return { status: 'applied', sequence: 7 };
        },
      }),
      () => now,
    );

    const result = await service.push({
      accountId: 'member-1',
      actorType: 'human',
      robotId: 'robot-1',
      operations: [
        {
          type: 'upsertDocument', operationId: 'mutation-1', idempotencyKey: 'key-1', deviceId: 'device-1', canonicalHashInput: 'document-1',
          resourceType: 'medication', resourceId: 'medication-1', baseVersion: 0, payload: '{}',
        },
        {
          type: 'appendEvent', operationId: 'mutation-2', idempotencyKey: 'key-2', deviceId: 'device-1', canonicalHashInput: 'event-1',
          eventId: 'event-1', kind: 'snoozed', doseId: 'dose-1',
          scheduleId: 'schedule-1', occurredAt: new Date('2026-07-29T08:00:00Z'), payload: '{}',
        },
      ],
    });

    assert.deepEqual(result, {
      acknowledgements: [
        { operationId: 'mutation-1', status: 'rejected', code: 'owner_required' },
        { operationId: 'mutation-2', status: 'applied', sequence: 7 },
      ],
    });
    assert.deepEqual(appended, ['event-1']);
  });

  test('passes owner document writes with server actor and receipt time', async () => {
    const seen: unknown[] = [];
    const service = new MedicationSyncPushService(
      { authorize: async () => ({ robotId: 'robot-1', role: 'owner' }) },
      store({
        upsertDocument: async (input) => {
          seen.push(input);
          return { status: 'duplicate', sequence: 4, resourceVersion: 2 };
        },
      }),
      () => now,
    );

    assert.deepEqual(await service.push({
      accountId: 'owner-1',
      actorType: 'human',
      robotId: 'robot-1',
      operations: [{
        type: 'upsertDocument', operationId: 'mutation-1', idempotencyKey: 'key-1', deviceId: 'device-1', canonicalHashInput: 'schedule-1',
        resourceType: 'schedule', resourceId: 'schedule-1', baseVersion: 1, payload: '{}',
      }],
    }), {
      acknowledgements: [{
        operationId: 'mutation-1', status: 'duplicate', sequence: 4, resourceVersion: 2,
      }],
    });
    const operation = seen[0] as { operationHash: string };
    assert.match(operation.operationHash, /^[a-f0-9]{64}$/);
    assert.deepEqual(seen, [{
      robotId: 'robot-1', operationId: 'key-1',
      operationHash: operation.operationHash,
      actorAccountId: 'owner-1', actorRole: 'owner', now,
      resourceType: 'schedule', resourceId: 'schedule-1', baseVersion: 1, payload: '{}',
    }]);
  });

  test('derives receipt and event hashes from normalized operation content', async () => {
    const seen: Array<{ operationId: string; operationHash: string; eventHash: string }> = [];
    const service = new MedicationSyncPushService(
      { authorize: async () => ({ robotId: 'robot-1', role: 'member' }) },
      store({
        appendEvent: async (input) => {
          seen.push({
            operationId: input.operationId,
            operationHash: input.operationHash,
            eventHash: input.eventHash,
          });
          return { status: 'applied', sequence: seen.length };
        },
      }),
      () => now,
    );
    const base = {
      type: 'appendEvent' as const,
      deviceId: 'device-1',
      idempotencyKey: 'same-key',
      eventId: 'event-1',
      kind: 'snoozed' as const,
      doseId: 'dose-1',
      scheduleId: 'schedule-1',
      occurredAt: new Date('2026-07-29T08:00:00Z'),
    };

    await service.push({
      accountId: 'member-1', actorType: 'human', robotId: 'robot-1',
      operations: [
        { ...base, operationId: 'mutation-1', canonicalHashInput: 'snoozed', payload: '{"kind":"snoozed"}' },
        { ...base, operationId: 'mutation-2', canonicalHashInput: 'help_requested', payload: '{"kind":"help_requested"}' },
      ],
    });

    assert.equal(seen[0]?.operationId, 'same-key');
    assert.notEqual(seen[0]?.operationHash, seen[1]?.operationHash);
    assert.notEqual(seen[0]?.eventHash, seen[1]?.eventHash);
  });

  test('authorizes pull before reading household changes', async () => {
    const service = new MedicationSyncPullService(
      { authorize: async () => ({ robotId: 'robot-1', role: 'member' }) },
      store({
        pull: async (input) => ({
          changes: [], nextCursor: input.cursor, checkpoint: input.checkpoint ?? 9, complete: false,
        }),
      }),
    );

    assert.deepEqual(await service.pull({
      accountId: 'member-1', actorType: 'human', robotId: 'robot-1', cursor: 5, checkpoint: 9, limit: 20,
    }), { changes: [], nextCursor: 5, checkpoint: 9, complete: false });
  });

  test('lets a claimed device append events and pull but rejects document mutations', async () => {
    const roles: string[] = [];
    const access = {
      authorize: async (input: { actorType: string }) => {
        assert.equal(input.actorType, 'device');
        return { robotId: 'robot-1', role: 'device' as const };
      },
    };
    const applicationStore = store({
      appendEvent: async (input) => {
        roles.push(input.actorRole);
        return { status: 'applied', sequence: 2 };
      },
    });
    const push = new MedicationSyncPushService(access, applicationStore, () => now);
    const result = await push.push({
      accountId: 'mounted-1', actorType: 'device', robotId: 'robot-1', operations: [
        {
          type: 'archiveDocument', operationId: 'mutation-1', idempotencyKey: 'key-1',
          deviceId: 'mounted-1', canonicalHashInput: 'delete', resourceType: 'medication',
          resourceId: 'medication-1', baseVersion: 1,
        },
        {
          type: 'appendEvent', operationId: 'mutation-2', idempotencyKey: 'key-2',
          deviceId: 'mounted-1', canonicalHashInput: 'event', eventId: 'event-1',
          kind: 'taken_confirmed', doseId: 'dose-1', scheduleId: 'schedule-1',
          occurredAt: now, payload: '{}',
        },
      ],
    });
    assert.deepEqual(result.acknowledgements, [
      { operationId: 'mutation-1', status: 'rejected', code: 'owner_required' },
      { operationId: 'mutation-2', status: 'applied', sequence: 2 },
    ]);
    assert.deepEqual(roles, ['device']);

    await new MedicationSyncPullService(access, applicationStore).pull({
      accountId: 'mounted-1', actorType: 'device', robotId: 'robot-1',
      cursor: 0, limit: 20,
    });
  });
});
