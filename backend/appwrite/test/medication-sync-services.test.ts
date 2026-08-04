import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  MedicationSyncAuthorizationError,
  MedicationSyncPullService,
  MedicationSyncPushService,
  type MedicationSyncApplicationStore,
  type MedicationSyncPushOperation,
} from '../src/application/medication-sync-services.js';
import {
  canonicalMutationHashInput,
  type DoseEventAppendMutation,
} from '../src/domain/medication-sync-contract.js';

const now = new Date('2026-07-29T10:00:00Z');

function human(role: 'owner' | 'member') {
  return {
    robotId: 'robot-1', role, authority: 'human' as const,
    registeredPatientDeviceId: null,
  };
}

function patientDevice(registeredPatientDeviceId: string | null) {
  return {
    robotId: 'robot-1', role: 'device' as const, authority: 'patient_device' as const,
    registeredPatientDeviceId,
  };
}

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

  test('lets members upsert plans and append Snoozed events', async () => {
    const appended: string[] = [];
    const service = new MedicationSyncPushService(
      { authorize: async () => human('member') },
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
        appendOperation(doseEventMutation('snoozed', 'mutation-2', 'device-1')),
      ],
    });

    assert.deepEqual(result, {
      acknowledgements: [
        { operationId: 'mutation-1', status: 'applied', sequence: 1, resourceVersion: 1 },
        { operationId: 'mutation-2', status: 'applied', sequence: 7 },
      ],
    });
    assert.deepEqual(appended, ['event-mutation-2']);
  });

  test('lets members archive plans', async () => {
    const archived: string[] = [];
    const service = new MedicationSyncPushService(
      { authorize: async () => human('member') },
      store({
        archiveDocument: async (input) => {
          archived.push(input.resourceId);
          return { status: 'applied', sequence: 2, resourceVersion: 2 };
        },
      }),
      () => now,
    );

    assert.deepEqual((await service.push({
      accountId: 'member-1', actorType: 'human', robotId: 'robot-1', operations: [{
        type: 'archiveDocument', operationId: 'mutation-1', idempotencyKey: 'key-1',
        deviceId: 'phone-1', canonicalHashInput: 'delete', resourceType: 'schedule',
        resourceId: 'schedule-1', baseVersion: 1,
      }],
    })).acknowledgements, [{
      operationId: 'mutation-1', status: 'applied', sequence: 2, resourceVersion: 2,
    }]);
    assert.deepEqual(archived, ['schedule-1']);
  });

  test('passes owner document writes with server actor and receipt time', async () => {
    const seen: unknown[] = [];
    const service = new MedicationSyncPushService(
      { authorize: async () => human('owner') },
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
      robotId: 'robot-1', idempotencyKey: 'key-1',
      operationHash: operation.operationHash,
      actorAccountId: 'owner-1', actorRole: 'owner', now,
      resourceType: 'schedule', resourceId: 'schedule-1', baseVersion: 1, payload: '{}',
    }]);
  });

  test('preserves Snoozed and Help event behavior while deriving normalized hashes', async () => {
    const seen: Array<{ idempotencyKey: string; operationHash: string; eventHash: string }> = [];
    const service = new MedicationSyncPushService(
      { authorize: async () => human('member') },
      store({
        appendEvent: async (input) => {
          seen.push({
            idempotencyKey: input.idempotencyKey,
            operationHash: input.operationHash,
            eventHash: input.eventHash,
          });
          return { status: 'applied', sequence: seen.length };
        },
      }),
      () => now,
    );
    const snoozed = doseEventMutation('snoozed', 'mutation-1', 'device-1', 'same-key');
    const help = doseEventMutation('help_requested', 'mutation-2', 'device-1', 'same-key');

    await service.push({
      accountId: 'member-1', actorType: 'human', robotId: 'robot-1',
      operations: [
        appendOperation(snoozed),
        appendOperation(help),
      ],
    });

    assert.equal(seen[0]?.idempotencyKey, 'same-key');
    assert.notEqual(seen[0]?.operationHash, seen[1]?.operationHash);
    assert.notEqual(seen[0]?.eventHash, seen[1]?.eventHash);
  });

  test('authorizes pull before reading household changes', async () => {
    const service = new MedicationSyncPullService(
      { authorize: async () => human('member') },
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

  test('lets a claimed device append Snoozed events and pull but rejects document mutations', async () => {
    const roles: string[] = [];
    let documentWrites = 0;
    const access = {
      authorize: async (input: { actorType: string }) => {
        assert.equal(input.actorType, 'device');
        return patientDevice('mounted-1');
      },
    };
    const applicationStore = store({
      appendEvent: async (input) => {
        roles.push(input.actorRole);
        return { status: 'applied', sequence: 2 };
      },
      archiveDocument: async () => {
        documentWrites += 1;
        return { status: 'applied', sequence: 1, resourceVersion: 1 };
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
        appendOperation(doseEventMutation('snoozed', 'mutation-2', 'mounted-1')),
      ],
    });
    assert.deepEqual(result.acknowledgements, [
      { operationId: 'mutation-1', status: 'rejected', code: 'owner_required' },
      { operationId: 'mutation-2', status: 'applied', sequence: 2 },
    ]);
    assert.deepEqual(roles, ['device']);
    assert.equal(documentWrites, 0);

    await new MedicationSyncPullService(access, applicationStore).pull({
      accountId: 'mounted-1', actorType: 'device', robotId: 'robot-1',
      cursor: 0, limit: 20,
    });
  });

  test('rejects Taken and Skipped events from owners and members without writing', async () => {
    for (const role of ['owner', 'member'] as const) {
      let writes = 0;
      const service = new MedicationSyncPushService(
        { authorize: async () => human(role) },
        store({ appendEvent: async () => { writes += 1; return { status: 'applied', sequence: 1 }; } }),
        () => now,
      );
      const operations = ['taken_confirmed', 'skipped'].map((kind, index) => terminalOperation(
        kind as 'taken_confirmed' | 'skipped', `mutation-${index + 1}`, 'patient-device-1',
      ));

      assert.deepEqual((await service.push({
        accountId: `${role}-1`, actorType: 'human', robotId: 'robot-1', operations,
      })).acknowledgements, operations.map((operation) => ({
        operationId: operation.operationId,
        status: 'rejected' as const,
        code: 'HUMAN_TERMINAL_OUTCOME_FORBIDDEN',
      })));
      assert.equal(writes, 0);
    }
  });

  test('fails closed for patient-device terminal events after authority checks', async () => {
    for (const [registeredPatientDeviceId, mutationDeviceId, code] of [
      ['patient-device-1', 'patient-device-1', null],
      [null, 'patient-device-1', 'PATIENT_DEVICE_AUTHORITY_REQUIRED'],
      ['patient-device-1', 'spoofed-device', 'DEVICE_IDENTITY_MISMATCH'],
    ] as const) {
      let writes = 0;
      const service = new MedicationSyncPushService(
        { authorize: async () => patientDevice(registeredPatientDeviceId) },
        store({ appendEvent: async () => { writes += 1; return { status: 'applied', sequence: 1 }; } }),
        () => now,
      );
      const operation = terminalOperation('taken_confirmed', 'mutation-1', mutationDeviceId);

      assert.deepEqual((await service.push({
        accountId: 'mounted-1', actorType: 'device', robotId: 'robot-1', operations: [operation],
      })).acknowledgements, [{
        operationId: 'mutation-1',
        status: 'rejected',
        code: code ?? 'terminal_persistence_not_implemented',
      }]);
      assert.equal(writes, 0);
    }
  });

  test('fails closed when terminal contract mutation has a nonterminal infrastructure kind', async () => {
    let writes = 0;
    const service = new MedicationSyncPushService(
      { authorize: async () => patientDevice('patient-device-1') },
      store({ appendEvent: async () => { writes += 1; return { status: 'applied', sequence: 1 }; } }),
      () => now,
    );

    const result = await service.push({
      accountId: 'mounted-1', actorType: 'device', robotId: 'robot-1', operations: [{
        ...terminalOperation('taken_confirmed', 'mutation-1', 'patient-device-1'),
        kind: 'snoozed',
      }],
    });

    assert.deepEqual(result.acknowledgements, [{
      operationId: 'mutation-1',
      status: 'rejected',
      code: 'mutation_handoff_mismatch',
    }]);
    assert.equal(writes, 0);
  });

  test('rejects mismatched append-event handoffs before terminal authorization or persistence', async () => {
    const mutation = doseEventMutation('snoozed', 'mutation-1', 'patient-device-1');
    const mismatches: readonly Partial<AppendOperation>[] = [
      { operationId: 'other-mutation' },
      { idempotencyKey: 'other-key' },
      { kind: 'taken_confirmed' },
      { eventId: 'other-event' },
      { deviceId: 'other-device' },
      { doseId: 'other-occurrence' },
      { scheduleId: 'other-schedule' },
      { occurredAt: new Date('2026-07-29T08:01:00.000Z') },
      { payload: '{"kind":"help_requested"}' },
      { canonicalHashInput: 'other-hash' },
    ];

    for (const overrides of mismatches) {
      let writes = 0;
      const service = new MedicationSyncPushService(
        { authorize: async () => patientDevice('patient-device-1') },
        store({ appendEvent: async () => { writes += 1; return { status: 'applied', sequence: 1 }; } }),
        () => now,
      );

      const result = await service.push({
        accountId: 'mounted-1', actorType: 'device', robotId: 'robot-1',
        operations: [appendOperation(mutation, overrides)],
      });

      assert.deepEqual(result.acknowledgements, [{
        operationId: 'mutation-1', status: 'rejected', code: 'mutation_handoff_mismatch',
      }]);
      assert.equal(writes, 0);
    }
  });

  test('marks a transient failure retryable and continues processing later operations', async () => {
    const service = new MedicationSyncPushService(
      { authorize: async () => human('owner') },
      store({
        upsertDocument: async (input) => {
          if (input.resourceId === 'medication-2') throw new Error('storage details');
          return { status: 'applied', sequence: input.resourceId === 'medication-1' ? 1 : 2, resourceVersion: 1 };
        },
      }),
      () => now,
    );

    const operations = ['medication-1', 'medication-2', 'medication-3'].map((resourceId, index) => ({
      type: 'upsertDocument' as const, operationId: `mutation-${index + 1}`,
      idempotencyKey: `key-${index + 1}`, deviceId: 'device-1', canonicalHashInput: resourceId,
      resourceType: 'medication' as const, resourceId, baseVersion: 0, payload: '{}',
    }));

    assert.deepEqual(await service.push({
      accountId: 'owner-1', actorType: 'human', robotId: 'robot-1', operations,
    }), {
      acknowledgements: [
        { operationId: 'mutation-1', status: 'applied', sequence: 1, resourceVersion: 1 },
        { operationId: 'mutation-2', status: 'rejected', code: 'retryable_internal_error' },
        { operationId: 'mutation-3', status: 'applied', sequence: 2, resourceVersion: 1 },
      ],
    });
  });
});

function terminalOperation(
  kind: 'taken_confirmed' | 'skipped',
  operationId: string,
  deviceId: string,
) {
  return appendOperation(doseEventMutation(kind, operationId, deviceId));
}

function doseEventMutation(
  kind: DoseEventAppendMutation['payload']['kind'],
  mutationId: string,
  deviceId: string,
  idempotencyKey = `${deviceId}:${mutationId}`,
): DoseEventAppendMutation {
  return {
    contractVersion: 1,
    mutationId,
    deviceId,
    idempotencyKey,
    entityType: 'dose_event',
    operation: 'append',
    entityId: `event-${mutationId}`,
    baseRevision: null,
    payload: {
      medicationId: 'medication-1',
      occurrence: {
        contractVersion: 1,
        occurrenceId: 'schedule-1:1:2026-07-29T08:00:00.000Z',
        scheduleId: 'schedule-1',
        scheduleRevision: 1,
        scheduledAt: '2026-07-29T08:00:00.000Z',
        localDate: '2026-07-29',
        timezoneId: 'Etc/UTC',
      },
      kind,
      occurredAt: '2026-07-29T08:00:00.000Z',
    },
  };
}

type AppendOperation = Extract<MedicationSyncPushOperation, { readonly type: 'appendEvent' }>;

function appendOperation(
  contractMutation: DoseEventAppendMutation,
  overrides: Partial<AppendOperation> = {},
): AppendOperation {
  const operation: AppendOperation = {
    type: 'appendEvent',
    operationId: contractMutation.mutationId,
    idempotencyKey: contractMutation.idempotencyKey,
    deviceId: contractMutation.deviceId,
    canonicalHashInput: canonicalMutationHashInput('robot-1', contractMutation),
    eventId: contractMutation.entityId,
    kind: contractMutation.payload.kind,
    doseId: contractMutation.payload.occurrence.occurrenceId,
    scheduleId: contractMutation.payload.occurrence.scheduleId,
    occurredAt: new Date(contractMutation.payload.occurredAt),
    payload: JSON.stringify(contractMutation.payload),
    contractMutation,
  };
  return {...operation, ...overrides};
}
