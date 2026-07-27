import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:dosey_app/core/household/appwrite_robot_pairing_gateway.dart';
import 'package:dosey_app/core/household/robot_pairing_gateway.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, (_) async => '/tmp');
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, null);
  });

  test('replaces a human session with a dedicated anonymous session', () async {
    final account = _FakeAccount([
      _user(id: 'human-1', email: 'owner@example.com'),
      _user(id: 'robot-device-1'),
    ]);
    final api = AppwriteRobotPairingApiAdapter(account, Functions(Client()));

    await api.ensureAnonymousSession();

    expect(account.events, [
      'get:human-1',
      'delete',
      'create',
      'get:robot-device-1',
    ]);
  });

  test('preserves an existing anonymous session', () async {
    final account = _FakeAccount([_user(id: 'robot-device-1')]);
    final api = AppwriteRobotPairingApiAdapter(account, Functions(Client()));

    await api.ensureAnonymousSession();

    expect(account.events, ['get:robot-device-1']);
  });

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

    expect(gateway.isAvailable, isTrue);

    final result = await gateway.createPairingCode(robotId: 'robot-1');

    expect(result.code, 'ABCD2EFGH3');
    expect(result.expiresAt, DateTime.parse('2026-07-26T12:10:00.000Z'));
    expect(api.functionId, 'create-code');
    expect(api.body, '{"robotId":"robot-1"}');
  });

  test('disabled pairing reports that it is unavailable', () {
    expect(const DisabledRobotPairingGateway().isAvailable, isFalse);
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

  test('maps create-code transport failures to function failure', () async {
    final gateway = AppwriteRobotPairingGateway(
      _FakePairingApi(executeError: AppwriteException('offline')),
      'create-code',
      'claim-robot',
    );

    await expectLater(
      gateway.createPairingCode(robotId: 'robot-1'),
      throwsA(
        isA<RobotPairingException>().having(
          (error) => error.reason,
          'reason',
          RobotPairingFailureReason.functionFailure,
        ),
      ),
    );
  });

  test('maps session transport failures to function failure', () async {
    final gateway = AppwriteRobotPairingGateway(
      _FakePairingApi(sessionError: AppwriteException('offline')),
      'create-code',
      'claim-robot',
    );

    await expectLater(
      gateway.claimRobot(code: 'ABCD2EFGH3'),
      throwsA(
        isA<RobotPairingException>().having(
          (error) => error.reason,
          'reason',
          RobotPairingFailureReason.functionFailure,
        ),
      ),
    );
  });
}

class _FakeAccount extends Account {
  _FakeAccount(this.users) : super(Client());

  final List<models.User> users;
  final events = <String>[];
  var _userIndex = 0;

  @override
  Future<models.User> get() async {
    final user = users[_userIndex++];
    events.add('get:${user.$id}');
    return user;
  }

  @override
  Future deleteSession({required String sessionId}) async {
    events.add('delete');
  }

  @override
  Future<models.Session> createAnonymousSession() async {
    events.add('create');
    return models.Session.fromMap(_sessionMap);
  }
}

models.User _user({required String id, String email = '', String phone = ''}) =>
    models.User.fromMap({
      r'$id': id,
      r'$createdAt': '2026-07-26T12:00:00.000Z',
      r'$updatedAt': '2026-07-26T12:00:00.000Z',
      'name': '',
      'registration': '2026-07-26T12:00:00.000Z',
      'status': true,
      'labels': <String>[],
      'passwordUpdate': '',
      'email': email,
      'phone': phone,
      'emailVerification': false,
      'phoneVerification': false,
      'mfa': false,
      'prefs': <String, dynamic>{},
      'targets': <Map<String, dynamic>>[],
      'accessedAt': '2026-07-26T12:00:00.000Z',
    });

final _sessionMap = <String, dynamic>{
  r'$id': 'session-1',
  r'$createdAt': '2026-07-26T12:00:00.000Z',
  r'$updatedAt': '2026-07-26T12:00:00.000Z',
  'userId': 'robot-device-1',
  'expire': '2026-08-26T12:00:00.000Z',
  'provider': 'anonymous',
  'providerUid': '',
  'providerAccessToken': '',
  'providerAccessTokenExpiry': '',
  'providerRefreshToken': '',
  'ip': '',
  'osCode': '',
  'osName': '',
  'osVersion': '',
  'clientType': '',
  'clientCode': '',
  'clientName': '',
  'clientVersion': '',
  'clientEngine': '',
  'clientEngineVersion': '',
  'deviceName': '',
  'deviceBrand': '',
  'deviceModel': '',
  'countryCode': '',
  'countryName': '',
  'current': true,
  'factors': <String>[],
  'secret': '',
  'mfaUpdatedAt': '',
};

class _FakePairingApi implements AppwriteRobotPairingApi {
  _FakePairingApi({
    this.response = const PairingFunctionResponse(statusCode: 200, body: '{}'),
    this.sessionError,
    this.executeError,
  });

  final PairingFunctionResponse response;
  final Object? sessionError;
  final Object? executeError;
  int ensureSessionCount = 0;
  String? functionId;
  String? body;

  @override
  Future<void> ensureAnonymousSession() async {
    ensureSessionCount += 1;
    if (sessionError case final error?) throw error;
  }

  @override
  Future<PairingFunctionResponse> execute({
    required String functionId,
    required String body,
  }) async {
    if (executeError case final error?) throw error;
    this.functionId = functionId;
    this.body = body;
    return response;
  }
}
