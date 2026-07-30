import 'dart:convert';

import 'package:dosey_app/core/sync/appwrite_medication_sync_gateway.dart';
import 'package:dosey_app/core/sync/domain_contracts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const request = MedicationSyncPushRequest(
    robotId: 'robot-1',
    operations: <MutationContract>[],
  );

  test(
    'push invokes the v1 function synchronously with the exact request',
    () async {
      final api = _RecordingFunctionsApi([
        const MedicationSyncFunctionResponse(
          statusCode: 200,
          body:
              '{"contractVersion":1,"robotId":"robot-1","acknowledgements":[]}',
        ),
      ]);

      final response = await AppwriteMedicationSyncGateway(api).push(request);

      expect(response.toJson(), {
        'contractVersion': 1,
        'robotId': 'robot-1',
        'acknowledgements': <Object?>[],
      });
      expect(api.calls, hasLength(1));
      expect(api.calls.single.functionId, 'medication-sync-push-v1');
      expect(jsonDecode(api.calls.single.body), request.toJson());
    },
  );

  test(
    'push refreshes authentication once and retries the same body',
    () async {
      final api = _RecordingFunctionsApi([
        const MedicationSyncFunctionResponse(
          statusCode: 401,
          body: '{"error":"authentication_required"}',
        ),
        const MedicationSyncFunctionResponse(
          statusCode: 200,
          body:
              '{"contractVersion":1,"robotId":"robot-1","acknowledgements":[]}',
        ),
      ]);
      var refreshes = 0;

      await AppwriteMedicationSyncGateway(
        api,
        refreshAuthentication: () async => refreshes += 1,
      ).push(request);

      expect(refreshes, 1);
      expect(api.calls, hasLength(2));
      expect(api.calls[1].body, api.calls[0].body);
    },
  );

  test('push refreshes once when the SDK rejects execution with 401', () async {
    final api = _AuthenticationRejectingFunctionsApi();
    var refreshes = 0;

    await AppwriteMedicationSyncGateway(
      api,
      refreshAuthentication: () async => refreshes += 1,
    ).push(request);

    expect(refreshes, 1);
    expect(api.calls, hasLength(2));
    expect(api.calls[1].body, api.calls[0].body);
  });

  test(
    'push rejects acknowledgements that are not ordered one-to-one',
    () async {
      final operation = MutationContract.fromJson(_mutationJson('mutation-1'));
      final api = _RecordingFunctionsApi([
        const MedicationSyncFunctionResponse(
          statusCode: 200,
          body:
              '{"contractVersion":1,"robotId":"robot-1","acknowledgements":[]}',
        ),
      ]);

      expect(
        () => AppwriteMedicationSyncGateway(api).push(
          MedicationSyncPushRequest(
            robotId: 'robot-1',
            operations: [operation],
          ),
        ),
        throwsA(
          isA<MedicationSyncGatewayException>().having(
            (error) => error.reason,
            'reason',
            MedicationSyncGatewayFailure.invalidResponse,
          ),
        ),
      );
    },
  );

  test('push classifies retryable and permanent function failures', () async {
    final retryable = AppwriteMedicationSyncGateway(
      _RecordingFunctionsApi([
        const MedicationSyncFunctionResponse(
          statusCode: 429,
          body: '{"error":"rate_limited"}',
        ),
      ]),
    );
    final permanent = AppwriteMedicationSyncGateway(
      _RecordingFunctionsApi([
        const MedicationSyncFunctionResponse(
          statusCode: 403,
          body: '{"error":"household_access_denied"}',
        ),
      ]),
    );

    await expectLater(
      retryable.push(request),
      throwsA(
        isA<MedicationSyncGatewayException>().having(
          (error) => error.reason,
          'reason',
          MedicationSyncGatewayFailure.retryable,
        ),
      ),
    );
    await expectLater(
      permanent.push(request),
      throwsA(
        isA<MedicationSyncGatewayException>()
            .having(
              (error) => error.reason,
              'reason',
              MedicationSyncGatewayFailure.permanent,
            )
            .having(
              (error) => error.errorCode,
              'errorCode',
              'household_access_denied',
            ),
      ),
    );
  });

  test('pull invokes the v1 function with the exact cursor request', () async {
    const pullRequest = MedicationSyncPullRequest(
      robotId: 'robot-1',
      cursor: null,
      checkpoint: null,
      limit: 100,
    );
    final api = _RecordingFunctionsApi([
      const MedicationSyncFunctionResponse(
        statusCode: 200,
        body:
            '{"contractVersion":1,"robotId":"robot-1","cursor":null,'
            '"checkpoint":"0","nextCursor":"0","hasMore":false,'
            '"changes":[]}',
      ),
    ]);

    final page = await AppwriteMedicationSyncPullGateway(api).pull(pullRequest);

    expect(page.nextCursor, '0');
    expect(api.calls.single.functionId, 'medication-sync-pull-v1');
    expect(jsonDecode(api.calls.single.body), pullRequest.toJson());
  });
}

Map<String, Object?> _mutationJson(String mutationId) => {
  'contractVersion': 1,
  'mutationId': mutationId,
  'deviceId': 'phone-0123456789abcdef',
  'idempotencyKey': 'idempotency-1',
  'entityType': 'dose_event',
  'operation': 'append',
  'entityId': 'event-1',
  'baseRevision': null,
  'payload': {
    'medicationId': 'medication-1',
    'occurrence': {
      'contractVersion': 1,
      'occurrenceId': 'schedule-1:1:2040-01-02T08:00:00.000Z',
      'scheduleId': 'schedule-1',
      'scheduleRevision': 1,
      'scheduledAt': '2040-01-02T08:00:00.000Z',
      'localDate': '2040-01-02',
      'timezoneId': 'UTC',
    },
    'kind': 'taken_confirmed',
    'occurredAt': '2040-01-02T08:01:00.000Z',
  },
};

class _FunctionCall {
  const _FunctionCall({required this.functionId, required this.body});

  final String functionId;
  final String body;
}

class _RecordingFunctionsApi implements MedicationSyncFunctionsApi {
  _RecordingFunctionsApi(this._responses);

  final List<MedicationSyncFunctionResponse> _responses;
  final List<_FunctionCall> calls = [];

  @override
  Future<MedicationSyncFunctionResponse> execute({
    required String functionId,
    required String body,
  }) async {
    calls.add(_FunctionCall(functionId: functionId, body: body));
    return _responses.removeAt(0);
  }
}

class _AuthenticationRejectingFunctionsApi
    implements MedicationSyncFunctionsApi {
  final List<_FunctionCall> calls = [];

  @override
  Future<MedicationSyncFunctionResponse> execute({
    required String functionId,
    required String body,
  }) async {
    calls.add(_FunctionCall(functionId: functionId, body: body));
    if (calls.length == 1) {
      throw const MedicationSyncGatewayException(
        reason: MedicationSyncGatewayFailure.authenticationRequired,
        errorCode: 'authentication_required',
        statusCode: 401,
      );
    }
    return const MedicationSyncFunctionResponse(
      statusCode: 200,
      body: '{"contractVersion":1,"robotId":"robot-1","acknowledgements":[]}',
    );
  }
}
