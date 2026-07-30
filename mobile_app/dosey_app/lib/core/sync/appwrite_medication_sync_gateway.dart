import 'dart:async';
import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as appwrite_enums;

import 'domain_contracts.dart';

const medicationSyncPushFunctionId = 'medication-sync-push-v1';
const medicationSyncPullFunctionId = 'medication-sync-pull-v1';

class MedicationSyncFunctionResponse {
  const MedicationSyncFunctionResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

abstract interface class MedicationSyncFunctionsApi {
  Future<MedicationSyncFunctionResponse> execute({
    required String functionId,
    required String body,
  });
}

final class AppwriteMedicationSyncFunctionsApi
    implements MedicationSyncFunctionsApi {
  AppwriteMedicationSyncFunctionsApi(this._functions);

  final Functions _functions;

  @override
  Future<MedicationSyncFunctionResponse> execute({
    required String functionId,
    required String body,
  }) async {
    final execution = await _functions.createExecution(
      functionId: functionId,
      body: body,
      xasync: false,
      method: appwrite_enums.ExecutionMethod.pOST,
    );
    return MedicationSyncFunctionResponse(
      statusCode: execution.responseStatusCode,
      body: execution.responseBody,
    );
  }
}

abstract interface class MedicationSyncPushGateway {
  Future<MedicationSyncPushResponse> push(MedicationSyncPushRequest request);
}

abstract interface class MedicationSyncPullGateway {
  Future<PullPageContract> pull(MedicationSyncPullRequest request);
}

enum MedicationSyncGatewayFailure {
  retryable,
  authenticationRequired,
  permanent,
  invalidResponse,
}

class MedicationSyncGatewayException implements Exception {
  const MedicationSyncGatewayException({
    required this.reason,
    required this.errorCode,
    this.statusCode,
    this.cause,
  });

  final MedicationSyncGatewayFailure reason;
  final String errorCode;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() =>
      'MedicationSyncGatewayException($reason, $errorCode, $statusCode)';
}

final class AppwriteMedicationSyncGateway implements MedicationSyncPushGateway {
  AppwriteMedicationSyncGateway(
    this._api, {
    Future<void> Function()? refreshAuthentication,
  }) : _refresh = refreshAuthentication;

  final MedicationSyncFunctionsApi _api;
  final Future<void> Function()? _refresh;

  @override
  Future<MedicationSyncPushResponse> push(
    MedicationSyncPushRequest request,
  ) async {
    final body = jsonEncode(request.toJson());
    var refreshedAuthentication = false;
    late MedicationSyncFunctionResponse response;
    try {
      response = await _execute(body);
    } on MedicationSyncGatewayException catch (error) {
      if (error.reason != MedicationSyncGatewayFailure.authenticationRequired ||
          _refresh == null) {
        rethrow;
      }
      await _refresh();
      refreshedAuthentication = true;
      response = await _execute(body);
    }
    if (response.statusCode == 401 &&
        _refresh != null &&
        !refreshedAuthentication) {
      await _refresh();
      response = await _execute(body);
    }
    if (response.statusCode != 200) {
      throw _functionFailure(response);
    }

    final MedicationSyncPushResponse result;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object.');
      }
      result = MedicationSyncPushResponse.fromJson(decoded);
    } on Object catch (error) {
      throw MedicationSyncGatewayException(
        reason: MedicationSyncGatewayFailure.invalidResponse,
        errorCode: 'invalid_response',
        statusCode: response.statusCode,
        cause: error,
      );
    }

    if (result.robotId != request.robotId ||
        result.acknowledgements.length != request.operations.length) {
      throw const MedicationSyncGatewayException(
        reason: MedicationSyncGatewayFailure.invalidResponse,
        errorCode: 'response_scope_or_count_mismatch',
      );
    }
    for (var index = 0; index < request.operations.length; index += 1) {
      if (result.acknowledgements[index].mutationId !=
          request.operations[index].mutationId) {
        throw const MedicationSyncGatewayException(
          reason: MedicationSyncGatewayFailure.invalidResponse,
          errorCode: 'acknowledgement_order_mismatch',
        );
      }
    }
    return result;
  }

  Future<MedicationSyncFunctionResponse> _execute(String body) async {
    try {
      return await _api.execute(
        functionId: medicationSyncPushFunctionId,
        body: body,
      );
    } on TimeoutException catch (error) {
      throw MedicationSyncGatewayException(
        reason: MedicationSyncGatewayFailure.retryable,
        errorCode: 'transport_timeout',
        cause: error,
      );
    } on AppwriteException catch (error) {
      final statusCode = error.code;
      throw MedicationSyncGatewayException(
        reason: _reasonForStatus(statusCode),
        errorCode: statusCode == 401
            ? 'authentication_required'
            : 'appwrite_transport_failure',
        statusCode: statusCode,
        cause: error,
      );
    }
  }

  static MedicationSyncGatewayException _functionFailure(
    MedicationSyncFunctionResponse response,
  ) {
    var errorCode = 'function_failure';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['error'] is String) {
        errorCode = decoded['error']! as String;
      }
    } on Object {
      // Preserve the status classification when an error body is malformed.
    }
    return MedicationSyncGatewayException(
      reason: _reasonForStatus(response.statusCode),
      errorCode: errorCode,
      statusCode: response.statusCode,
    );
  }

  static MedicationSyncGatewayFailure _reasonForStatus(int? statusCode) {
    if (statusCode == 401) {
      return MedicationSyncGatewayFailure.authenticationRequired;
    }
    if (statusCode == 429 || (statusCode != null && statusCode >= 500)) {
      return MedicationSyncGatewayFailure.retryable;
    }
    return MedicationSyncGatewayFailure.permanent;
  }
}

final class AppwriteMedicationSyncPullGateway
    implements MedicationSyncPullGateway {
  AppwriteMedicationSyncPullGateway(
    this._api, {
    Future<void> Function()? refreshAuthentication,
  }) : _refresh = refreshAuthentication;

  final MedicationSyncFunctionsApi _api;
  final Future<void> Function()? _refresh;

  @override
  Future<PullPageContract> pull(MedicationSyncPullRequest request) async {
    final body = jsonEncode(request.toJson());
    var refreshedAuthentication = false;
    late MedicationSyncFunctionResponse response;
    try {
      response = await _execute(body);
    } on MedicationSyncGatewayException catch (error) {
      if (error.reason != MedicationSyncGatewayFailure.authenticationRequired ||
          _refresh == null) {
        rethrow;
      }
      await _refresh();
      refreshedAuthentication = true;
      response = await _execute(body);
    }
    if (response.statusCode == 401 &&
        _refresh != null &&
        !refreshedAuthentication) {
      await _refresh();
      response = await _execute(body);
    }
    if (response.statusCode != 200) {
      throw AppwriteMedicationSyncGateway._functionFailure(response);
    }

    final PullPageContract page;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object.');
      }
      page = PullPageContract.fromJson(decoded);
    } on Object catch (error) {
      throw MedicationSyncGatewayException(
        reason: MedicationSyncGatewayFailure.invalidResponse,
        errorCode: 'invalid_response',
        statusCode: response.statusCode,
        cause: error,
      );
    }

    if (page.robotId != request.robotId || page.cursor != request.cursor) {
      throw const MedicationSyncGatewayException(
        reason: MedicationSyncGatewayFailure.invalidResponse,
        errorCode: 'response_scope_or_cursor_mismatch',
      );
    }
    if (request.checkpoint != null && page.checkpoint != request.checkpoint) {
      throw const MedicationSyncGatewayException(
        reason: MedicationSyncGatewayFailure.invalidResponse,
        errorCode: 'response_checkpoint_mismatch',
      );
    }
    return page;
  }

  Future<MedicationSyncFunctionResponse> _execute(String body) async {
    try {
      return await _api.execute(
        functionId: medicationSyncPullFunctionId,
        body: body,
      );
    } on TimeoutException catch (error) {
      throw MedicationSyncGatewayException(
        reason: MedicationSyncGatewayFailure.retryable,
        errorCode: 'transport_timeout',
        cause: error,
      );
    } on AppwriteException catch (error) {
      final statusCode = error.code;
      throw MedicationSyncGatewayException(
        reason: AppwriteMedicationSyncGateway._reasonForStatus(statusCode),
        errorCode: statusCode == 401
            ? 'authentication_required'
            : 'appwrite_transport_failure',
        statusCode: statusCode,
        cause: error,
      );
    }
  }
}
