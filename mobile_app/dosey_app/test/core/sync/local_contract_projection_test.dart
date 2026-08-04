import 'dart:convert';

import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/sync/domain_contracts.dart';
import 'package:dosey_app/core/sync/local_contract_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const projection = LocalSyncContractProjection();

  group('LocalSyncContractProjection', () {
    test('maps a Snoozed row and preserves mutation identity', () {
      final mutation = projection.project(_row());
      final payload = mutation.payload! as DoseEventMutationPayloadContract;

      expect(mutation.mutationId, 'mutation-1');
      expect(mutation.idempotencyKey, 'idempotency-1');
      expect(mutation.deviceId, 'device-1');
      expect(mutation.entityId, 'opaque-event-1');
      expect(mutation.operation, MutationOperationContract.append);
      expect(mutation.baseRevision, isNull);
      expect(payload.kind, DoseEventKindContract.snoozed);
      expect(payload.medicationId, 'medication-1');
      expect(payload.occurrence.scheduleId, 'schedule-1');
      expect(payload.occurrence.scheduleRevision, 2);
      expect(payload.occurrence.localDate, '2026-07-29');
      expect(payload.occurrence.timezoneId, 'UTC');
      expect(payload.occurredAt, '2026-07-29T15:30:01.123Z');
      expect(payload.occurrence.scheduledAt, '2026-07-29T15:30:00.987Z');
      expect(
        payload.occurrence.occurrenceId,
        'schedule-1:2:2026-07-29T15:30:00.987Z',
      );
      expect(mutation.toJson()['payload'], isNot(contains('profileId')));
    });

    test('maps a Help row and round trips through the v1 contract', () {
      final mutation = projection.project(_row(kind: 'help_requested'));

      expect(
        (mutation.payload! as DoseEventMutationPayloadContract).kind,
        DoseEventKindContract.helpRequested,
      );
      expect(
        MutationContract.fromJson(mutation.toJson()).toJson(),
        mutation.toJson(),
      );
    });

    test(
      'truncates microseconds before rebuilding the occurrence identity',
      () {
        final mutation = projection.project(_row());
        final payload = mutation.payload! as DoseEventMutationPayloadContract;

        expect(payload.occurredAt, '2026-07-29T15:30:01.123Z');
        expect(payload.occurrence.scheduledAt, '2026-07-29T15:30:00.987Z');
        expect(
          payload.occurrence.occurrenceId,
          'schedule-1:2:2026-07-29T15:30:00.987Z',
        );
      },
    );

    test(
      'rejects malformed, non-object, missing, mistyped, and extra payloads',
      () {
        final payloads = <String>[
          '{',
          '[]',
          jsonEncode(_payload()..remove('profileId')),
          jsonEncode({..._payload(), 'kind': 1}),
          jsonEncode({..._payload(), 'unexpected': true}),
          jsonEncode({
            ..._payload(),
            'occurrence': {
              ..._payload()['occurrence']! as Map<String, Object?>,
              'extra': true,
            },
          }),
        ];

        for (final payloadJson in payloads) {
          expect(
            () => projection.project(_row(payloadJson: payloadJson)),
            throwsA(isA<FormatException>()),
            reason: payloadJson,
          );
        }
      },
    );

    test('rejects unsupported kind and mutation shape', () {
      for (final row in <SyncOutboxMutationRow>[
        _row(kind: 'taken_confirmed'),
        _row(entityType: 'schedule'),
        _row(operation: 'upsert'),
        _row(baseRevision: 1),
      ]) {
        expect(() => projection.project(row), throwsA(isA<FormatException>()));
      }
    });

    test('rejects an incoherent raw occurrence tuple', () {
      final payload = _payload();
      final occurrence = payload['occurrence']! as Map<String, Object?>;
      occurrence['occurrenceId'] = 'schedule-1:2:2026-07-29T15:30:00.987Z';

      expect(
        () => projection.project(_row(payloadJson: jsonEncode(payload))),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects local data that the v1 contract rejects', () {
      final payload = _payload();
      (payload['occurrence']! as Map<String, Object?>)['localDate'] =
          '2026-07-28';

      expect(
        () => projection.project(_row(payloadJson: jsonEncode(payload))),
        throwsA(isA<MedicationSyncContractException>()),
      );
    });
  });
}

SyncOutboxMutationRow _row({
  String kind = 'snoozed',
  String entityType = 'dose_event',
  String operation = 'append',
  int? baseRevision,
  String? payloadJson,
}) => SyncOutboxMutationRow(
  mutationId: 'mutation-1',
  deviceId: 'device-1',
  scopeState: 'local_only',
  idempotencyKey: 'idempotency-1',
  entityType: entityType,
  operation: operation,
  entityId: 'opaque-event-1',
  baseRevision: baseRevision,
  payloadJson: payloadJson ?? jsonEncode(_payload(kind: kind)),
  state: 'pending',
  attemptCount: 0,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Map<String, Object?> _payload({String kind = 'snoozed'}) => {
  'medicationId': 'medication-1',
  'profileId': 'profile-1',
  'kind': kind,
  'occurredAt': '2026-07-29T15:30:01.123987Z',
  'occurrence': {
    'occurrenceId': 'schedule-1:2:2026-07-29T15:30:00.987654Z',
    'scheduleId': 'schedule-1',
    'scheduleRevision': 2,
    'scheduledAtUtc': '2026-07-29T15:30:00.987654Z',
    'localDate': '2026-07-29',
    'timezoneId': 'UTC',
  },
};
