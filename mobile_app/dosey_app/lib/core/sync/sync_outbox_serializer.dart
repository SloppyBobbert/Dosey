import 'dart:convert';

import 'package:dosey_app/core/storage/dosey_database.dart';

class SyncOutboxSerializer {
  const SyncOutboxSerializer._();

  static Map<String, Object?> toMutationJson(SyncOutboxMutationRow row) {
    final decodedPayload = jsonDecode(row.payloadJson);
    if (decodedPayload is! Map<String, dynamic>) {
      throw const FormatException('Outbox mutation payload must be an object.');
    }
    return <String, Object?>{
      'contractVersion': 1,
      'mutationId': row.mutationId,
      'deviceId': row.deviceId,
      'idempotencyKey': row.idempotencyKey,
      'entityType': row.entityType,
      'operation': row.operation,
      'entityId': row.entityId,
      'baseRevision': row.baseRevision,
      'payload': decodedPayload,
    };
  }

  static Map<String, Object?> toPushRequestJson({
    required String robotId,
    required Iterable<SyncOutboxMutationRow> mutations,
  }) {
    return <String, Object?>{
      'contractVersion': 1,
      'robotId': robotId,
      'operations': mutations.map(toMutationJson).toList(growable: false),
    };
  }
}
