import 'dart:convert';
import 'dart:io';

import 'package:dosey_app/core/sync/domain_contracts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    _packageRoot = File.fromUri(Platform.script).parent;
  });

  group('medication sync contract v1', () {
    test('accepts every shared valid fixture', () {
      for (final fixture in _fixtures('valid')) {
        expect(
          () => parseMedicationSyncValue(
            fixture['type']! as String,
            fixture['value'],
          ),
          returnsNormally,
          reason: fixture['name']! as String,
        );
      }
    });

    test('rejects every shared invalid fixture', () {
      for (final fixture in _fixtures('invalid')) {
        expect(
          () => parseMedicationSyncValue(
            fixture['type']! as String,
            fixture['value'],
          ),
          throwsA(isA<MedicationSyncContractException>()),
          reason: fixture['name']! as String,
        );
      }
    });

    test('mirrors the shared canonical timezone artifact exactly', () {
      final file = _repositoryFile(
        'contracts/medication-sync/v1/canonical-timezones.json',
      );
      final document =
          jsonDecode(file.readAsStringSync())! as Map<String, Object?>;

      expect(
        medicationSyncCanonicalTimezones,
        (document['zones']! as List<Object?>).cast<String>().toSet(),
      );
    });

    test('supports every timezone in the shared canonical set', () {
      for (final timezoneId in medicationSyncCanonicalTimezones) {
        expect(
          () => parseMedicationSyncValue('schedule', {
            'contractVersion': 1,
            'id': 'schedule-1',
            'householdId': 'robot-1',
            'medicationId': 'medication-1',
            'label': 'Daily',
            'hour': 8,
            'minute': 30,
            'timezoneId': timezoneId,
            'enabled': true,
            'revision': 1,
            'deletedAt': null,
            'updatedAt': '2026-07-29T08:15:30Z',
          }),
          returnsNormally,
          reason: timezoneId,
        );
      }
    });

    test('orders canonical object keys by UTF-16 code units', () {
      expect(
        canonicalMedicationSyncJson({
          '\uE000': 4,
          '\u{10000}': 3,
          'é': 2,
          'a': 1,
        }),
        '{"a":1,"é":2,"𐀀":3,"":4}',
      );
    });

    test('accepts integral doubles with TypeScript integer semantics', () {
      final schedule = <String, Object?>{
        'contractVersion': 1,
        'id': 'schedule-1',
        'householdId': 'robot-1',
        'medicationId': 'medication-1',
        'label': 'Daily',
        'hour': 1,
        'minute': 30,
        'timezoneId': 'UTC',
        'enabled': true,
        'revision': 1,
        'deletedAt': null,
        'updatedAt': '2026-07-29T08:15:30Z',
      };

      expect(
        MedicationScheduleContract.fromJson({...schedule, 'hour': -0.0}).hour,
        0,
      );
      expect(
        MedicationScheduleContract.fromJson({
          ...schedule,
          'revision': 9007199254740991.0,
        }).revision,
        9007199254740991,
      );
      for (final value in <double>[
        1.5,
        double.nan,
        double.infinity,
        9007199254740992.0,
      ]) {
        expect(
          () => MedicationScheduleContract.fromJson({
            ...schedule,
            'revision': value,
          }),
          throwsA(isA<MedicationSyncContractException>()),
          reason: '$value',
        );
      }
    });

    test('rejects object maps with non-string keys using a contract error', () {
      expect(
        () => parseMedicationSyncValue('medication', <Object?, Object?>{
          1: 'bad',
        }),
        throwsA(
          isA<MedicationSyncContractException>().having(
            (error) => error.code,
            'code',
            'INVALID_TYPE',
          ),
        ),
      );
    });

    test(
      'loads shared fixtures independently of the process working directory',
      () {
        final original = Directory.current;
        final temporary = Directory.systemTemp.createTempSync(
          'dosey-fixtures-',
        );
        try {
          Directory.current = temporary;
          expect(_fixtures('valid'), isNotEmpty);
        } finally {
          Directory.current = original;
          temporary.deleteSync(recursive: true);
        }
      },
    );

    test('converts an ordinary occurrence in every canonical timezone', () {
      for (final timezoneId in medicationSyncCanonicalTimezones) {
        var acceptedLocalDates = 0;
        for (final localDate in const [
          '2026-07-28',
          '2026-07-29',
          '2026-07-30',
        ]) {
          try {
            OccurrenceRefContract.fromJson({
              'contractVersion': 1,
              'occurrenceId': 'schedule-1:1:2026-07-29T12:00:00.000Z',
              'scheduleId': 'schedule-1',
              'scheduleRevision': 1,
              'scheduledAt': '2026-07-29T12:00:00Z',
              'localDate': localDate,
              'timezoneId': timezoneId,
            });
            acceptedLocalDates += 1;
          } on MedicationSyncContractException {
            // Exactly one candidate must match the timezone conversion.
          }
        }
        expect(acceptedLocalDates, 1, reason: timezoneId);
      }
    });

    test('accepts an identical idempotent replay regardless of key order', () {
      final original = MutationContract.fromJson({
        'contractVersion': 1,
        'mutationId': 'mutation-1',
        'deviceId': 'android-1',
        'idempotencyKey': 'android-1:mutation-1',
        'entityType': 'medication',
        'operation': 'upsert',
        'entityId': 'medication-1',
        'baseRevision': null,
        'payload': {
          'name': 'Morning pill',
          'pillType': 'pill',
          'instructions': null,
        },
      });
      final replay = MutationContract.fromJson({
        'payload': {
          'instructions': null,
          'pillType': 'pill',
          'name': 'Morning pill',
        },
        'baseRevision': null,
        'entityId': 'medication-1',
        'operation': 'upsert',
        'entityType': 'medication',
        'idempotencyKey': 'android-1:mutation-1',
        'deviceId': 'android-1',
        'mutationId': 'mutation-1',
        'contractVersion': 1,
      });

      expect(
        () => assertMatchingIdempotentReplay(
          'robot-1',
          original,
          'robot-1',
          replay,
        ),
        returnsNormally,
      );
    });

    test('rejects reuse of an idempotency key with a changed payload', () {
      final original = MutationContract.fromJson({
        'contractVersion': 1,
        'mutationId': 'mutation-1',
        'deviceId': 'android-1',
        'idempotencyKey': 'android-1:mutation-1',
        'entityType': 'medication',
        'operation': 'upsert',
        'entityId': 'medication-1',
        'baseRevision': null,
        'payload': {
          'name': 'Morning pill',
          'pillType': 'pill',
          'instructions': null,
        },
      });
      final changedJson = original.toJson();
      changedJson['payload'] = {
        ...changedJson['payload']! as Map<String, Object?>,
        'name': 'Changed pill',
      };
      final changed = MutationContract.fromJson(changedJson);

      expect(
        () => assertMatchingIdempotentReplay(
          'robot-1',
          original,
          'robot-1',
          changed,
        ),
        throwsA(
          isA<MedicationSyncContractException>().having(
            (error) => error.code,
            'code',
            'IDEMPOTENCY_KEY_REUSED',
          ),
        ),
      );
    });

    test('scopes idempotent replay identity to one robot', () {
      final mutation = MutationContract.fromJson({
        'contractVersion': 1,
        'mutationId': 'mutation-1',
        'deviceId': 'android-1',
        'idempotencyKey': 'android-1:mutation-1',
        'entityType': 'medication',
        'operation': 'delete',
        'entityId': 'medication-1',
        'baseRevision': 1,
        'payload': null,
      });

      expect(
        () => assertMatchingIdempotentReplay(
          'robot-1',
          mutation,
          'robot-2',
          mutation,
        ),
        throwsA(
          isA<MedicationSyncContractException>().having(
            (error) => error.code,
            'code',
            'IDEMPOTENCY_SCOPE_MISMATCH',
          ),
        ),
      );
    });

    test('normalizes scheduledAt before deriving occurrence identity', () {
      final occurrence = OccurrenceRefContract.fromJson({
        'contractVersion': 1,
        'occurrenceId': 'schedule-1:2:2026-07-29T15:30:00.000Z',
        'scheduleId': 'schedule-1',
        'scheduleRevision': 2,
        'scheduledAt': '2026-07-29T15:30:00Z',
        'localDate': '2026-07-29',
        'timezoneId': 'America/Los_Angeles',
      });

      expect(occurrence.scheduledAt, '2026-07-29T15:30:00.000Z');
    });

    test('typed occurrence serialization is canonical and stable', () {
      const occurrence = OccurrenceRefContract(
        occurrenceId: 'schedule-1:2:2026-07-29T15:30:00.000Z',
        scheduleId: 'schedule-1',
        scheduleRevision: 2,
        scheduledAt: '2026-07-29T15:30:00Z',
        localDate: '2026-07-29',
        timezoneId: 'America/Los_Angeles',
      );

      final first = occurrence.toJson();
      final second = OccurrenceRefContract.fromJson(first).toJson();

      expect(first, second);
      expect(first['scheduledAt'], '2026-07-29T15:30:00.000Z');
    });

    test('normalizes reconstructed mutation JSON through the public API', () {
      final fixture = _fixtures('valid').firstWhere(
        (entry) => entry['name'] == 'append explicit dose event mutation',
      );
      final input = fixture['value']! as Map<String, Object?>;

      final first = normalizeMedicationSyncMutationJson(input);
      final second = normalizeMedicationSyncMutationJson(first);

      expect(first, second);
      expect(
        ((first['payload']! as Map<String, Object?>)['occurrence']!
            as Map<String, Object?>)['scheduledAt'],
        '2026-07-29T15:30:00.000Z',
      );
    });

    test('does not serialize a parser-invalid typed mutation', () {
      const mutation = MutationContract(
        mutationId: 'mutation-1',
        deviceId: 'android-1',
        idempotencyKey: 'android-1:mutation-1',
        entityType: EntityTypeContract.medication,
        operation: MutationOperationContract.append,
        entityId: 'medication-1',
        baseRevision: null,
        payload: null,
      );

      expect(mutation.toJson, throwsA(isA<MedicationSyncContractException>()));
    });

    test('every public serializer rejects parser-invalid typed state', () {
      const occurrence = OccurrenceRefContract(
        occurrenceId: 'schedule-1:1:2026-07-29T15:30:00.000Z',
        scheduleId: 'schedule-1',
        scheduleRevision: 1,
        scheduledAt: '2026-07-29T15:30:00Z',
        localDate: '2026-07-29',
        timezoneId: 'America/Los_Angeles',
      );
      const medication = MedicationContract(
        id: 'medication-1',
        householdId: 'robot-1',
        name: 'Morning pill',
        pillType: PillTypeContract.pill,
        instructions: null,
        revision: 2,
        deletedAt: null,
        updatedAt: '2026-07-29T08:15:30Z',
      );
      const conflict = ConflictContract(
        entityType: EntityTypeContract.medication,
        entityId: 'medication-1',
        expectedRevision: 1,
        actualRevision: 2,
        authoritativeRecord: medication,
      );

      final invalidSerializers = <String, Map<String, Object?> Function()>{
        'medication': () => const MedicationContract(
          id: ' ',
          householdId: 'robot-1',
          name: 'Morning pill',
          pillType: PillTypeContract.pill,
          instructions: null,
          revision: 1,
          deletedAt: null,
          updatedAt: '2026-07-29T08:15:30Z',
        ).toJson(),
        'schedule': () => const MedicationScheduleContract(
          id: 'schedule-1',
          householdId: 'robot-1',
          medicationId: 'medication-1',
          label: 'Daily',
          hour: 24,
          minute: 0,
          timezoneId: 'UTC',
          enabled: true,
          revision: 1,
          deletedAt: null,
          updatedAt: '2026-07-29T08:15:30Z',
        ).toJson(),
        'occurrence': () => const OccurrenceRefContract(
          occurrenceId: 'bad',
          scheduleId: 'schedule-1',
          scheduleRevision: 1,
          scheduledAt: '2026-07-29T15:30:00Z',
          localDate: '2026-07-29',
          timezoneId: 'America/Los_Angeles',
        ).toJson(),
        'dose event': () => const DoseEventContract(
          id: 'event-1',
          householdId: 'robot-1',
          medicationId: 'medication-1',
          occurrence: occurrence,
          kind: DoseEventKindContract.takenConfirmed,
          occurredAt: '2026-07-29T15:34:12+00:00',
          actorAccountId: 'account-1',
        ).toJson(),
        'medication payload': () => const MedicationMutationPayloadContract(
          name: ' ',
          pillType: PillTypeContract.pill,
          instructions: null,
        ).toJson(),
        'schedule payload': () => const ScheduleMutationPayloadContract(
          medicationId: 'medication-1',
          label: 'Daily',
          hour: 24,
          minute: 0,
          timezoneId: 'UTC',
          enabled: true,
        ).toJson(),
        'dose event payload': () => const DoseEventMutationPayloadContract(
          medicationId: 'medication-1',
          occurrence: occurrence,
          kind: DoseEventKindContract.takenConfirmed,
          occurredAt: '2026-07-29T15:34:12+00:00',
        ).toJson(),
        'mutation': () => const MutationContract(
          mutationId: 'mutation-1',
          deviceId: 'android-1',
          idempotencyKey: 'android-1:mutation-1',
          entityType: EntityTypeContract.medication,
          operation: MutationOperationContract.append,
          entityId: 'medication-1',
          baseRevision: null,
          payload: null,
        ).toJson(),
        'conflict': () => const ConflictContract(
          entityType: EntityTypeContract.medication,
          entityId: 'medication-1',
          expectedRevision: 2,
          actualRevision: 2,
          authoritativeRecord: medication,
        ).toJson(),
        'ack': () => const MutationAckContract(
          mutationId: 'mutation-1',
          outcome: MutationOutcomeContract.applied,
          revision: 1,
          cursor: null,
          errorCode: null,
          conflict: null,
        ).toJson(),
        'pull change': () => const PullChangeContract(
          cursor: '01',
          entityType: EntityTypeContract.medication,
          entityId: 'medication-1',
          operation: MutationOperationContract.upsert,
          record: medication,
        ).toJson(),
        'pull page': () => const PullPageContract(
          robotId: 'robot-1',
          cursor: '1',
          checkpoint: '3',
          nextCursor: '2',
          hasMore: false,
          changes: [],
        ).toJson(),
        'push request': () => const MedicationSyncPushRequest(
          robotId: ' ',
          operations: [],
        ).toJson(),
        'push response': () => const MedicationSyncPushResponse(
          robotId: 'robot-2',
          acknowledgements: [
            MutationAckContract(
              mutationId: 'mutation-1',
              outcome: MutationOutcomeContract.conflict,
              revision: null,
              cursor: null,
              errorCode: null,
              conflict: conflict,
            ),
          ],
        ).toJson(),
        'pull request': () => const MedicationSyncPullRequest(
          robotId: 'robot-1',
          cursor: null,
          checkpoint: '3',
          limit: 100,
        ).toJson(),
      };

      for (final MapEntry(key: name, value: serialize)
          in invalidSerializers.entries) {
        expect(
          serialize,
          throwsA(isA<MedicationSyncContractException>()),
          reason: name,
        );
      }
    });

    test('idempotent replay normalizes equivalent occurredAt spellings', () {
      final fixture = _fixtures('valid').firstWhere(
        (entry) => entry['name'] == 'append explicit dose event mutation',
      );
      final originalJson = fixture['value']! as Map<String, Object?>;
      final payload = originalJson['payload']! as Map<String, Object?>;
      final replayJson = <String, Object?>{
        ...originalJson,
        'payload': {...payload, 'occurredAt': '2026-07-29T15:34:12.000Z'},
      };

      expect(
        () => assertMatchingIdempotentReplay(
          'robot-1',
          MutationContract.fromJson(originalJson),
          'robot-1',
          MutationContract.fromJson(replayJson),
        ),
        returnsNormally,
      );
    });

    test('wire enum exposes only explicit synced dose actions', () {
      expect(DoseEventKindContract.values.map((kind) => kind.wireValue), [
        'taken_confirmed',
        'skipped',
        'missed',
        'snoozed',
        'help_requested',
      ]);
    });

    test('classifies exactly the three terminal dose event kinds', () {
      for (final kind in const ['taken_confirmed', 'skipped', 'missed']) {
        expect(isTerminalDoseEventMutation(_terminalMutation(kind)), isTrue);
      }
      expect(
        isTerminalDoseEventMutation(_terminalMutation('snoozed')),
        isFalse,
      );
      expect(
        isTerminalDoseEventMutation(_terminalMutation('help_requested')),
        isFalse,
      );
    });

    test('requires terminal mutations for authority decisions', () {
      final terminal = _terminalMutation('missed');
      final ownerDecision = evaluateTerminalOutcomeAuthority(
        const MedicationSyncActorContract(
          accountId: 'owner-1',
          authority: MedicationSyncActorAuthority.human,
          registeredDeviceId: null,
          role: HouseholdRoleContract.owner,
        ),
        terminal,
      );
      final caregiverDecision = evaluateTerminalOutcomeAuthority(
        const MedicationSyncActorContract(
          accountId: 'caregiver-1',
          authority: MedicationSyncActorAuthority.human,
          registeredDeviceId: null,
          role: HouseholdRoleContract.member,
        ),
        terminal,
      );
      final deviceDecision = evaluateTerminalOutcomeAuthority(
        const MedicationSyncActorContract(
          accountId: 'device-account-1',
          authority: MedicationSyncActorAuthority.patientDevice,
          registeredDeviceId: 'patient-device-1',
          role: null,
        ),
        terminal,
      );
      final mismatchedDecision = evaluateTerminalOutcomeAuthority(
        const MedicationSyncActorContract(
          accountId: 'device-1',
          authority: MedicationSyncActorAuthority.patientDevice,
          registeredDeviceId: 'patient-device-2',
          role: null,
        ),
        terminal,
      );
      final missingDecision = evaluateTerminalOutcomeAuthority(
        const MedicationSyncActorContract(
          accountId: 'device-1',
          authority: MedicationSyncActorAuthority.patientDevice,
          registeredDeviceId: null,
          role: null,
        ),
        terminal,
      );
      expect(ownerDecision.errorCode, 'HUMAN_TERMINAL_OUTCOME_FORBIDDEN');
      expect(caregiverDecision.errorCode, 'HUMAN_TERMINAL_OUTCOME_FORBIDDEN');
      expect(deviceDecision.outcome, MutationAuthorityOutcome.allowed);
      expect(mismatchedDecision.errorCode, 'DEVICE_IDENTITY_MISMATCH');
      expect(missingDecision.errorCode, 'PATIENT_DEVICE_AUTHORITY_REQUIRED');
      expect(
        () => evaluateTerminalOutcomeAuthority(
          const MedicationSyncActorContract(
            accountId: 'owner-1',
            authority: MedicationSyncActorAuthority.human,
            registeredDeviceId: null,
            role: HouseholdRoleContract.owner,
          ),
          _terminalMutation('snoozed'),
        ),
        _contractCode('TERMINAL_OUTCOME_REQUIRED'),
      );
    });

    test('resolves terminal outcomes deterministically per occurrence', () {
      final taken = _terminalMutation('taken_confirmed');
      expect(resolveTerminalOutcome(taken, taken).outcome, 'duplicate');
      expect(
        resolveTerminalOutcome(
          taken,
          _terminalMutation('taken_confirmed', entityId: 'event-2'),
        ).errorCode,
        'TERMINAL_OUTCOME_REPLAY_MISMATCH',
      );
      expect(
        resolveTerminalOutcome(
          taken,
          _terminalMutation(
            'taken_confirmed',
            occurredAt: '2026-07-29T15:35:12Z',
          ),
        ).errorCode,
        'TERMINAL_OUTCOME_REPLAY_MISMATCH',
      );
      for (final pair in const [
        ['taken_confirmed', 'skipped'],
        ['taken_confirmed', 'missed'],
        ['skipped', 'missed'],
      ]) {
        expect(
          resolveTerminalOutcome(
            _terminalMutation(pair[0]),
            _terminalMutation(pair[1]),
          ).errorCode,
          'TERMINAL_OUTCOME_CONFLICT',
        );
      }
      expect(
        () => resolveTerminalOutcome(
          taken,
          _terminalMutation(
            'missed',
            occurrenceId: 'schedule-2:2:2026-07-29T15:30:00.000Z',
          ),
        ),
        _contractCode('TERMINAL_OUTCOME_OCCURRENCE_MISMATCH'),
      );
      expect(
        () => resolveTerminalOutcome(taken, _terminalMutation('snoozed')),
        _contractCode('TERMINAL_OUTCOME_REQUIRED'),
      );
      expect(
        () => resolveTerminalOutcome(
          _terminalMutation('help_requested'),
          _terminalMutation('help_requested'),
        ),
        _contractCode('TERMINAL_OUTCOME_REQUIRED'),
      );
    });
  });
}

List<Map<String, Object?>> _fixtures(String name) {
  final file = _repositoryFile(
    'contracts/medication-sync/v1/fixtures/$name.json',
  );
  final document = jsonDecode(file.readAsStringSync())! as Map<String, Object?>;
  return (document['cases']! as List<Object?>)
      .cast<Map<String, Object?>>()
      .toList(growable: false);
}

late final Directory _packageRoot;

File _repositoryFile(String relativePath) =>
    File('${_packageRoot.parent.parent.path}/$relativePath');

MutationContract _terminalMutation(
  String kind, {
  String entityId = 'event-1',
  String occurredAt = '2026-07-29T15:34:12Z',
  String occurrenceId = 'schedule-1:2:2026-07-29T15:30:00.000Z',
}) => MutationContract.fromJson({
  'contractVersion': 1,
  'mutationId': 'terminal-1',
  'deviceId': 'patient-device-1',
  'idempotencyKey': 'patient-device-1:terminal-1',
  'entityType': 'dose_event',
  'operation': 'append',
  'entityId': entityId,
  'baseRevision': null,
  'payload': {
    'medicationId': 'medication-1',
    'kind': kind,
    'occurredAt': occurredAt,
    'occurrence': {
      'contractVersion': 1,
      'occurrenceId': occurrenceId,
      'scheduleId': occurrenceId.startsWith('schedule-2:')
          ? 'schedule-2'
          : 'schedule-1',
      'scheduleRevision': 2,
      'scheduledAt': '2026-07-29T15:30:00Z',
      'localDate': '2026-07-29',
      'timezoneId': 'America/Los_Angeles',
    },
  },
});

Matcher _contractCode(String code) => throwsA(
  isA<MedicationSyncContractException>().having(
    (error) => error.code,
    'code',
    code,
  ),
);
