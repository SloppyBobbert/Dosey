import 'dart:convert';

import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/sync/domain_contracts.dart';

class LocalSyncContractProjection {
  const LocalSyncContractProjection();

  MutationContract project(SyncOutboxMutationRow row) {
    if (row.entityType != 'dose_event' ||
        row.operation != 'append' ||
        row.baseRevision != null) {
      throw const FormatException(
        'Expected a dose event append without revision.',
      );
    }

    final payload = _object(_decode(row.payloadJson), 'payload');
    _exactKeys(payload, const [
      'medicationId',
      'profileId',
      'kind',
      'occurredAt',
      'occurrence',
    ], 'payload');
    _localString(payload['profileId'], 'payload.profileId');
    final kind = switch (_localString(payload['kind'], 'payload.kind')) {
      'snoozed' => DoseEventKindContract.snoozed,
      'help_requested' => DoseEventKindContract.helpRequested,
      _ => throw const FormatException('Unsupported local dose event kind.'),
    };
    final occurrence = _object(payload['occurrence'], 'payload.occurrence');
    _exactKeys(occurrence, const [
      'occurrenceId',
      'scheduleId',
      'scheduleRevision',
      'scheduledAtUtc',
      'localDate',
      'timezoneId',
    ], 'payload.occurrence');
    final occurrenceId = _localString(
      occurrence['occurrenceId'],
      'payload.occurrence.occurrenceId',
    );
    final scheduleId = _localString(
      occurrence['scheduleId'],
      'payload.occurrence.scheduleId',
    );
    final scheduleRevision = occurrence['scheduleRevision'];
    if (scheduleRevision is! int) {
      throw const FormatException('Expected an integer schedule revision.');
    }
    final scheduledAt = _localString(
      occurrence['scheduledAtUtc'],
      'payload.occurrence.scheduledAtUtc',
    );
    if (occurrenceId != '$scheduleId:$scheduleRevision:$scheduledAt') {
      throw const FormatException(
        'Local occurrence ID does not match its tuple.',
      );
    }

    final mutation = MutationContract(
      mutationId: row.mutationId,
      deviceId: row.deviceId,
      idempotencyKey: row.idempotencyKey,
      entityType: EntityTypeContract.doseEvent,
      operation: MutationOperationContract.append,
      entityId: row.entityId,
      baseRevision: null,
      payload: DoseEventMutationPayloadContract(
        medicationId: _localString(
          payload['medicationId'],
          'payload.medicationId',
        ),
        occurrence: OccurrenceRefContract(
          occurrenceId:
              '$scheduleId:$scheduleRevision:${_canonicalUtcTimestamp(scheduledAt)}',
          scheduleId: scheduleId,
          scheduleRevision: scheduleRevision,
          scheduledAt: _canonicalUtcTimestamp(scheduledAt),
          localDate: _localString(
            occurrence['localDate'],
            'payload.occurrence.localDate',
          ),
          timezoneId: _localString(
            occurrence['timezoneId'],
            'payload.occurrence.timezoneId',
          ),
        ),
        kind: kind,
        occurredAt: _canonicalUtcTimestamp(
          _localString(payload['occurredAt'], 'payload.occurredAt'),
        ),
      ),
    );
    return MutationContract.fromJson(mutation.toJson());
  }
}

Object? _decode(String value) {
  try {
    return jsonDecode(value);
  } on FormatException {
    throw const FormatException('Invalid local outbox payload JSON.');
  }
}

Map<String, Object?> _object(Object? value, String path) {
  if (value is! Map) throw FormatException('Expected an object at $path.');
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('Expected string object keys at $path.');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

void _exactKeys(Map<String, Object?> value, List<String> keys, String path) {
  if (value.length != keys.length ||
      value.keys.any((key) => !keys.contains(key))) {
    throw FormatException('Unexpected fields at $path.');
  }
  if (keys.any((key) => !value.containsKey(key))) {
    throw FormatException('Missing fields at $path.');
  }
}

String _localString(Object? value, String path) {
  if (value is! String || value.isEmpty || value.trim() != value) {
    throw FormatException('Expected a non-empty string at $path.');
  }
  return value;
}

final _localUtcTimestamp = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?Z$',
);

String _canonicalUtcTimestamp(String value) {
  final match = _localUtcTimestamp.firstMatch(value);
  if (match == null) throw const FormatException('Expected a UTC timestamp.');
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6)!);
  final fraction = (match.group(7) ?? '').padRight(6, '0');
  final instant = DateTime.utc(
    year,
    month,
    day,
    hour,
    minute,
    second,
    int.parse(fraction) ~/ 1000,
    int.parse(fraction) % 1000,
  );
  if (year < 1 ||
      instant.year != year ||
      instant.month != month ||
      instant.day != day ||
      instant.hour != hour ||
      instant.minute != minute ||
      instant.second != second) {
    throw const FormatException('Invalid UTC timestamp.');
  }
  String digits(int number, int width) => number.toString().padLeft(width, '0');
  return '${digits(instant.year, 4)}-${digits(instant.month, 2)}-'
      '${digits(instant.day, 2)}T${digits(instant.hour, 2)}:'
      '${digits(instant.minute, 2)}:${digits(instant.second, 2)}.'
      '${digits(instant.millisecond, 3)}Z';
}
