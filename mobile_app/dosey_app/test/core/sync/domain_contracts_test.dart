import 'dart:convert';
import 'dart:io';

import 'package:dosey_app/core/sync/domain_contracts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      final file = File(
        '../../contracts/medication-sync/v1/canonical-timezones.json',
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
        'snoozed',
        'help_requested',
      ]);
    });
  });
}

List<Map<String, Object?>> _fixtures(String name) {
  final file = File('../../contracts/medication-sync/v1/fixtures/$name.json');
  final document = jsonDecode(file.readAsStringSync())! as Map<String, Object?>;
  return (document['cases']! as List<Object?>)
      .cast<Map<String, Object?>>()
      .toList(growable: false);
}
