import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as appwrite_enums;
import 'package:appwrite/models.dart' as models;
import 'package:dosey_app/core/household/robot_pairing_gateway.dart';

class PairingFunctionResponse {
  const PairingFunctionResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

abstract interface class AppwriteRobotPairingApi {
  Future<void> ensureAnonymousSession();

  Future<PairingFunctionResponse> execute({
    required String functionId,
    required String body,
  });
}

class AppwriteRobotPairingApiAdapter implements AppwriteRobotPairingApi {
  AppwriteRobotPairingApiAdapter(this._account, this._functions);

  final Account _account;
  final Functions _functions;

  @override
  Future<void> ensureAnonymousSession() async {
    models.User user;
    try {
      user = await _account.get();
    } on AppwriteException catch (error) {
      if (error.code != 401) rethrow;
      await _account.createAnonymousSession();
      user = await _account.get();
    }

    if (user.email.trim().isNotEmpty || user.phone.trim().isNotEmpty) {
      await _account.deleteSession(sessionId: 'current');
      await _account.createAnonymousSession();
      user = await _account.get();
    }

    if (user.email.trim().isNotEmpty || user.phone.trim().isNotEmpty) {
      throw AppwriteException('Dedicated anonymous session unavailable');
    }
  }

  @override
  Future<PairingFunctionResponse> execute({
    required String functionId,
    required String body,
  }) async {
    final execution = await _functions.createExecution(
      functionId: functionId,
      body: body,
      xasync: false,
      method: appwrite_enums.ExecutionMethod.pOST,
    );
    return PairingFunctionResponse(
      statusCode: execution.responseStatusCode,
      body: execution.responseBody,
    );
  }
}

class AppwriteRobotPairingGateway implements RobotPairingGateway {
  AppwriteRobotPairingGateway(
    this._api,
    this._createPairingCodeFunctionId,
    this._claimRobotFunctionId,
  );

  final AppwriteRobotPairingApi _api;
  final String _createPairingCodeFunctionId;
  final String _claimRobotFunctionId;

  @override
  Future<RobotPairingCredential> createPairingCode({
    required String robotId,
  }) async {
    final response = await _execute(
      _createPairingCodeFunctionId,
      jsonEncode({'robotId': robotId}),
    );
    final body = _successfulBody(response);
    try {
      return RobotPairingCredential(
        code: body['code'] as String,
        expiresAt: DateTime.parse(body['expiresAt'] as String),
      );
    } on Object {
      throw const RobotPairingException(
        RobotPairingFailureReason.functionFailure,
      );
    }
  }

  @override
  Future<String> claimRobot({required String code}) async {
    try {
      await _api.ensureAnonymousSession();
    } on AppwriteException {
      throw const RobotPairingException(
        RobotPairingFailureReason.functionFailure,
      );
    }
    final normalized = code.trim().toUpperCase().replaceAll('-', '');
    final response = await _execute(
      _claimRobotFunctionId,
      jsonEncode({'code': normalized}),
    );
    final body = _successfulBody(response);
    final robotId = body['robotId'];
    if (robotId is! String || robotId.isEmpty) {
      throw const RobotPairingException(
        RobotPairingFailureReason.functionFailure,
      );
    }
    return robotId;
  }

  Future<PairingFunctionResponse> _execute(
    String functionId,
    String body,
  ) async {
    try {
      return await _api.execute(functionId: functionId, body: body);
    } on AppwriteException {
      throw const RobotPairingException(
        RobotPairingFailureReason.functionFailure,
      );
    }
  }

  Map<String, dynamic> _successfulBody(PairingFunctionResponse response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RobotPairingException(_reasonForStatus(response.statusCode));
    }
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on Object {
      throw const RobotPairingException(
        RobotPairingFailureReason.functionFailure,
      );
    }
  }

  RobotPairingFailureReason _reasonForStatus(int statusCode) =>
      switch (statusCode) {
        400 => RobotPairingFailureReason.invalidCode,
        401 => RobotPairingFailureReason.missingSession,
        409 => RobotPairingFailureReason.consumedCode,
        410 => RobotPairingFailureReason.expiredCode,
        429 => RobotPairingFailureReason.blockedDevice,
        _ => RobotPairingFailureReason.functionFailure,
      };
}
