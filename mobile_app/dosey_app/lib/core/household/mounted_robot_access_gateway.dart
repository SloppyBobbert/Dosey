import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as appwrite_enums;

class MountedRobotInstallation {
  const MountedRobotInstallation({
    required this.robotId,
    required this.displayName,
  });

  final String robotId;
  final String displayName;

  @override
  bool operator ==(Object other) =>
      other is MountedRobotInstallation &&
      other.robotId == robotId &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(robotId, displayName);
}

class MountedRobotFunctionResponse {
  const MountedRobotFunctionResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

abstract interface class AppwriteMountedRobotAccessApi {
  Future<MountedRobotFunctionResponse> execute({
    required String functionId,
    required String body,
  });
}

class AppwriteMountedRobotAccessApiAdapter
    implements AppwriteMountedRobotAccessApi {
  AppwriteMountedRobotAccessApiAdapter(this._functions);

  final Functions _functions;

  @override
  Future<MountedRobotFunctionResponse> execute({
    required String functionId,
    required String body,
  }) async {
    final execution = await _functions.createExecution(
      functionId: functionId,
      body: body,
      xasync: false,
      method: appwrite_enums.ExecutionMethod.pOST,
    );
    return MountedRobotFunctionResponse(
      statusCode: execution.responseStatusCode,
      body: execution.responseBody,
    );
  }
}

abstract interface class MountedRobotAccessGateway {
  bool get isAvailable;

  Future<MountedRobotInstallation?> restore();
}

class DisabledMountedRobotAccessGateway implements MountedRobotAccessGateway {
  const DisabledMountedRobotAccessGateway();

  @override
  bool get isAvailable => false;

  @override
  Future<MountedRobotInstallation?> restore() async => null;
}

class MountedRobotAccessException implements Exception {
  const MountedRobotAccessException(this.message);

  final String message;

  @override
  String toString() => 'MountedRobotAccessException: $message';
}

class MountedRobotAccessTransportException extends MountedRobotAccessException {
  const MountedRobotAccessTransportException(super.message);
}

class MountedRobotAccessResponseException extends MountedRobotAccessException {
  const MountedRobotAccessResponseException(super.message);
}

class AppwriteMountedRobotAccessGateway implements MountedRobotAccessGateway {
  AppwriteMountedRobotAccessGateway(this._api, this._functionId);

  final AppwriteMountedRobotAccessApi _api;
  final String _functionId;

  @override
  bool get isAvailable => true;

  @override
  Future<MountedRobotInstallation?> restore() async {
    MountedRobotFunctionResponse response;
    try {
      response = await _api.execute(functionId: _functionId, body: '{}');
    } on Object catch (error) {
      throw MountedRobotAccessTransportException(
        'Mounted robot restore failed: $error',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MountedRobotAccessResponseException(
        'Mounted robot restore returned HTTP ${response.statusCode}.',
      );
    }

    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> ||
          body.length != 1 ||
          !body.containsKey('robot')) {
        throw const FormatException('Invalid mounted robot response envelope.');
      }
      final robot = body['robot'];
      if (robot == null) return null;
      if (robot is! Map<String, dynamic> ||
          robot.length != 2 ||
          !robot.containsKey('robotId') ||
          !robot.containsKey('displayName')) {
        throw const FormatException('Invalid mounted robot fields.');
      }
      final robotId = robot['robotId'];
      final displayName = robot['displayName'];
      if (robotId is! String ||
          displayName is! String ||
          robotId.trim().isEmpty ||
          displayName.trim().isEmpty) {
        throw const FormatException('Invalid mounted robot values.');
      }
      return MountedRobotInstallation(
        robotId: robotId.trim(),
        displayName: displayName.trim(),
      );
    } on Object {
      throw const MountedRobotAccessResponseException(
        'Mounted robot response was malformed.',
      );
    }
  }
}
