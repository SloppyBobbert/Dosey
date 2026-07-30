import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { describe, test } from 'node:test';

import {
  MedicationSyncContractError,
  assertMatchingIdempotentReplay,
  canonicalMutationHashInput,
  medicationSyncCanonicalTimezones,
  parseMedicationSyncValue,
  parseMutation,
  parseOccurrenceRef,
  parseSchedule,
} from '../src/domain/medication-sync-contract.js';

interface FixtureCase {
  readonly name: string;
  readonly type: string;
  readonly value: unknown;
}

async function fixtures(name: 'valid' | 'invalid'): Promise<readonly FixtureCase[]> {
  const url = new URL(
    `../../../contracts/medication-sync/v1/fixtures/${name}.json`,
    import.meta.url,
  );
  const document = JSON.parse(await readFile(url, 'utf8')) as {
    readonly cases: readonly FixtureCase[];
  };
  return document.cases;
}

describe('medication sync contract v1', () => {
  test('accepts every shared valid fixture', async () => {
    for (const fixture of await fixtures('valid')) {
      assert.doesNotThrow(
        () => parseMedicationSyncValue(fixture.type, fixture.value),
        fixture.name,
      );
    }
  });

  test('rejects every shared invalid fixture', async () => {
    for (const fixture of await fixtures('invalid')) {
      assert.throws(
        () => parseMedicationSyncValue(fixture.type, fixture.value),
        MedicationSyncContractError,
        fixture.name,
      );
    }
  });

  test('mirrors the shared canonical timezone artifact exactly', async () => {
    const url = new URL(
      '../../../contracts/medication-sync/v1/canonical-timezones.json',
      import.meta.url,
    );
    const document = JSON.parse(await readFile(url, 'utf8')) as {
      readonly zones: readonly string[];
    };

    assert.deepEqual(medicationSyncCanonicalTimezones, document.zones);
  });

  test('supports every timezone in the shared canonical set', () => {
    for (const timezoneId of medicationSyncCanonicalTimezones) {
      assert.doesNotThrow(() =>
        parseSchedule({
          contractVersion: 1,
          id: 'schedule-1',
          householdId: 'robot-1',
          medicationId: 'medication-1',
          label: 'Daily',
          hour: 8,
          minute: 30,
          timezoneId,
          enabled: true,
          revision: 1,
          deletedAt: null,
          updatedAt: '2026-07-29T08:15:30Z',
        }),
      );
    }
  });

  test('converts an ordinary occurrence in every canonical timezone', () => {
    for (const timezoneId of medicationSyncCanonicalTimezones) {
      let acceptedLocalDates = 0;
      for (const localDate of ['2026-07-28', '2026-07-29', '2026-07-30']) {
        try {
          parseOccurrenceRef({
            contractVersion: 1,
            occurrenceId: 'schedule-1:1:2026-07-29T12:00:00.000Z',
            scheduleId: 'schedule-1',
            scheduleRevision: 1,
            scheduledAt: '2026-07-29T12:00:00Z',
            localDate,
            timezoneId,
          });
          acceptedLocalDates += 1;
        } catch (error) {
          if (!(error instanceof MedicationSyncContractError)) throw error;
        }
      }
      assert.equal(acceptedLocalDates, 1, timezoneId);
    }
  });

  test('accepts an identical idempotent replay regardless of object key order', () => {
    const original = parseMutation({
      contractVersion: 1,
      mutationId: 'mutation-1',
      deviceId: 'android-1',
      idempotencyKey: 'android-1:mutation-1',
      entityType: 'medication',
      operation: 'upsert',
      entityId: 'medication-1',
      baseRevision: null,
      payload: {
        name: 'Morning pill',
        pillType: 'pill',
        instructions: null,
      },
    });
    const replay = parseMutation({
      payload: {
        instructions: null,
        pillType: 'pill',
        name: 'Morning pill',
      },
      baseRevision: null,
      entityId: 'medication-1',
      operation: 'upsert',
      entityType: 'medication',
      idempotencyKey: 'android-1:mutation-1',
      deviceId: 'android-1',
      mutationId: 'mutation-1',
      contractVersion: 1,
    });

    assert.doesNotThrow(() =>
      assertMatchingIdempotentReplay('robot-1', original, 'robot-1', replay),
    );
  });

  test('rejects reuse of an idempotency key with a changed payload', () => {
    const original = parseMutation({
      contractVersion: 1,
      mutationId: 'mutation-1',
      deviceId: 'android-1',
      idempotencyKey: 'android-1:mutation-1',
      entityType: 'medication',
      operation: 'upsert',
      entityId: 'medication-1',
      baseRevision: null,
      payload: {
        name: 'Morning pill',
        pillType: 'pill',
        instructions: null,
      },
    });
    const changed = parseMutation({
      ...original,
      payload: {...original.payload, name: 'Changed pill'},
    });

    assert.throws(
      () => assertMatchingIdempotentReplay('robot-1', original, 'robot-1', changed),
      (error: unknown) =>
        error instanceof MedicationSyncContractError &&
        error.code === 'IDEMPOTENCY_KEY_REUSED',
    );
  });

  test('scopes idempotent replay identity to one robot', () => {
    const mutation = parseMutation({
      contractVersion: 1,
      mutationId: 'mutation-1',
      deviceId: 'android-1',
      idempotencyKey: 'android-1:mutation-1',
      entityType: 'medication',
      operation: 'delete',
      entityId: 'medication-1',
      baseRevision: 1,
      payload: null,
    });

    assert.throws(
      () => assertMatchingIdempotentReplay('robot-1', mutation, 'robot-2', mutation),
      (error: unknown) =>
        error instanceof MedicationSyncContractError &&
        error.code === 'IDEMPOTENCY_SCOPE_MISMATCH',
    );
  });

  test('normalizes scheduledAt before deriving occurrence identity', () => {
    const occurrence = parseOccurrenceRef({
      contractVersion: 1,
      occurrenceId: 'schedule-1:2:2026-07-29T15:30:00.000Z',
      scheduleId: 'schedule-1',
      scheduleRevision: 2,
      scheduledAt: '2026-07-29T15:30:00Z',
      localDate: '2026-07-29',
      timezoneId: 'America/Los_Angeles',
    });

    assert.equal(occurrence.scheduledAt, '2026-07-29T15:30:00.000Z');
  });

  test('produces one server-side canonical idempotency hash input', () => {
    const mutation = {
      payload: {
        occurredAt: '2026-07-29T15:34:12.0Z',
        kind: 'taken_confirmed',
        occurrence: {
          timezoneId: 'America/Los_Angeles',
          localDate: '2026-07-29',
          scheduledAt: '2026-07-29T15:30:00Z',
          scheduleRevision: 2,
          scheduleId: 'schedule-1',
          occurrenceId: 'schedule-1:2:2026-07-29T15:30:00.000Z',
          contractVersion: 1,
        },
        medicationId: 'medication-1',
      },
      baseRevision: null,
      entityId: 'dose-event-1',
      operation: 'append',
      entityType: 'dose_event',
      idempotencyKey: 'android-1:mutation-1',
      deviceId: 'android-1',
      mutationId: 'mutation-1',
      contractVersion: 1,
    };

    assert.equal(
      canonicalMutationHashInput('robot-1', mutation),
      '{"mutation":{"baseRevision":null,"contractVersion":1,"deviceId":"android-1","entityId":"dose-event-1","entityType":"dose_event","idempotencyKey":"android-1:mutation-1","mutationId":"mutation-1","operation":"append","payload":{"kind":"taken_confirmed","medicationId":"medication-1","occurredAt":"2026-07-29T15:34:12.000Z","occurrence":{"contractVersion":1,"localDate":"2026-07-29","occurrenceId":"schedule-1:2:2026-07-29T15:30:00.000Z","scheduledAt":"2026-07-29T15:30:00.000Z","scheduleId":"schedule-1","scheduleRevision":2,"timezoneId":"America/Los_Angeles"}}},"robotId":"robot-1"}',
    );
    assert.equal(
      canonicalMutationHashInput('robot-1', mutation),
      canonicalMutationHashInput('robot-1', {
        ...mutation,
        payload: {...mutation.payload, occurredAt: '2026-07-29T15:34:12Z'},
      }),
    );
  });
});
