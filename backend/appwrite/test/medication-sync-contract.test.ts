import assert from 'node:assert/strict';
import { mkdtemp, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, test } from 'node:test';

import {
  MedicationSyncContractError,
  assertMatchingIdempotentReplay,
  canonicalMedicationSyncJson,
  canonicalMutationHashInput,
  medicationSyncCanonicalTimezones,
  parseMedicationSyncValue,
  parseMutation,
  parseOccurrenceRef,
  parseSchedule,
  resolveTerminalOutcome,
  evaluateTerminalOutcomeAuthority,
  isTerminalDoseEventMutation,
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

  test('maps a runtime-unavailable canonical timezone to a contract error', () => {
    const original = Intl.DateTimeFormat;
    Object.defineProperty(Intl, 'DateTimeFormat', {
      configurable: true,
      value: function DateTimeFormat(
        locales?: Intl.LocalesArgument,
        options?: Intl.DateTimeFormatOptions,
      ) {
        if (options?.timeZone === 'America/Los_Angeles') {
          throw new RangeError('unsupported test timezone');
        }
        return new original(locales, options);
      },
    });

    try {
      assert.throws(
        () =>
          parseSchedule({
            contractVersion: 1,
            id: 'schedule-1',
            householdId: 'robot-1',
            medicationId: 'medication-1',
            label: 'Daily',
            hour: 8,
            minute: 30,
            timezoneId: 'America/Los_Angeles',
            enabled: true,
            revision: 1,
            deletedAt: null,
            updatedAt: '2026-07-29T08:15:30Z',
          }),
        (error: unknown) =>
          error instanceof MedicationSyncContractError &&
          error.code === 'UNSUPPORTED_TIMEZONE_DATABASE',
      );
    } finally {
      Object.defineProperty(Intl, 'DateTimeFormat', {
        configurable: true,
        value: original,
      });
    }
  });

  test('orders canonical object keys by UTF-16 code units', () => {
    assert.equal(
      canonicalMedicationSyncJson({'\uE000': 4, '\u{10000}': 3, é: 2, a: 1}),
      '{"a":1,"é":2,"𐀀":3,"":4}',
    );
  });

  test('matches TypeScript integer semantics for integral JSON numbers', () => {
    const schedule = {
      contractVersion: 1,
      id: 'schedule-1',
      householdId: 'robot-1',
      medicationId: 'medication-1',
      label: 'Daily',
      hour: 1,
      minute: 30,
      timezoneId: 'UTC',
      enabled: true,
      revision: 1,
      deletedAt: null,
      updatedAt: '2026-07-29T08:15:30Z',
    };

    assert.equal(parseSchedule({...schedule, hour: -0}).hour, 0);
    assert.equal(
      parseSchedule({...schedule, revision: 9_007_199_254_740_991}).revision,
      9_007_199_254_740_991,
    );
    for (const value of [1.5, Number.NaN, Number.POSITIVE_INFINITY, 9_007_199_254_740_992]) {
      assert.throws(
        () => parseSchedule({...schedule, revision: value}),
        MedicationSyncContractError,
      );
    }
  });

  test('timezone generation leaves originals intact when preflight validation fails', async () => {
    const directory = await mkdtemp(join(tmpdir(), 'dosey-timezones-'));
    try {
      const source = join(directory, 'tzdata.zi');
      const artifact = join(directory, 'canonical-timezones.json');
      const typescript = join(directory, 'contract.ts');
      const dart = join(directory, 'contract.dart');
      await writeFile(source, '# version 2026b-rearguard\nZ Test/Zone 0 - TEST\n');
      await writeFile(artifact, 'artifact-original\n');
      await writeFile(
        typescript,
        '// BEGIN GENERATED CANONICAL TIMEZONES\nold\n// END GENERATED CANONICAL TIMEZONES\n',
      );
      await writeFile(dart, 'dart-original-without-markers\n');
      const moduleUrl = new URL(
        '../../../contracts/medication-sync/v1/generate-timezones.mjs',
        import.meta.url,
      ).href;
      const generator = (await import(moduleUrl)) as {
        generateTimezones: (...args: readonly unknown[]) => Promise<void>;
      };

      await assert.rejects(() => generator.generateTimezones(source, artifact, typescript, dart));
      assert.equal(await readFile(artifact, 'utf8'), 'artifact-original\n');
      assert.match(await readFile(typescript, 'utf8'), /\nold\n/);
      assert.equal(await readFile(dart, 'utf8'), 'dart-original-without-markers\n');
      assert.deepEqual((await readdir(directory)).sort(), [
        'canonical-timezones.json',
        'contract.dart',
        'contract.ts',
        'tzdata.zi',
      ]);
    } finally {
      await rm(directory, {recursive: true, force: true});
    }
  });

  test('timezone generation restores originals after a later replacement fails', async () => {
    const directory = await mkdtemp(join(tmpdir(), 'dosey-timezones-'));
    try {
      const source = join(directory, 'tzdata.zi');
      const artifact = join(directory, 'canonical-timezones.json');
      const typescript = join(directory, 'contract.ts');
      const dart = join(directory, 'contract.dart');
      const marked =
        '// BEGIN GENERATED CANONICAL TIMEZONES\nold\n// END GENERATED CANONICAL TIMEZONES\n';
      await writeFile(source, '# version 2026b-rearguard\nZ Test/Zone 0 - TEST\n');
      await writeFile(artifact, 'artifact-original\n');
      await writeFile(typescript, marked);
      await writeFile(dart, marked);
      const moduleUrl = new URL(
        '../../../contracts/medication-sync/v1/generate-timezones.mjs',
        import.meta.url,
      ).href;
      const generator = (await import(moduleUrl)) as {
        generateTimezones: (
          sourcePath: string,
          outputPath: string,
          typescriptPath: string,
          dartPath: string,
          options: {beforeReplace: (index: number) => void},
        ) => Promise<void>;
      };

      await assert.rejects(() =>
        generator.generateTimezones(source, artifact, typescript, dart, {
          beforeReplace(index) {
            if (index === 2) throw new Error('injected later replacement failure');
          },
        }),
      );
      assert.equal(await readFile(artifact, 'utf8'), 'artifact-original\n');
      assert.equal(await readFile(typescript, 'utf8'), marked);
      assert.equal(await readFile(dart, 'utf8'), marked);
      assert.deepEqual((await readdir(directory)).sort(), [
        'canonical-timezones.json',
        'contract.dart',
        'contract.ts',
        'tzdata.zi',
      ]);
    } finally {
      await rm(directory, {recursive: true, force: true});
    }
  });

  test('timezone generation restores originals when the first replacement fails', async () => {
    const directory = await mkdtemp(join(tmpdir(), 'dosey-timezones-'));
    try {
      const source = join(directory, 'tzdata.zi');
      const artifact = join(directory, 'canonical-timezones.json');
      const typescript = join(directory, 'contract.ts');
      const dart = join(directory, 'contract.dart');
      const marked =
        '// BEGIN GENERATED CANONICAL TIMEZONES\nold\n// END GENERATED CANONICAL TIMEZONES\n';
      await writeFile(source, '# version 2026b-rearguard\nZ Test/Zone 0 - TEST\n');
      await writeFile(artifact, 'artifact-original\n');
      await writeFile(typescript, marked);
      await writeFile(dart, marked);
      const moduleUrl = new URL(
        '../../../contracts/medication-sync/v1/generate-timezones.mjs',
        import.meta.url,
      ).href;
      const generator = (await import(moduleUrl)) as {
        generateTimezones: (
          sourcePath: string,
          outputPath: string,
          typescriptPath: string,
          dartPath: string,
          options: {beforeReplace: (index: number) => void},
        ) => Promise<void>;
      };

      await assert.rejects(() =>
        generator.generateTimezones(source, artifact, typescript, dart, {
          beforeReplace(index) {
            if (index === 0) throw new Error('injected first replacement failure');
          },
        }),
      );
      assert.equal(await readFile(artifact, 'utf8'), 'artifact-original\n');
      assert.equal(await readFile(typescript, 'utf8'), marked);
      assert.equal(await readFile(dart, 'utf8'), marked);
      assert.deepEqual((await readdir(directory)).sort(), [
        'canonical-timezones.json',
        'contract.dart',
        'contract.ts',
        'tzdata.zi',
      ]);
    } finally {
      await rm(directory, {recursive: true, force: true});
    }
  });

  test('timezone generation waits for every staged write before cleaning a staging failure', async () => {
    const directory = await mkdtemp(join(tmpdir(), 'dosey-timezones-'));
    try {
      const source = join(directory, 'tzdata.zi');
      const artifact = join(directory, 'canonical-timezones.json');
      const typescript = join(directory, 'contract.ts');
      const dart = join(directory, 'contract.dart');
      const marked =
        '// BEGIN GENERATED CANONICAL TIMEZONES\nold\n// END GENERATED CANONICAL TIMEZONES\n';
      await writeFile(source, '# version 2026b-rearguard\nZ Test/Zone 0 - TEST\n');
      await writeFile(artifact, 'artifact-original\n');
      await writeFile(typescript, marked);
      await writeFile(dart, marked);
      const moduleUrl = new URL(
        '../../../contracts/medication-sync/v1/generate-timezones.mjs',
        import.meta.url,
      ).href;
      const generator = (await import(moduleUrl)) as {
        generateTimezones: (
          sourcePath: string,
          outputPath: string,
          typescriptPath: string,
          dartPath: string,
          options: {
            writeTemporary: (
              path: string,
              content: string,
              index: number,
            ) => Promise<void>;
          },
        ) => Promise<void>;
      };

      await assert.rejects(() =>
        generator.generateTimezones(source, artifact, typescript, dart, {
          async writeTemporary(path, content, index) {
            if (index === 1) throw new Error('injected staging failure');
            if (index === 2) await new Promise((resolve) => setTimeout(resolve, 30));
            await writeFile(path, content, {flag: 'wx'});
          },
        }),
      );
      await new Promise((resolve) => setTimeout(resolve, 50));
      assert.equal(await readFile(artifact, 'utf8'), 'artifact-original\n');
      assert.equal(await readFile(typescript, 'utf8'), marked);
      assert.equal(await readFile(dart, 'utf8'), marked);
      assert.deepEqual((await readdir(directory)).sort(), [
        'canonical-timezones.json',
        'contract.dart',
        'contract.ts',
        'tzdata.zi',
      ]);
    } finally {
      await rm(directory, {recursive: true, force: true});
    }
  });

  test('timezone generation keeps committed targets when backup cleanup fails', async () => {
    const directory = await mkdtemp(join(tmpdir(), 'dosey-timezones-'));
    try {
      const source = join(directory, 'tzdata.zi');
      const artifact = join(directory, 'canonical-timezones.json');
      const typescript = join(directory, 'contract.ts');
      const dart = join(directory, 'contract.dart');
      const marked =
        '// BEGIN GENERATED CANONICAL TIMEZONES\nold\n// END GENERATED CANONICAL TIMEZONES\n';
      await writeFile(source, '# version 2026b-rearguard\nZ Test/Zone 0 - TEST\n');
      await writeFile(artifact, 'artifact-original\n');
      await writeFile(typescript, marked);
      await writeFile(dart, marked);
      const moduleUrl = new URL(
        '../../../contracts/medication-sync/v1/generate-timezones.mjs',
        import.meta.url,
      ).href;
      const generator = (await import(moduleUrl)) as {
        generateTimezones: (
          sourcePath: string,
          outputPath: string,
          typescriptPath: string,
          dartPath: string,
          options: {
            removeBackup: (path: string, index: number) => Promise<void>;
          },
        ) => Promise<void>;
      };

      await assert.rejects(() =>
        generator.generateTimezones(source, artifact, typescript, dart, {
          async removeBackup(path, index) {
            if (index === 1) throw new Error('injected backup cleanup failure');
            await rm(path, {force: true});
          },
        }),
      );
      const artifactDocument = JSON.parse(await readFile(artifact, 'utf8')) as {
        zones: string[];
      };
      assert.deepEqual(artifactDocument.zones, ['Test/Zone', 'UTC']);
      const typescriptContent = await readFile(typescript, 'utf8');
      const dartContent = await readFile(dart, 'utf8');
      for (const zone of artifactDocument.zones) {
        assert.match(typescriptContent, new RegExp(JSON.stringify(zone)));
        assert.match(dartContent, new RegExp(`'${zone}'`));
      }
      const entries = await readdir(directory);
      assert.ok(entries.includes('canonical-timezones.json'));
      assert.ok(entries.includes('contract.ts'));
      assert.ok(entries.includes('contract.dart'));
      assert.equal(entries.some((entry) => entry.includes('.tmp-')), false);
      assert.equal(entries.filter((entry) => entry.includes('.bak-')).length, 1);
    } finally {
      await rm(directory, {recursive: true, force: true});
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
      '{"mutation":{"baseRevision":null,"contractVersion":1,"deviceId":"android-1","entityId":"dose-event-1","entityType":"dose_event","idempotencyKey":"android-1:mutation-1","mutationId":"mutation-1","operation":"append","payload":{"kind":"taken_confirmed","medicationId":"medication-1","occurredAt":"2026-07-29T15:34:12.000Z","occurrence":{"contractVersion":1,"localDate":"2026-07-29","occurrenceId":"schedule-1:2:2026-07-29T15:30:00.000Z","scheduleId":"schedule-1","scheduleRevision":2,"scheduledAt":"2026-07-29T15:30:00.000Z","timezoneId":"America/Los_Angeles"}}},"robotId":"robot-1"}',
    );
    assert.equal(
      canonicalMutationHashInput('robot-1', mutation),
      canonicalMutationHashInput('robot-1', {
        ...mutation,
        payload: {...mutation.payload, occurredAt: '2026-07-29T15:34:12Z'},
      }),
    );
  });

  test('classifies exactly the three terminal dose event kinds', () => {
    for (const kind of ['taken_confirmed', 'skipped', 'missed']) {
      assert.equal(isTerminalDoseEventMutation(terminalMutation(kind)), true);
    }
    assert.equal(isTerminalDoseEventMutation(terminalMutation('snoozed')), false);
    assert.equal(isTerminalDoseEventMutation(terminalMutation('help_requested')), false);
  });

  test('requires terminal mutations for authority decisions', () => {
    const humanOwner = {accountId: 'owner-1', authority: 'human' as const, registeredDeviceId: null, role: 'owner' as const};
    const humanCaregiver = {...humanOwner, accountId: 'caregiver-1', role: 'member' as const};
    const matchingDevice = {accountId: 'device-1', authority: 'patient_device' as const, registeredDeviceId: 'patient-device-1', role: null};
    const mismatchedDevice = {...matchingDevice, registeredDeviceId: 'patient-device-2'};
    const missingDevice = {...matchingDevice, registeredDeviceId: null};
    const terminal = terminalMutation('missed');
    assert.deepEqual(evaluateTerminalOutcomeAuthority(humanOwner, terminal), {outcome: 'rejected', errorCode: 'HUMAN_TERMINAL_OUTCOME_FORBIDDEN'});
    assert.deepEqual(evaluateTerminalOutcomeAuthority(humanCaregiver, terminal), {outcome: 'rejected', errorCode: 'HUMAN_TERMINAL_OUTCOME_FORBIDDEN'});
    assert.deepEqual(evaluateTerminalOutcomeAuthority(matchingDevice, terminal), {outcome: 'allowed'});
    assert.deepEqual(evaluateTerminalOutcomeAuthority(mismatchedDevice, terminal), {outcome: 'rejected', errorCode: 'DEVICE_IDENTITY_MISMATCH'});
    assert.deepEqual(evaluateTerminalOutcomeAuthority(missingDevice, terminal), {outcome: 'rejected', errorCode: 'PATIENT_DEVICE_AUTHORITY_REQUIRED'});
    assertContractCode(() => evaluateTerminalOutcomeAuthority(humanOwner, terminalMutation('snoozed')), 'TERMINAL_OUTCOME_REQUIRED');
  });

  test('resolves terminal outcomes deterministically per occurrence', () => {
    const taken = terminalMutation('taken_confirmed');
    assert.deepEqual(resolveTerminalOutcome(taken, taken), {outcome: 'duplicate'});
    assert.deepEqual(resolveTerminalOutcome(taken, terminalMutation('taken_confirmed', {entityId: 'event-2'})), {outcome: 'needs_review', errorCode: 'TERMINAL_OUTCOME_REPLAY_MISMATCH'});
    assert.deepEqual(resolveTerminalOutcome(taken, terminalMutation('taken_confirmed', {occurredAt: '2026-07-29T15:35:12Z'})), {outcome: 'needs_review', errorCode: 'TERMINAL_OUTCOME_REPLAY_MISMATCH'});
    for (const [left, right] of [['taken_confirmed', 'skipped'], ['taken_confirmed', 'missed'], ['skipped', 'missed']] as const) {
      assert.deepEqual(resolveTerminalOutcome(terminalMutation(left), terminalMutation(right)), {outcome: 'needs_review', errorCode: 'TERMINAL_OUTCOME_CONFLICT'});
    }
    assertContractCode(() => resolveTerminalOutcome(taken, terminalMutation('missed', {occurrenceId: 'schedule-2:2:2026-07-29T15:30:00.000Z'})), 'TERMINAL_OUTCOME_OCCURRENCE_MISMATCH');
    assertContractCode(() => resolveTerminalOutcome(taken, terminalMutation('snoozed')), 'TERMINAL_OUTCOME_REQUIRED');
    assertContractCode(() => resolveTerminalOutcome(terminalMutation('help_requested'), terminalMutation('help_requested')), 'TERMINAL_OUTCOME_REQUIRED');
  });
});

function terminalMutation(kind: 'taken_confirmed' | 'skipped' | 'missed' | 'snoozed' | 'help_requested', overrides: {entityId?: string; occurredAt?: string; occurrenceId?: string} = {}) {
  const occurrenceId = overrides.occurrenceId ?? 'schedule-1:2:2026-07-29T15:30:00.000Z';
  const scheduleId = occurrenceId.startsWith('schedule-2:') ? 'schedule-2' : 'schedule-1';
  return parseMutation({contractVersion: 1, mutationId: 'terminal-1', deviceId: 'patient-device-1', idempotencyKey: 'patient-device-1:terminal-1', entityType: 'dose_event', operation: 'append', entityId: overrides.entityId ?? 'event-1', baseRevision: null, payload: {medicationId: 'medication-1', kind, occurredAt: overrides.occurredAt ?? '2026-07-29T15:34:12Z', occurrence: {contractVersion: 1, occurrenceId, scheduleId, scheduleRevision: 2, scheduledAt: '2026-07-29T15:30:00Z', localDate: '2026-07-29', timezoneId: 'America/Los_Angeles'}}});
}

function assertContractCode(action: () => void, code: string): void {
  assert.throws(action, (error: unknown) => error instanceof MedicationSyncContractError && error.code === code);
}
