import 'package:dosey_app/core/household/mounted_robot_access_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restores sanitized mounted robot fields', () async {
    final gateway = AppwriteMountedRobotAccessGateway(
      _FakeMountedRobotAccessApi(
        '{"robot":{"robotId":"robot-1","displayName":"Kitchen Dosey"}}',
      ),
      'get-mounted-robot',
    );

    expect(await gateway.restore(), isA<MountedRobotInstallation>());
    expect((await gateway.restore())?.robotId, 'robot-1');
  });

  test('authoritative null means unmounted', () async {
    final gateway = AppwriteMountedRobotAccessGateway(
      _FakeMountedRobotAccessApi('{"robot":null}'),
      'get-mounted-robot',
    );

    expect(await gateway.restore(), isNull);
  });

  test('rejects malformed and privacy-leaking responses', () async {
    for (final body in [
      '{}',
      '{"robot":{"robotId":"robot-1"}}',
      '{"robot":{"robotId":"robot-1","displayName":"Dosey","ownerAccountId":"owner-1"}}',
      '{"robot":{"robotId":"","displayName":"Dosey"}}',
    ]) {
      final gateway = AppwriteMountedRobotAccessGateway(
        _FakeMountedRobotAccessApi(body),
        'get-mounted-robot',
      );
      await expectLater(
        gateway.restore(),
        throwsA(isA<MountedRobotAccessException>()),
      );
    }
  });

  test(
    'server and transport failures are not interpreted as unmounted',
    () async {
      final gateway = AppwriteMountedRobotAccessGateway(
        _FakeMountedRobotAccessApi('', statusCode: 500),
        'get-mounted-robot',
      );

      await expectLater(
        gateway.restore(),
        throwsA(isA<MountedRobotAccessException>()),
      );
    },
  );
}

class _FakeMountedRobotAccessApi implements AppwriteMountedRobotAccessApi {
  _FakeMountedRobotAccessApi(this.body, {this.statusCode = 200});

  final String body;
  final int statusCode;

  @override
  Future<MountedRobotFunctionResponse> execute({
    required String functionId,
    required String body,
  }) async =>
      MountedRobotFunctionResponse(statusCode: statusCode, body: this.body);
}
