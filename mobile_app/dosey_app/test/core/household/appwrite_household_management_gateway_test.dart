import 'dart:convert';

import 'package:dosey_app/core/household/appwrite_household_management_gateway.dart';
import 'package:dosey_app/core/household/household_management_gateway.dart';
import 'package:dosey_app/core/household/robot_installation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates a robot through the configured Function', () async {
    final api = _FakeHouseholdFunctionsApi(
      response: HouseholdFunctionResponse(
        statusCode: 200,
        body: jsonEncode(_householdJson()),
      ),
    );
    final gateway = AppwriteHouseholdManagementGateway(
      api,
      createRobotFunctionId: 'create-robot',
      createInvitationFunctionId: 'create-invitation',
      acceptInvitationFunctionId: 'accept-invitation',
      removeMemberFunctionId: 'remove-member',
    );

    final robot = await gateway.createRobot(' Kitchen Dosey ');

    expect(api.functionId, 'create-robot');
    expect(jsonDecode(api.body!), {'displayName': 'Kitchen Dosey'});
    expect(robot.id, 'robot-1');
    expect(robot.currentRole, HouseholdRole.owner);
    expect(robot.mountedDeviceId, isNull);
    expect(robot.members.single.label, 'Owner Person');
  });

  test('returns an invitation credential without retaining the code', () async {
    final api = _FakeHouseholdFunctionsApi(
      response: const HouseholdFunctionResponse(
        statusCode: 200,
        body:
            '{"code":"ABCD2345EFGH6789","expiresAt":"2026-07-27T12:00:00.000Z"}',
      ),
    );
    final gateway = AppwriteHouseholdManagementGateway(
      api,
      createRobotFunctionId: 'create-robot',
      createInvitationFunctionId: 'create-invitation',
      acceptInvitationFunctionId: 'accept-invitation',
      removeMemberFunctionId: 'remove-member',
    );

    final credential = await gateway.createInvitation(
      'robot-1',
      ' Member@Example.com ',
    );

    expect(api.functionId, 'create-invitation');
    expect(jsonDecode(api.body!), {
      'robotId': 'robot-1',
      'email': 'member@example.com',
    });
    expect(credential.code, 'ABCD2345EFGH6789');
    expect(credential.expiresAt.toUtc().year, 2026);
  });

  test(
    'maps the safe response error instead of only the HTTP status',
    () async {
      final api = _FakeHouseholdFunctionsApi(
        response: const HouseholdFunctionResponse(
          statusCode: 409,
          body: '{"error":"household_full"}',
        ),
      );
      final gateway = AppwriteHouseholdManagementGateway(
        api,
        createRobotFunctionId: 'create-robot',
        createInvitationFunctionId: 'create-invitation',
        acceptInvitationFunctionId: 'accept-invitation',
        removeMemberFunctionId: 'remove-member',
      );

      await expectLater(
        gateway.acceptInvitation('ABCD-2345-EFGH-6789'),
        throwsA(
          isA<HouseholdManagementException>().having(
            (error) => error.reason,
            'reason',
            HouseholdManagementFailureReason.householdFull,
          ),
        ),
      );
    },
  );

  test('self-leave omits an account ID from the removal request', () async {
    final api = _FakeHouseholdFunctionsApi(
      response: const HouseholdFunctionResponse(
        statusCode: 200,
        body: '{"removed":true}',
      ),
    );
    final gateway = AppwriteHouseholdManagementGateway(
      api,
      createRobotFunctionId: 'create-robot',
      createInvitationFunctionId: 'create-invitation',
      acceptInvitationFunctionId: 'accept-invitation',
      removeMemberFunctionId: 'remove-member',
    );

    await gateway.leaveRobot('robot-1');

    expect(api.functionId, 'remove-member');
    expect(jsonDecode(api.body!), {'robotId': 'robot-1'});
  });

  test('disabled management rejects cloud mutations', () async {
    const gateway = DisabledHouseholdManagementGateway();

    await expectLater(
      gateway.createRobot('Kitchen Dosey'),
      throwsA(isA<HouseholdManagementException>()),
    );
  });
}

Map<String, Object?> _householdJson() => {
  'robotId': 'robot-1',
  'displayName': 'Kitchen Dosey',
  'ownerAccountId': 'owner-1',
  'mountedDeviceId': null,
  'currentRole': 'owner',
  'members': [
    {'accountId': 'owner-1', 'label': 'Owner Person', 'role': 'owner'},
  ],
};

class _FakeHouseholdFunctionsApi implements AppwriteHouseholdFunctionsApi {
  _FakeHouseholdFunctionsApi({required this.response});

  final HouseholdFunctionResponse response;
  String? functionId;
  String? body;

  @override
  Future<HouseholdFunctionResponse> execute({
    required String functionId,
    required String body,
  }) async {
    this.functionId = functionId;
    this.body = body;
    return response;
  }
}
