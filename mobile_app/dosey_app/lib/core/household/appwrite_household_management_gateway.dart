import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as appwrite_enums;
import 'package:dosey_app/core/household/household_management_gateway.dart';
import 'package:dosey_app/core/household/robot_installation.dart';

class HouseholdFunctionResponse {
  const HouseholdFunctionResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

abstract interface class AppwriteHouseholdFunctionsApi {
  Future<HouseholdFunctionResponse> execute({
    required String functionId,
    required String body,
  });
}

class AppwriteHouseholdFunctionsApiAdapter
    implements AppwriteHouseholdFunctionsApi {
  AppwriteHouseholdFunctionsApiAdapter(this._functions);

  final Functions _functions;

  @override
  Future<HouseholdFunctionResponse> execute({
    required String functionId,
    required String body,
  }) async {
    final execution = await _functions.createExecution(
      functionId: functionId,
      body: body,
      xasync: false,
      method: appwrite_enums.ExecutionMethod.pOST,
    );
    return HouseholdFunctionResponse(
      statusCode: execution.responseStatusCode,
      body: execution.responseBody,
    );
  }
}

class AppwriteHouseholdManagementGateway implements HouseholdManagementGateway {
  AppwriteHouseholdManagementGateway(
    this._api, {
    required this.createRobotFunctionId,
    required this.createInvitationFunctionId,
    required this.acceptInvitationFunctionId,
    required this.removeMemberFunctionId,
  });

  final AppwriteHouseholdFunctionsApi _api;
  final String createRobotFunctionId;
  final String createInvitationFunctionId;
  final String acceptInvitationFunctionId;
  final String removeMemberFunctionId;

  @override
  bool get isAvailable => true;

  @override
  Future<RobotInstallation> createRobot(String displayName) async {
    final body = await _execute(createRobotFunctionId, {
      'displayName': displayName.trim(),
    });
    return _household(body);
  }

  @override
  Future<HouseholdInvitationCredential> createInvitation(
    String robotId,
    String email,
  ) async {
    final body = await _execute(createInvitationFunctionId, {
      'robotId': robotId,
      'email': email.trim().toLowerCase(),
    });
    try {
      return HouseholdInvitationCredential(
        code: body['code'] as String,
        expiresAt: DateTime.parse(body['expiresAt'] as String),
      );
    } on Object {
      throw const HouseholdManagementException(
        HouseholdManagementFailureReason.functionFailure,
      );
    }
  }

  @override
  Future<RobotInstallation> acceptInvitation(String code) async {
    final body = await _execute(acceptInvitationFunctionId, {
      'code': code.trim().toUpperCase().replaceAll('-', ''),
    });
    return _household(body);
  }

  @override
  Future<RobotInstallation> removeMember(
    String robotId,
    String accountId,
  ) async {
    final body = await _execute(removeMemberFunctionId, {
      'robotId': robotId,
      'accountId': accountId,
    });
    return _household(body);
  }

  @override
  Future<void> leaveRobot(String robotId) async {
    await _execute(removeMemberFunctionId, {'robotId': robotId});
  }

  Future<Map<String, dynamic>> _execute(
    String functionId,
    Map<String, String> request,
  ) async {
    HouseholdFunctionResponse response;
    try {
      response = await _api.execute(
        functionId: functionId,
        body: jsonEncode(request),
      );
    } on AppwriteException {
      throw const HouseholdManagementException(
        HouseholdManagementFailureReason.functionFailure,
      );
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } on Object {
      throw const HouseholdManagementException(
        HouseholdManagementFailureReason.functionFailure,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HouseholdManagementException(_failureReason(body['error']));
    }
    return body;
  }

  RobotInstallation _household(Map<String, dynamic> body) {
    try {
      final members = (body['members'] as List<dynamic>)
          .map((value) => value as Map<String, dynamic>)
          .map(
            (value) => HouseholdMember(
              accountId: value['accountId'] as String,
              label: value['label'] as String,
              role: _role(value['role']),
            ),
          )
          .toList(growable: false);
      return RobotInstallation(
        id: body['robotId'] as String,
        displayName: body['displayName'] as String,
        ownerAccountId: body['ownerAccountId'] as String,
        mountedDeviceId: body['mountedDeviceId'] as String?,
        currentRole: _role(body['currentRole']),
        members: members,
      );
    } on Object {
      throw const HouseholdManagementException(
        HouseholdManagementFailureReason.functionFailure,
      );
    }
  }

  HouseholdRole _role(Object? value) => switch (value) {
    'owner' => HouseholdRole.owner,
    'member' => HouseholdRole.member,
    _ => throw const FormatException('Invalid household role.'),
  };

  HouseholdManagementFailureReason _failureReason(
    Object? code,
  ) => switch (code) {
    'already_linked' => HouseholdManagementFailureReason.alreadyLinked,
    'household_full' => HouseholdManagementFailureReason.householdFull,
    'invalid_invitation' => HouseholdManagementFailureReason.invalidInvitation,
    'invitation_expired' => HouseholdManagementFailureReason.invitationExpired,
    'email_mismatch' => HouseholdManagementFailureReason.emailMismatch,
    'owner_required' => HouseholdManagementFailureReason.ownerRequired,
    'owner_cannot_leave' => HouseholdManagementFailureReason.ownerCannotLeave,
    'member_not_found' => HouseholdManagementFailureReason.memberNotFound,
    'authentication_required' =>
      HouseholdManagementFailureReason.authenticationRequired,
    'invalid_display_name' ||
    'invalid_invitation_request' ||
    'invalid_removal_request' =>
      HouseholdManagementFailureReason.invalidRequest,
    _ => HouseholdManagementFailureReason.functionFailure,
  };
}
