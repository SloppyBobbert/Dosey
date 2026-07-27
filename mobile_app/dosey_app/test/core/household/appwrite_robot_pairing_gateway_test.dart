import 'package:dosey_app/core/household/appwrite_robot_pairing_gateway.dart';
import 'package:dosey_app/core/household/robot_pairing_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates a pairing code through the configured function', () async {
    final api = _FakePairingApi(
      response: const PairingFunctionResponse(
        statusCode: 200,
        body: '{"code":"ABCD2EFGH3","expiresAt":"2026-07-26T12:10:00.000Z"}',
      ),
    );
    final gateway = AppwriteRobotPairingGateway(
      api,
      'create-code',
      'claim-robot',
    );

    final result = await gateway.createPairingCode(robotId: 'robot-1');

    expect(result.code, 'ABCD2EFGH3');
    expect(result.expiresAt, DateTime.parse('2026-07-26T12:10:00.000Z'));
    expect(api.functionId, 'create-code');
    expect(api.body, '{"robotId":"robot-1"}');
  });

  test(
    'creates an anonymous session before claiming from Robot Mode',
    () async {
      final api = _FakePairingApi(
        response: const PairingFunctionResponse(
          statusCode: 200,
          body: '{"robotId":"robot-1"}',
        ),
      );
      final gateway = AppwriteRobotPairingGateway(
        api,
        'create-code',
        'claim-robot',
      );

      final robotId = await gateway.claimRobot(code: 'abcd2-efgh3');

      expect(robotId, 'robot-1');
      expect(api.ensureSessionCount, 1);
      expect(api.functionId, 'claim-robot');
      expect(api.body, '{"code":"ABCD2EFGH3"}');
    },
  );

  test('maps safe function errors to pairing failures', () async {
    const cases = <int, RobotPairingFailureReason>{
      400: RobotPairingFailureReason.invalidCode,
      401: RobotPairingFailureReason.missingSession,
      409: RobotPairingFailureReason.consumedCode,
      410: RobotPairingFailureReason.expiredCode,
      429: RobotPairingFailureReason.blockedDevice,
      500: RobotPairingFailureReason.functionFailure,
    };

    for (final entry in cases.entries) {
      final gateway = AppwriteRobotPairingGateway(
        _FakePairingApi(
          response: PairingFunctionResponse(
            statusCode: entry.key,
            body: '{"error":"safe_error"}',
          ),
        ),
        'create-code',
        'claim-robot',
      );

      await expectLater(
        gateway.claimRobot(code: 'ABCD2EFGH3'),
        throwsA(
          isA<RobotPairingException>().having(
            (error) => error.reason,
            'reason',
            entry.value,
          ),
        ),
      );
    }
  });
}

class _FakePairingApi implements AppwriteRobotPairingApi {
  _FakePairingApi({required this.response});

  final PairingFunctionResponse response;
  int ensureSessionCount = 0;
  String? functionId;
  String? body;

  @override
  Future<void> ensureAnonymousSession() async {
    ensureSessionCount += 1;
  }

  @override
  Future<PairingFunctionResponse> execute({
    required String functionId,
    required String body,
  }) async {
    this.functionId = functionId;
    this.body = body;
    return response;
  }
}
