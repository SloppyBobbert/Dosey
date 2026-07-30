import 'dart:convert';

import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/reminders/reminder_occurrence.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/sync/sync_outbox_scope.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;
// ignore: experimental_member_use
import 'package:drift/remote.dart' show DriftRemoteException;

enum PhoneDoseActionKind {
  takenConfirmed('taken_confirmed'),
  skipped('skipped'),
  snoozed('snoozed'),
  helpRequested('help_requested'),
  missed('missed'),
  missedAcknowledged('missed_acknowledged');

  const PhoneDoseActionKind(this.storageValue);

  final String storageValue;

  bool get isTerminal =>
      this == takenConfirmed || this == skipped || this == missedAcknowledged;

  bool get isSynced =>
      this == takenConfirmed ||
      this == skipped ||
      this == snoozed ||
      this == helpRequested;

  bool get marksDoseTaken => this == takenConfirmed;

  static PhoneDoseActionKind fromStorage(String value) => values.firstWhere(
    (kind) => kind.storageValue == value,
    orElse: () => throw StateError('Unknown phone dose action kind: $value'),
  );
}

class PhoneDoseActionRequest {
  const PhoneDoseActionRequest({
    required this.occurrence,
    required this.medicationId,
    required this.kind,
    required this.occurredAt,
    required this.deviceId,
    this.syncScope,
  });

  final ReminderOccurrence occurrence;
  final String medicationId;
  final PhoneDoseActionKind kind;
  final DateTime occurredAt;
  final String deviceId;
  final SyncOutboxScope? syncScope;
}

class PhoneDoseActionResult {
  const PhoneDoseActionResult({
    required this.eventId,
    required this.kind,
    required this.inserted,
  });

  final String eventId;
  final PhoneDoseActionKind kind;
  final bool inserted;
}

final class PhoneDoseTerminalConflict implements Exception {
  const PhoneDoseTerminalConflict({
    required this.deviceId,
    required this.occurrenceId,
    required this.existingKind,
    required this.requestedKind,
  });

  final String deviceId;
  final String occurrenceId;
  final PhoneDoseActionKind existingKind;
  final PhoneDoseActionKind requestedKind;

  @override
  String toString() =>
      'A terminal outcome (${existingKind.storageValue}) is already recorded '
      'for this device and occurrence.';
}

final class PhoneDoseActionWriteFailure implements Exception {
  const PhoneDoseActionWriteFailure();

  @override
  String toString() => 'The dose action could not be recorded safely.';
}

class PhoneDoseActionService {
  const PhoneDoseActionService(
    this._database, {
    this.missedContentionAttempts = 5,
    this.missedContentionDelay = const Duration(milliseconds: 10),
  }) : assert(missedContentionAttempts > 0);

  final DoseyDatabase _database;
  final int missedContentionAttempts;
  final Duration missedContentionDelay;

  Future<PhoneDoseActionResult> record(PhoneDoseActionRequest request) async {
    try {
      return await _database.transaction(() => _recordInTransaction(request));
    } on Object {
      final resolved = await _resolveConstraintRace(request);
      if (resolved != null) return resolved;
      rethrow;
    }
  }

  Future<PhoneDoseActionResult?> recordMissedIfNoTerminal(
    PhoneDoseActionRequest request,
  ) async {
    if (request.kind != PhoneDoseActionKind.missed) {
      throw ArgumentError.value(request.kind, 'request.kind');
    }
    for (var attempt = 0; attempt < missedContentionAttempts; attempt++) {
      try {
        return await _recordMissedAttempt(request);
      } on Object catch (error) {
        if (!_isContentionOrConstraint(error)) rethrow;
        final resolved = await _resolveMissedRace(request);
        if (resolved != null) return resolved.result;
        if (attempt == missedContentionAttempts - 1) {
          throw const PhoneDoseActionWriteFailure();
        }
        await Future<void>.delayed(_retryDelay(attempt));
      }
    }
    throw const PhoneDoseActionWriteFailure();
  }

  Future<PhoneDoseActionResult?> _recordMissedAttempt(
    PhoneDoseActionRequest request,
  ) async {
    var transactionStarted = false;
    try {
      await _database.customStatement('BEGIN IMMEDIATE;');
      transactionStarted = true;
      final result = await _terminalFor(request) == null
          ? await _recordInTransaction(request)
          : null;
      await _database.customStatement('COMMIT;');
      transactionStarted = false;
      return result;
    } on Object {
      if (transactionStarted) {
        try {
          await _database.customStatement('ROLLBACK;');
        } on Object {
          // Preserve the original write failure for retry classification.
        }
      }
      rethrow;
    }
  }

  Future<_MissedRaceResolution?> _resolveMissedRace(
    PhoneDoseActionRequest request,
  ) async {
    try {
      if (await _terminalFor(request) != null) {
        return const _MissedRaceResolution(null);
      }
      final duplicate =
          await (_database.select(_database.phoneDoseActionEvents)..where(
                (event) =>
                    event.idempotencyKey.equals(_idempotencyKey(request)),
              ))
              .getSingleOrNull();
      if (duplicate == null) return null;
      _validateDuplicate(duplicate, request);
      return _MissedRaceResolution(_existingResult(duplicate));
    } on Object catch (error) {
      if (_isContentionOrConstraint(error)) return null;
      rethrow;
    }
  }

  Duration _retryDelay(int attempt) => missedContentionDelay * (1 << attempt);

  static bool _isContentionOrConstraint(Object error) {
    final cause = error is DriftRemoteException ? error.remoteCause : error;
    return cause is SqliteException &&
        (cause.resultCode == 5 ||
            cause.resultCode == 6 ||
            cause.resultCode == 19);
  }

  Future<PhoneDoseActionResult> _recordInTransaction(
    PhoneDoseActionRequest request,
  ) async {
    final idempotencyKey = _idempotencyKey(request);
    final duplicate =
        await (_database.select(_database.phoneDoseActionEvents)
              ..where((event) => event.idempotencyKey.equals(idempotencyKey)))
            .getSingleOrNull();
    if (duplicate != null) {
      _validateDuplicate(duplicate, request);
      return _existingResult(duplicate);
    }

    if (request.kind.isTerminal) {
      final terminal = await _terminalFor(request);
      if (terminal != null) {
        throw PhoneDoseTerminalConflict(
          deviceId: request.deviceId,
          occurrenceId: request.occurrence.occurrenceId,
          existingKind: PhoneDoseActionKind.fromStorage(terminal.kind),
          requestedKind: request.kind,
        );
      }
    }

    final eventId = _stableId('event', idempotencyKey);
    final occurredAt = _normalizeTimestamp(request.occurredAt);
    await _database
        .into(_database.phoneDoseActionEvents)
        .insert(
          PhoneDoseActionEventsCompanion.insert(
            id: eventId,
            deviceId: request.deviceId,
            occurrenceId: request.occurrence.occurrenceId,
            scheduleId: request.occurrence.scheduleId,
            scheduleRevision: request.occurrence.scheduleRevision,
            scheduledAt: request.occurrence.scheduledAt,
            localDate: request.occurrence.localDate,
            timezoneId: request.occurrence.timezoneId,
            medicationId: request.medicationId,
            kind: request.kind.storageValue,
            occurredAt: occurredAt,
            marksDoseTaken: request.kind.marksDoseTaken,
            idempotencyKey: idempotencyKey,
            createdAt: occurredAt,
          ),
        );
    await _database
        .into(_database.doseLogEvents)
        .insert(
          DoseLogEventsCompanion.insert(
            id: 'phone:$eventId',
            kind: _legacyKind(request.kind).name,
            doseId: request.occurrence.occurrenceId,
            occurredAt: occurredAt,
            marksDoseTaken: request.kind.marksDoseTaken,
          ),
        );

    if (request.kind.isSynced) {
      final mutationId = _stableId('mutation', idempotencyKey);
      final payload = <String, Object?>{
        'medicationId': request.medicationId,
        'occurrence': {
          'contractVersion': 1,
          'occurrenceId': request.occurrence.occurrenceId,
          'scheduleId': request.occurrence.scheduleId,
          'scheduleRevision': request.occurrence.scheduleRevision,
          'scheduledAt': request.occurrence.scheduledAt.toIso8601String(),
          'localDate': request.occurrence.localDate,
          'timezoneId': request.occurrence.timezoneId,
        },
        'kind': request.kind.storageValue,
        'occurredAt': occurredAt.toIso8601String(),
      };
      await _database
          .into(_database.syncOutboxMutations)
          .insert(
            SyncOutboxMutationsCompanion.insert(
              mutationId: mutationId,
              deviceId: request.deviceId,
              actorAccountId: Value(request.syncScope?.actorAccountId),
              robotId: Value(request.syncScope?.robotId),
              scopeState: Value(
                request.syncScope == null ? 'local_only' : 'bound',
              ),
              idempotencyKey: idempotencyKey,
              entityType: 'dose_event',
              operation: 'append',
              entityId: eventId,
              payloadJson: jsonEncode(payload),
              createdAt: occurredAt,
              updatedAt: occurredAt,
            ),
          );
    }

    return PhoneDoseActionResult(
      eventId: eventId,
      kind: request.kind,
      inserted: true,
    );
  }

  Future<PhoneDoseActionEventRow?> _terminalFor(
    PhoneDoseActionRequest request,
  ) {
    final query = _database.select(_database.phoneDoseActionEvents)
      ..where(
        (row) =>
            row.deviceId.equals(request.deviceId) &
            row.occurrenceId.equals(request.occurrence.occurrenceId) &
            row.kind.isIn(const [
              'taken_confirmed',
              'skipped',
              'missed_acknowledged',
            ]),
      )
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<PhoneDoseActionResult?> _resolveConstraintRace(
    PhoneDoseActionRequest request,
  ) async {
    final idempotencyKey = _idempotencyKey(request);
    final duplicate =
        await (_database.select(_database.phoneDoseActionEvents)
              ..where((event) => event.idempotencyKey.equals(idempotencyKey)))
            .getSingleOrNull();
    if (duplicate != null) {
      _validateDuplicate(duplicate, request);
      return _existingResult(duplicate);
    }
    if (request.kind.isTerminal) {
      final terminal = await _terminalFor(request);
      if (terminal != null) {
        throw PhoneDoseTerminalConflict(
          deviceId: request.deviceId,
          occurrenceId: request.occurrence.occurrenceId,
          existingKind: PhoneDoseActionKind.fromStorage(terminal.kind),
          requestedKind: request.kind,
        );
      }
    }
    return null;
  }

  static String _idempotencyKey(PhoneDoseActionRequest request) => _stableId(
    'dose-action',
    jsonEncode([
      request.deviceId,
      request.occurrence.occurrenceId,
      request.kind.storageValue,
    ]),
  );

  static void _validateDuplicate(
    PhoneDoseActionEventRow duplicate,
    PhoneDoseActionRequest request,
  ) {
    final sameContent =
        duplicate.deviceId == request.deviceId &&
        duplicate.occurrenceId == request.occurrence.occurrenceId &&
        duplicate.scheduleId == request.occurrence.scheduleId &&
        duplicate.scheduleRevision == request.occurrence.scheduleRevision &&
        duplicate.scheduledAt.millisecondsSinceEpoch ~/ 1000 ==
            request.occurrence.scheduledAt.millisecondsSinceEpoch ~/ 1000 &&
        duplicate.medicationId == request.medicationId &&
        duplicate.kind == request.kind.storageValue;
    if (!sameContent) {
      throw StateError(
        'Idempotency key already belongs to a different dose action.',
      );
    }
  }

  static DateTime _normalizeTimestamp(DateTime value) =>
      DateTime.fromMillisecondsSinceEpoch(
        value.toUtc().millisecondsSinceEpoch,
        isUtc: true,
      );

  static String _stableId(String prefix, String input) {
    const seeds = [0x811c9dc5, 0x9e3779b9, 0x85ebca6b, 0xc2b2ae35];
    final digest = seeds
        .map((seed) => _fnv1a32(input, seed).toRadixString(16).padLeft(8, '0'))
        .join();
    return '$prefix-$digest';
  }

  static int _fnv1a32(String input, int seed) {
    var hash = seed;
    for (final byte in utf8.encode(input)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  static PhoneDoseActionResult _existingResult(PhoneDoseActionEventRow row) {
    return PhoneDoseActionResult(
      eventId: row.id,
      kind: PhoneDoseActionKind.fromStorage(row.kind),
      inserted: false,
    );
  }

  static DoseLogEventKind _legacyKind(PhoneDoseActionKind kind) {
    return switch (kind) {
      PhoneDoseActionKind.takenConfirmed => DoseLogEventKind.doseTakenConfirmed,
      PhoneDoseActionKind.skipped => DoseLogEventKind.doseSkipped,
      PhoneDoseActionKind.snoozed => DoseLogEventKind.doseSnoozed,
      PhoneDoseActionKind.helpRequested =>
        DoseLogEventKind.caregiverHelpRequested,
      PhoneDoseActionKind.missed => DoseLogEventKind.doseMissed,
      PhoneDoseActionKind.missedAcknowledged =>
        DoseLogEventKind.doseMissedRecognized,
    };
  }
}

final class _MissedRaceResolution {
  const _MissedRaceResolution(this.result);

  final PhoneDoseActionResult? result;
}
