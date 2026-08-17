import 'dart:async';
import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:dosey_app/core/caregiver/appwrite_caregiver_sync_gateway.dart';
import 'package:dosey_app/core/caregiver/caregiver_snapshot.dart';
import 'package:dosey_app/core/caregiver/caregiver_snapshot_controller.dart';
import 'package:dosey_app/core/caregiver/caregiver_status_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'pull follows the stable checkpoint and builds an authoritative snapshot',
    () async {
      final api = _FakeMedicationSyncFunctionsApi([
        MedicationSyncFunctionResponse(
          statusCode: 200,
          body: jsonEncode(
            _pullPage(
              cursor: null,
              checkpoint: '2',
              nextCursor: '1',
              hasMore: true,
              changes: [_medicationChange()],
            ),
          ),
        ),
        MedicationSyncFunctionResponse(
          statusCode: 200,
          body: jsonEncode(
            _pullPage(
              cursor: '1',
              checkpoint: '2',
              nextCursor: '2',
              hasMore: false,
              changes: [_scheduleChange()],
            ),
          ),
        ),
      ]);
      final gateway = AppwriteCaregiverSyncGateway(
        api,
        pushFunctionId: 'medication-push',
        pullFunctionId: 'medication-pull',
        deviceId: 'web-device',
        newId: () => 'unused',
        now: () => DateTime.utc(2026, 7, 29, 12),
      );

      final result = await gateway.pull('robot-1');

      expect(api.calls.map((call) => call.functionId), [
        'medication-pull',
        'medication-pull',
      ]);
      expect(jsonDecode(api.calls.first.body), {
        'contractVersion': 1,
        'robotId': 'robot-1',
        'cursor': null,
        'checkpoint': null,
        'limit': 100,
      });
      expect(jsonDecode(api.calls.last.body), {
        'contractVersion': 1,
        'robotId': 'robot-1',
        'cursor': '1',
        'checkpoint': '2',
        'limit': 100,
      });
      expect(result.cursor, '2');
      expect(result.checkpoint, '2');
      expect(result.snapshot.householdId, 'robot-1');
      expect(result.snapshot.revision, '2');
      expect(result.snapshot.medications.single.name, 'Aspirin');
      expect(
        result.snapshot.medications.single.pillType,
        CaregiverPillType.tablet,
      );
      expect(result.snapshot.schedules.single.timezoneId, 'UTC');
    },
  );

  test('pull applies tombstones to previously cached records', () async {
    final api = _FakeMedicationSyncFunctionsApi([
      MedicationSyncFunctionResponse(
        statusCode: 200,
        body: jsonEncode(
          _pullPage(
            cursor: null,
            checkpoint: '2',
            nextCursor: '2',
            hasMore: false,
            changes: [
              _medicationChange(),
              _medicationChange(deleted: true, cursor: '2'),
            ],
          ),
        ),
      ),
    ]);
    final gateway = _gateway(api);

    final result = await gateway.pull('robot-1');

    expect(result.snapshot.medications, isEmpty);
    expect(result.cursor, '2');
  });

  test(
    'pull preserves the authoritative occurrence identity and revision',
    () async {
      final api = _FakeMedicationSyncFunctionsApi([
        MedicationSyncFunctionResponse(
          statusCode: 200,
          body: jsonEncode(
            _pullPage(
              cursor: null,
              checkpoint: '1',
              nextCursor: '1',
              hasMore: false,
              changes: [_doseEventChange()],
            ),
          ),
        ),
      ]);

      final result = await _gateway(api).pull('robot-1');

      final event = result.snapshot.events.single;
      expect(event.occurrenceId, 'schedule-1:7:2026-07-29T09:00:00.000Z');
      expect(event.scheduleRevision, 7);
    },
  );

  test('pull rejects a contract-valid missed dose event safely', () async {
    final api = _FakeMedicationSyncFunctionsApi([
      MedicationSyncFunctionResponse(
        statusCode: 200,
        body: jsonEncode(
          _pullPage(
            cursor: null,
            checkpoint: '1',
            nextCursor: '1',
            hasMore: false,
            changes: [_doseEventChange(kind: 'missed')],
          ),
        ),
      ),
    ]);

    await expectLater(
      _gateway(api).pull('robot-1'),
      throwsA(
        isA<CaregiverSyncException>().having(
          (error) => error.message,
          'message',
          'This app cannot display missed dose outcomes yet.',
        ),
      ),
    );
  });

  test('pull cache is isolated when the signed-in account changes', () async {
    final api = _FakeMedicationSyncFunctionsApi([
      MedicationSyncFunctionResponse(
        statusCode: 200,
        body: jsonEncode(
          _pullPage(
            cursor: null,
            checkpoint: '1',
            nextCursor: '1',
            hasMore: false,
            changes: [_medicationChange()],
          ),
        ),
      ),
      MedicationSyncFunctionResponse(
        statusCode: 200,
        body: jsonEncode(
          _pullPage(
            cursor: null,
            checkpoint: '2',
            nextCursor: '2',
            hasMore: false,
            changes: const [],
          ),
        ),
      ),
    ]);
    final gateway = _gateway(api);

    final first = await gateway.pull('robot-1');
    api.accountId = 'account-2';
    final second = await gateway.pull('robot-1');

    expect(first.snapshot.medications, hasLength(1));
    expect(second.snapshot.medications, isEmpty);
  });

  test('an older concurrent pull cannot overwrite the newer cache', () async {
    final firstResponse = Completer<MedicationSyncFunctionResponse>();
    final secondResponse = Completer<MedicationSyncFunctionResponse>();
    final api = _DeferredMedicationSyncFunctionsApi([
      firstResponse,
      secondResponse,
    ]);
    final gateway = _gateway(api);

    final olderPull = gateway.pull('robot-1');
    final newerPull = gateway.pull('robot-1');
    secondResponse.complete(
      MedicationSyncFunctionResponse(
        statusCode: 200,
        body: jsonEncode(
          _pullPage(
            cursor: null,
            checkpoint: '2',
            nextCursor: '2',
            hasMore: false,
            changes: [_medicationChange(cursor: '2', name: 'New')],
          ),
        ),
      ),
    );
    await newerPull;
    firstResponse.complete(
      MedicationSyncFunctionResponse(
        statusCode: 200,
        body: jsonEncode(
          _pullPage(
            cursor: null,
            checkpoint: '1',
            nextCursor: '1',
            hasMore: false,
            changes: [_medicationChange(name: 'Old')],
          ),
        ),
      ),
    );
    await olderPull;
    api.responses.add(
      Completer<MedicationSyncFunctionResponse>()..complete(
        MedicationSyncFunctionResponse(
          statusCode: 200,
          body: jsonEncode(
            _pullPage(
              cursor: '2',
              checkpoint: '2',
              nextCursor: '2',
              hasMore: false,
              changes: const [],
            ),
          ),
        ),
      ),
    );

    final continued = await gateway.pull(
      'robot-1',
      cursor: '2',
      checkpoint: '2',
    );

    expect(continued.snapshot.medications.single.name, 'New');
  });

  test('pull rejects a page bound to a different robot', () async {
    final api = _FakeMedicationSyncFunctionsApi([
      MedicationSyncFunctionResponse(
        statusCode: 200,
        body: jsonEncode({
          ..._pullPage(
            cursor: null,
            checkpoint: '0',
            nextCursor: '0',
            hasMore: false,
            changes: const [],
          ),
          'robotId': 'robot-2',
        }),
      ),
    ]);

    await expectLater(
      _gateway(api).pull('robot-1'),
      throwsA(
        isA<CaregiverSyncException>().having(
          (error) => error.message,
          'message',
          'Medication data returned an invalid response.',
        ),
      ),
    );
  });

  test(
    'push emits complete mutation identities and authoritative payloads',
    () async {
      var sequence = 0;
      final api = _FakeMedicationSyncFunctionsApi([
        MedicationSyncFunctionResponse(
          statusCode: 200,
          body: jsonEncode({
            'contractVersion': 1,
            'robotId': 'robot-1',
            'acknowledgements': [
              {
                'contractVersion': 1,
                'mutationId': 'generated-1',
                'outcome': 'applied',
                'revision': 4,
                'cursor': '9',
                'errorCode': null,
                'conflict': null,
              },
            ],
          }),
        ),
      ]);
      final gateway = AppwriteCaregiverSyncGateway(
        api,
        pushFunctionId: 'medication-push',
        pullFunctionId: 'medication-pull',
        deviceId: 'web-device',
        newId: () => 'generated-${++sequence}',
        now: () => DateTime.utc(2026, 7, 29, 12),
      );

      await gateway.push('robot-1', [
        CaregiverMutation.upsertMedication(
          CaregiverMedication(
            id: 'medication-1',
            name: 'Aspirin',
            instructions: 'With water',
            pillType: CaregiverPillType.tablet,
            active: true,
            version: 3,
          ),
        ),
      ]);

      expect(api.calls.single.functionId, 'medication-push');
      expect(jsonDecode(api.calls.single.body), {
        'contractVersion': 1,
        'robotId': 'robot-1',
        'operations': [
          {
            'contractVersion': 1,
            'mutationId': 'generated-1',
            'deviceId': 'web-device',
            'idempotencyKey': 'web-device:generated-1',
            'entityType': 'medication',
            'operation': 'upsert',
            'entityId': 'medication-1',
            'baseRevision': 3,
            'payload': {
              'name': 'Aspirin',
              'pillType': 'tablet',
              'instructions': 'With water',
            },
          },
        ],
      });
    },
  );

  test(
    'push passes through the projected immutable occurrence unchanged',
    () async {
      var sequence = 0;
      final api = _FakeMedicationSyncFunctionsApi([
        MedicationSyncFunctionResponse(
          statusCode: 200,
          body: jsonEncode(
            _pullPage(
              cursor: null,
              checkpoint: '2',
              nextCursor: '2',
              hasMore: false,
              changes: [_medicationChange(), _scheduleChange()],
            ),
          ),
        ),
        MedicationSyncFunctionResponse(
          statusCode: 200,
          body: jsonEncode({
            'contractVersion': 1,
            'robotId': 'robot-1',
            'acknowledgements': [
              {
                'contractVersion': 1,
                'mutationId': 'generated-1',
                'outcome': 'applied',
                'revision': null,
                'cursor': '10',
                'errorCode': null,
                'conflict': null,
              },
            ],
          }),
        ),
      ]);
      final gateway = AppwriteCaregiverSyncGateway(
        api,
        pushFunctionId: 'medication-push',
        pullFunctionId: 'medication-pull',
        deviceId: 'web-device',
        newId: () => 'generated-${++sequence}',
        now: () => DateTime.utc(2026, 7, 29, 12, 5),
      );
      await gateway.pull('robot-1');

      await gateway.push('robot-1', [
        CaregiverMutation.recordDose(
          occurrence: CaregiverOccurrence(
            occurrenceId: 'schedule-1:7:2026-07-29T09:00:00.000Z',
            scheduleId: 'schedule-1',
            scheduleRevision: 7,
            scheduledFor: DateTime.utc(2026, 7, 29, 9),
            timezoneId: 'UTC',
            localDate: '2026-07-29',
          ),
          action: CaregiverDoseAction.helpRequested,
        ),
      ]);

      final operation =
          (jsonDecode(api.calls.last.body)
                  as Map<String, dynamic>)['operations']
              as List<dynamic>;
      expect(operation.single, {
        'contractVersion': 1,
        'mutationId': 'generated-1',
        'deviceId': 'web-device',
        'idempotencyKey': 'web-device:generated-1',
        'entityType': 'dose_event',
        'operation': 'append',
        'entityId': 'generated-2',
        'baseRevision': null,
        'payload': {
          'medicationId': 'medication-1',
          'occurrence': {
            'contractVersion': 1,
            'occurrenceId': 'schedule-1:7:2026-07-29T09:00:00.000Z',
            'scheduleId': 'schedule-1',
            'scheduleRevision': 7,
            'scheduledAt': '2026-07-29T09:00:00.000Z',
            'localDate': '2026-07-29',
            'timezoneId': 'UTC',
          },
          'kind': 'help_requested',
          'occurredAt': '2026-07-29T12:05:00.000Z',
        },
      });
    },
  );

  test(
    'push rejects duplicate generated mutation identities before calling',
    () async {
      final api = _FakeMedicationSyncFunctionsApi([]);
      final gateway = AppwriteCaregiverSyncGateway(
        api,
        pushFunctionId: 'medication-push',
        pullFunctionId: 'medication-pull',
        deviceId: 'web-device',
        newId: () => 'duplicate-id',
        now: () => DateTime.utc(2026, 7, 29, 12),
      );

      await expectLater(
        gateway.push('robot-1', [
          _medicationMutation('medication-1'),
          _medicationMutation('medication-2'),
        ]),
        throwsA(
          isA<CaregiverSyncException>().having(
            (error) => error.message,
            'message',
            'Medication change is invalid.',
          ),
        ),
      );

      expect(api.calls, isEmpty);
    },
  );

  test('push rejects an unexpected acknowledgement identity', () async {
    final api = _FakeMedicationSyncFunctionsApi([
      MedicationSyncFunctionResponse(
        statusCode: 200,
        body: jsonEncode({
          'contractVersion': 1,
          'robotId': 'robot-1',
          'acknowledgements': [_pushAcknowledgement('unexpected-id')],
        }),
      ),
    ]);

    await expectLater(
      _gateway(api).push('robot-1', [_medicationMutation('medication-1')]),
      throwsA(isA<CaregiverSyncException>()),
    );

    expect(api.calls, hasLength(1));
  });

  test('push rejects duplicate acknowledgement identities', () async {
    var sequence = 0;
    final api = _FakeMedicationSyncFunctionsApi([
      MedicationSyncFunctionResponse(
        statusCode: 200,
        body: jsonEncode({
          'contractVersion': 1,
          'robotId': 'robot-1',
          'acknowledgements': [
            _pushAcknowledgement('mutation-1'),
            _pushAcknowledgement('mutation-1'),
          ],
        }),
      ),
    ]);
    final gateway = AppwriteCaregiverSyncGateway(
      api,
      pushFunctionId: 'medication-push',
      pullFunctionId: 'medication-pull',
      deviceId: 'web-device',
      newId: () => 'mutation-${++sequence}',
      now: () => DateTime.utc(2026, 7, 29, 12),
    );

    await expectLater(
      gateway.push('robot-1', [
        _medicationMutation('medication-1'),
        _medicationMutation('medication-2'),
      ]),
      throwsA(isA<CaregiverSyncException>()),
    );

    expect(api.calls, hasLength(1));
  });

  test(
    'push accepts complete unique acknowledgements for multiple operations',
    () async {
      var sequence = 0;
      final api = _FakeMedicationSyncFunctionsApi([
        MedicationSyncFunctionResponse(
          statusCode: 200,
          body: jsonEncode({
            'contractVersion': 1,
            'robotId': 'robot-1',
            'acknowledgements': [
              _pushAcknowledgement('mutation-1'),
              {..._pushAcknowledgement('mutation-2'), 'outcome': 'duplicate'},
            ],
          }),
        ),
      ]);
      final gateway = AppwriteCaregiverSyncGateway(
        api,
        pushFunctionId: 'medication-push',
        pullFunctionId: 'medication-pull',
        deviceId: 'web-device',
        newId: () => 'mutation-${++sequence}',
        now: () => DateTime.utc(2026, 7, 29, 12),
      );

      await gateway.push('robot-1', [
        _medicationMutation('medication-1'),
        _medicationMutation('medication-2'),
      ]);

      expect(api.calls, hasLength(1));
    },
  );

  test(
    'push fails closed when the cached schedule changed after projection',
    () async {
      final api = _FakeMedicationSyncFunctionsApi([
        MedicationSyncFunctionResponse(
          statusCode: 200,
          body: jsonEncode(
            _pullPage(
              cursor: null,
              checkpoint: '2',
              nextCursor: '2',
              hasMore: false,
              changes: [_medicationChange(), _scheduleChange()],
            ),
          ),
        ),
      ]);
      final gateway = _gateway(api);
      await gateway.pull('robot-1');
      final staleOccurrence = projectCaregiverDay(
        snapshot: CaregiverSnapshot(
          householdId: 'robot-1',
          revision: '0',
          generatedAt: DateTime.utc(2026, 7, 29),
          medications: [
            CaregiverMedication(
              id: 'medication-1',
              name: 'Aspirin',
              instructions: '',
              active: true,
              version: 1,
            ),
          ],
          schedules: [
            CaregiverSchedule(
              id: 'schedule-1',
              medicationId: 'medication-1',
              label: 'Morning',
              hour: 9,
              minute: 0,
              enabled: true,
              version: 6,
            ),
          ],
          events: const [],
        ),
        now: DateTime.utc(2026, 7, 29, 8),
      ).single.occurrence;

      await expectLater(
        gateway.push('robot-1', [
          CaregiverMutation.recordDose(
            occurrence: staleOccurrence,
            action: CaregiverDoseAction.taken,
          ),
        ]),
        throwsA(isA<CaregiverSyncException>()),
      );

      expect(api.calls, hasLength(1));
    },
  );

  test(
    'successful pull rejects an account change before parsing or caching',
    () async {
      final api = _FakeMedicationSyncFunctionsApi(
        [
          MedicationSyncFunctionResponse(
            statusCode: 200,
            body: jsonEncode(
              _pullPage(
                cursor: null,
                checkpoint: '1',
                nextCursor: '1',
                hasMore: false,
                changes: [_medicationChange()],
              ),
            ),
          ),
        ],
        accountResults: ['account-a', 'account-b'],
      );

      await expectLater(
        _gateway(api).pull('robot-1'),
        throwsA(isA<CaregiverSyncException>()),
      );
      expect(api.calls, hasLength(1));
    },
  );

  test(
    'account-changed successful pull leaves the initiating cache untouched',
    () async {
      final api = _FakeMedicationSyncFunctionsApi(
        [
          MedicationSyncFunctionResponse(
            statusCode: 200,
            body: jsonEncode(
              _pullPage(
                cursor: null,
                checkpoint: '1',
                nextCursor: '1',
                hasMore: false,
                changes: [_medicationChange()],
              ),
            ),
          ),
          MedicationSyncFunctionResponse(
            statusCode: 200,
            body: jsonEncode(
              _pullPage(
                cursor: '1',
                checkpoint: '1',
                nextCursor: '1',
                hasMore: false,
                changes: const [],
              ),
            ),
          ),
        ],
        accountResults: ['account-a', 'account-b'],
      );
      final gateway = _gateway(api);

      await expectLater(
        gateway.pull('robot-1'),
        throwsA(isA<CaregiverSyncException>()),
      );
      api.accountId = 'account-a';
      final result = await gateway.pull(
        'robot-1',
        cursor: '1',
        checkpoint: '1',
      );

      expect(result.snapshot.medications, isEmpty);
    },
  );

  test(
    'successful push rejects an account change before acknowledging',
    () async {
      final api = _FakeMedicationSyncFunctionsApi(
        [
          MedicationSyncFunctionResponse(
            statusCode: 200,
            body: jsonEncode({
              'contractVersion': 1,
              'robotId': 'robot-1',
              'acknowledgements': [_pushAcknowledgement('mutation-1')],
            }),
          ),
        ],
        accountResults: ['account-a', 'account-b'],
      );

      await expectLater(
        _gateway(api).push('robot-1', [
          CaregiverMutation.upsertMedication(
            CaregiverMedication(
              id: 'med-1',
              name: 'Morning tablet',
              instructions: '',
              active: true,
              version: 0,
            ),
          ),
        ]),
        throwsA(isA<CaregiverSyncException>()),
      );
      expect(api.calls, hasLength(1));
    },
  );

  test('push surfaces conflicts and safe rejection codes', () async {
    final conflictApi = _FakeMedicationSyncFunctionsApi([
      MedicationSyncFunctionResponse(
        statusCode: 200,
        body: jsonEncode(_pushFailure('conflict')),
      ),
    ]);
    final rejectedApi = _FakeMedicationSyncFunctionsApi([
      MedicationSyncFunctionResponse(
        statusCode: 200,
        body: jsonEncode(_pushFailure('rejected')),
      ),
    ]);
    final mutation = CaregiverMutation.deleteMedication(
      CaregiverMedication(
        id: 'medication-1',
        name: 'Aspirin',
        instructions: '',
        active: true,
        version: 3,
      ),
    );

    await expectLater(
      _gateway(conflictApi).push('robot-1', [mutation]),
      throwsA(isA<CaregiverConflictException>()),
    );
    await expectLater(
      _gateway(rejectedApi).push('robot-1', [mutation]),
      throwsA(
        isA<CaregiverSyncException>().having(
          (error) => error.message,
          'message',
          'The server rejected a medication change (OWNER_REQUIRED).',
        ),
      ),
    );
  });

  test('runtime errors and malformed Function bodies stay safe', () async {
    final denied = _FakeMedicationSyncFunctionsApi([
      const MedicationSyncFunctionResponse(
        statusCode: 403,
        body: '{"error":"owner_required"}',
      ),
    ]);
    final malformed = _FakeMedicationSyncFunctionsApi([
      const MedicationSyncFunctionResponse(statusCode: 200, body: 'not-json'),
    ]);

    await expectLater(
      _gateway(denied).pull('robot-1'),
      throwsA(
        isA<CaregiverSyncException>().having(
          (error) => error.message,
          'message',
          'You do not have access to this household.',
        ),
      ),
    );
    await expectLater(
      _gateway(malformed).pull('robot-1'),
      throwsA(
        isA<CaregiverSyncException>().having(
          (error) => error.message,
          'message',
          'Medication data returned an invalid response.',
        ),
      ),
    );
  });

  test(
    'Function 401 revalidates the account then retries the same body once',
    () async {
      final api = _FakeMedicationSyncFunctionsApi(
        [
          AppwriteException('expired', 401),
          MedicationSyncFunctionResponse(
            statusCode: 200,
            body: jsonEncode(
              _pullPage(
                cursor: null,
                checkpoint: '1',
                nextCursor: '1',
                hasMore: false,
                changes: const [],
              ),
            ),
          ),
        ],
        accountResults: ['account-1', 'account-1'],
      );

      await _gateway(api).pull('robot-1');

      expect(api.accountLookups, 3);
      expect(api.calls, hasLength(2));
      expect(api.calls.first.body, api.calls.last.body);
    },
  );

  test('pull aborts when Function revalidation changes accounts', () async {
    final api = _FakeMedicationSyncFunctionsApi(
      [
        MedicationSyncFunctionResponse(
          statusCode: 200,
          body: jsonEncode(
            _pullPage(
              cursor: null,
              checkpoint: '1',
              nextCursor: '1',
              hasMore: false,
              changes: [_medicationChange()],
            ),
          ),
        ),
        const MedicationSyncFunctionResponse(statusCode: 401, body: '{}'),
        MedicationSyncFunctionResponse(
          statusCode: 200,
          body: jsonEncode(
            _pullPage(
              cursor: null,
              checkpoint: '2',
              nextCursor: '2',
              hasMore: false,
              changes: const [],
            ),
          ),
        ),
      ],
      accountResults: ['account-a', 'account-a', 'account-a', 'account-b'],
    );
    final gateway = _gateway(api);
    final accountA = await gateway.pull('robot-1');
    expect(accountA.snapshot.medications.single.name, 'Aspirin');

    await expectLater(
      gateway.pull('robot-1'),
      throwsA(
        isA<CaregiverSyncException>().having(
          (error) => error.message,
          'message',
          'Signed-in account changed. Refresh medication data.',
        ),
      ),
    );
    expect(api.calls, hasLength(2));

    final result = await gateway.pull('robot-1');
    final retryBody = jsonDecode(api.calls.last.body) as Map<String, dynamic>;
    expect(retryBody['cursor'], isNull);
    expect(retryBody['checkpoint'], isNull);
    expect(result.snapshot.medications, isEmpty);
  });

  test('push aborts when Function revalidation changes accounts', () async {
    final api = _FakeMedicationSyncFunctionsApi(
      [const MedicationSyncFunctionResponse(statusCode: 401, body: '{}')],
      accountResults: ['account-a', 'account-b'],
    );

    await expectLater(
      _gateway(api).push('robot-1', [
        CaregiverMutation.upsertMedication(
          CaregiverMedication(
            id: 'med-1',
            name: 'Morning tablet',
            instructions: '',
            active: true,
            version: 0,
          ),
        ),
      ]),
      throwsA(
        isA<CaregiverSyncException>().having(
          (error) => error.message,
          'message',
          'Signed-in account changed. Refresh medication data.',
        ),
      ),
    );

    expect(api.calls, hasLength(1));
  });

  test(
    'account lookup 401 requires sign-in without invoking the Function',
    () async {
      final api = _FakeMedicationSyncFunctionsApi(
        const [],
        accountResults: [AppwriteException('expired', 401)],
      );

      await expectLater(
        _gateway(api).pull('robot-1'),
        throwsA(
          isA<CaregiverSyncException>().having(
            (error) => error.message,
            'message',
            'Sign in again to view medication data.',
          ),
        ),
      );

      expect(api.accountLookups, 1);
      expect(api.calls, isEmpty);
    },
  );

  test('thrown contract and access errors are not retried', () async {
    for (final statusCode in [400, 403, 405]) {
      final api = _FakeMedicationSyncFunctionsApi([
        AppwriteException('request failed', statusCode),
      ]);

      await expectLater(
        _gateway(api).pull('robot-1'),
        throwsA(isA<CaregiverSyncException>()),
      );
      expect(api.calls, hasLength(1), reason: 'HTTP $statusCode');
    }
  });

  test(
    'retries transient responses and Appwrite errors without changing pushes',
    () async {
      final pushApi = _FakeMedicationSyncFunctionsApi([
        const MedicationSyncFunctionResponse(statusCode: 429, body: '{}'),
        MedicationSyncFunctionResponse(
          statusCode: 200,
          body: jsonEncode({
            'contractVersion': 1,
            'robotId': 'robot-1',
            'acknowledgements': [_pushAcknowledgement('mutation-1')],
          }),
        ),
      ]);

      await _gateway(pushApi).push('robot-1', [
        CaregiverMutation.upsertMedication(
          CaregiverMedication(
            id: 'medication-1',
            name: 'Aspirin',
            instructions: '',
            active: true,
            version: 3,
          ),
        ),
      ]);

      expect(pushApi.calls, hasLength(2));
      expect(pushApi.calls.first.body, pushApi.calls.last.body);
      expect(
        ((jsonDecode(pushApi.calls.first.body) as Map)['operations'] as List)
            .single['mutationId'],
        'mutation-1',
      );

      for (final failure in <Object>[
        const MedicationSyncFunctionResponse(statusCode: 503, body: '{}'),
        AppwriteException('transport unavailable'),
        AppwriteException('server unavailable', 503),
      ]) {
        final api = _FakeMedicationSyncFunctionsApi([
          failure,
          MedicationSyncFunctionResponse(
            statusCode: 200,
            body: jsonEncode(
              _pullPage(
                cursor: null,
                checkpoint: '1',
                nextCursor: '1',
                hasMore: false,
                changes: const [],
              ),
            ),
          ),
        ]);

        await _gateway(api).pull('robot-1');

        expect(api.calls, hasLength(2), reason: '$failure');
        expect(api.calls.first.body, api.calls.last.body, reason: '$failure');
      }
    },
  );

  test('exhausted pull retries leave the committed cache unchanged', () async {
    final api = _FakeMedicationSyncFunctionsApi([
      MedicationSyncFunctionResponse(
        statusCode: 200,
        body: jsonEncode(
          _pullPage(
            cursor: null,
            checkpoint: '1',
            nextCursor: '1',
            hasMore: false,
            changes: [_medicationChange(name: 'Committed')],
          ),
        ),
      ),
      const MedicationSyncFunctionResponse(statusCode: 503, body: '{}'),
      const MedicationSyncFunctionResponse(statusCode: 503, body: '{}'),
      const MedicationSyncFunctionResponse(statusCode: 503, body: '{}'),
      MedicationSyncFunctionResponse(
        statusCode: 200,
        body: jsonEncode(
          _pullPage(
            cursor: '1',
            checkpoint: '1',
            nextCursor: '1',
            hasMore: false,
            changes: const [],
          ),
        ),
      ),
    ]);
    final gateway = _gateway(api);
    await gateway.pull('robot-1');

    await expectLater(
      gateway.pull('robot-1', cursor: '1', checkpoint: '1'),
      throwsA(isA<CaregiverSyncException>()),
    );

    expect(api.calls, hasLength(4));
    expect(api.calls.skip(1).map((call) => call.body).toSet(), hasLength(1));

    final recovered = await gateway.pull(
      'robot-1',
      cursor: '1',
      checkpoint: '1',
    );

    expect(recovered.snapshot.medications.single.name, 'Committed');
  });

  test(
    'a later pull page failure does not publish partial cache changes',
    () async {
      final api = _FakeMedicationSyncFunctionsApi([
        MedicationSyncFunctionResponse(
          statusCode: 200,
          body: jsonEncode(
            _pullPage(
              cursor: null,
              checkpoint: '1',
              nextCursor: '1',
              hasMore: false,
              changes: [_medicationChange(name: 'Committed')],
            ),
          ),
        ),
        MedicationSyncFunctionResponse(
          statusCode: 200,
          body: jsonEncode(
            _pullPage(
              cursor: null,
              checkpoint: '3',
              nextCursor: '2',
              hasMore: true,
              changes: [_medicationChange(cursor: '2', name: 'Partial')],
            ),
          ),
        ),
        const MedicationSyncFunctionResponse(statusCode: 400, body: '{}'),
        MedicationSyncFunctionResponse(
          statusCode: 200,
          body: jsonEncode(
            _pullPage(
              cursor: '1',
              checkpoint: '1',
              nextCursor: '1',
              hasMore: false,
              changes: const [],
            ),
          ),
        ),
      ]);
      final gateway = _gateway(api);
      await gateway.pull('robot-1');

      await expectLater(
        gateway.pull('robot-1'),
        throwsA(isA<CaregiverSyncException>()),
      );

      expect(api.calls, hasLength(3));

      final recovered = await gateway.pull(
        'robot-1',
        cursor: '1',
        checkpoint: '1',
      );

      expect(recovered.snapshot.medications.single.name, 'Committed');
    },
  );

  test(
    'Function 401 requires sign-in when account revalidation fails',
    () async {
      final api = _FakeMedicationSyncFunctionsApi(
        [const MedicationSyncFunctionResponse(statusCode: 401, body: '{}')],
        accountResults: ['account-1', AppwriteException('signed out', 401)],
      );

      await expectLater(
        _gateway(api).pull('robot-1'),
        throwsA(
          isA<CaregiverSyncException>().having(
            (error) => error.message,
            'message',
            'Sign in again to view medication data.',
          ),
        ),
      );

      expect(api.accountLookups, 2);
      expect(api.calls, hasLength(1));
    },
  );
}

AppwriteCaregiverSyncGateway _gateway(AppwriteMedicationSyncFunctionsApi api) =>
    AppwriteCaregiverSyncGateway(
      api,
      pushFunctionId: 'medication-push',
      pullFunctionId: 'medication-pull',
      deviceId: 'web-device',
      newId: () => 'mutation-1',
      now: () => DateTime.utc(2026, 7, 29, 12),
    );

CaregiverMutation _medicationMutation(String id) =>
    CaregiverMutation.upsertMedication(
      CaregiverMedication(
        id: id,
        name: 'Aspirin',
        instructions: '',
        active: true,
        version: 3,
      ),
    );

Map<String, Object?> _pullPage({
  required String? cursor,
  required String checkpoint,
  required String nextCursor,
  required bool hasMore,
  required List<Map<String, Object?>> changes,
}) => {
  'contractVersion': 1,
  'robotId': 'robot-1',
  'cursor': cursor,
  'checkpoint': checkpoint,
  'nextCursor': nextCursor,
  'hasMore': hasMore,
  'changes': changes,
};

Map<String, Object?> _medicationChange({
  bool deleted = false,
  String cursor = '1',
  String name = 'Aspirin',
}) => {
  'cursor': cursor,
  'entityType': 'medication',
  'entityId': 'medication-1',
  'operation': deleted ? 'delete' : 'upsert',
  'record': {
    'contractVersion': 1,
    'id': 'medication-1',
    'householdId': 'robot-1',
    'name': name,
    'pillType': 'tablet',
    'instructions': 'With water',
    'revision': deleted ? 4 : 3,
    'deletedAt': deleted ? '2026-07-29T12:00:00.000Z' : null,
    'updatedAt': '2026-07-29T12:00:00.000Z',
  },
};

Map<String, Object?> _scheduleChange() => {
  'cursor': '2',
  'entityType': 'schedule',
  'entityId': 'schedule-1',
  'operation': 'upsert',
  'record': {
    'contractVersion': 1,
    'id': 'schedule-1',
    'householdId': 'robot-1',
    'medicationId': 'medication-1',
    'label': 'Morning',
    'hour': 9,
    'minute': 0,
    'timezoneId': 'UTC',
    'enabled': true,
    'revision': 7,
    'deletedAt': null,
    'updatedAt': '2026-07-29T12:00:00.000Z',
  },
};

Map<String, Object?> _doseEventChange({String kind = 'taken_confirmed'}) => {
  'cursor': '1',
  'entityType': 'dose_event',
  'entityId': 'event-1',
  'operation': 'append',
  'record': {
    'contractVersion': 1,
    'id': 'event-1',
    'householdId': 'robot-1',
    'medicationId': 'medication-1',
    'occurrence': {
      'contractVersion': 1,
      'occurrenceId': 'schedule-1:7:2026-07-29T09:00:00.000Z',
      'scheduleId': 'schedule-1',
      'scheduleRevision': 7,
      'scheduledAt': '2026-07-29T09:00:00.000Z',
      'localDate': '2026-07-29',
      'timezoneId': 'UTC',
    },
    'kind': kind,
    'occurredAt': '2026-07-29T09:05:00.000Z',
    'actorAccountId': 'account-1',
  },
};

Map<String, Object?> _pushFailure(String outcome) => {
  'contractVersion': 1,
  'robotId': 'robot-1',
  'acknowledgements': [
    {
      'contractVersion': 1,
      'mutationId': 'mutation-1',
      'outcome': outcome,
      'revision': null,
      'cursor': null,
      'errorCode': outcome == 'rejected' ? 'OWNER_REQUIRED' : null,
      'conflict': outcome == 'conflict'
          ? {
              'contractVersion': 1,
              'entityType': 'medication',
              'entityId': 'medication-1',
              'expectedRevision': 3,
              'actualRevision': 4,
              'authoritativeRecord': {
                'contractVersion': 1,
                'id': 'medication-1',
                'householdId': 'robot-1',
                'name': 'Aspirin',
                'pillType': 'tablet',
                'instructions': 'With water',
                'revision': 4,
                'deletedAt': null,
                'updatedAt': '2026-07-29T12:00:00.000Z',
              },
            }
          : null,
    },
  ],
};

Map<String, Object?> _pushAcknowledgement(String mutationId) => {
  'contractVersion': 1,
  'mutationId': mutationId,
  'outcome': 'applied',
  'revision': 1,
  'cursor': '1',
  'errorCode': null,
  'conflict': null,
};

class _FunctionCall {
  const _FunctionCall(this.functionId, this.body);
  final String functionId;
  final String body;
}

class _FakeMedicationSyncFunctionsApi
    implements AppwriteMedicationSyncFunctionsApi {
  _FakeMedicationSyncFunctionsApi(
    this.responses, {
    List<Object>? accountResults,
  }) : accountResults = accountResults ?? [];

  final List<Object> responses;
  final List<Object> accountResults;
  final List<_FunctionCall> calls = [];
  int accountLookups = 0;
  String accountId = 'account-1';

  @override
  Future<String> currentAccountId() async {
    accountLookups += 1;
    if (accountResults.isEmpty) return accountId;
    final result = accountResults.removeAt(0);
    if (result is AppwriteException) throw result;
    return result as String;
  }

  @override
  Future<MedicationSyncFunctionResponse> execute({
    required String functionId,
    required String body,
  }) async {
    calls.add(_FunctionCall(functionId, body));
    final response = responses.removeAt(0);
    if (response is AppwriteException) throw response;
    return response as MedicationSyncFunctionResponse;
  }
}

class _DeferredMedicationSyncFunctionsApi
    implements AppwriteMedicationSyncFunctionsApi {
  _DeferredMedicationSyncFunctionsApi(this.responses);

  final List<Completer<MedicationSyncFunctionResponse>> responses;

  @override
  Future<String> currentAccountId() async => 'account-1';

  @override
  Future<MedicationSyncFunctionResponse> execute({
    required String functionId,
    required String body,
  }) => responses.removeAt(0).future;
}
