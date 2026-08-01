import 'dart:convert';

import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/reminders/reminder_occurrence.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';
import 'package:sqlite3/common.dart' show SqlError, SqliteException;

enum PhoneDoseActionKind {
  takenConfirmed('taken_confirmed'),
  skipped('skipped'),
  snoozed('snoozed'),
  helpRequested('help_requested'),
  missed('missed'),
  missedAcknowledged('missed_acknowledged');

  const PhoneDoseActionKind(this.storageValue);
  final String storageValue;
  bool get terminal => this == takenConfirmed || this == skipped;
  bool get outboxEligible => this != missed && this != missedAcknowledged;
  bool get marksTaken => this == takenConfirmed;
}

class PhoneDoseActionRequest {
  const PhoneDoseActionRequest({
    required this.occurrence,
    required this.kind,
    required this.deviceId,
    required this.occurredAt,
    this.intentToken,
  });
  final ReminderOccurrence occurrence;
  final PhoneDoseActionKind kind;
  final String deviceId;
  final DateTime occurredAt;
  final String? intentToken;
}

class PhoneDoseActionResult {
  const PhoneDoseActionResult({
    required this.eventId,
    required this.inserted,
    required this.occurredAt,
  });
  final String eventId;
  final bool inserted;
  final DateTime occurredAt;
}

class PhoneDoseActionService {
  const PhoneDoseActionService(this._database);
  final DoseyDatabase _database;

  Future<PhoneDoseActionResult> record(PhoneDoseActionRequest request) async {
    if (request.deviceId.trim().isEmpty) {
      throw ArgumentError.value(request.deviceId, 'deviceId');
    }
    if (!request.occurredAt.isUtc) {
      throw ArgumentError.value(request.occurredAt, 'occurredAt');
    }
    _canonicalIntentToken(request);
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        return await _database.transaction(() => _record(request));
      } on SqliteException catch (error) {
        if (error.resultCode != SqlError.SQLITE_BUSY || attempt == 3) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 10 * (attempt + 1)));
      }
    }
    throw StateError('Unreachable');
  }

  /// Records a derived missed action while the caller owns the transaction.
  Future<PhoneDoseActionResult?> recordMissedIfNoTerminalInCurrentTransaction(
    PhoneDoseActionRequest request,
  ) async {
    if (request.kind != PhoneDoseActionKind.missed) {
      throw ArgumentError.value(request.kind, 'request.kind');
    }
    _validateRequest(request);
    final occurrence = request.occurrence;
    final token = _canonicalIntentToken(request);
    final key = _idempotencyKey(
      request.deviceId,
      occurrence,
      request.kind,
      token,
    );
    final existing = await (_database.select(
      _database.phoneDoseActionEvents,
    )..where((row) => row.idempotencyKey.equals(key))).getSingleOrNull();
    if (existing != null) {
      _verify(existing, request);
      return PhoneDoseActionResult(
        eventId: existing.id,
        inserted: false,
        occurredAt: existing.occurredAt.toUtc(),
      );
    }
    final taken =
        await (_database.select(_database.phoneDoseActionEvents)..where(
              (row) =>
                  row.occurrenceId.equals(occurrence.id) &
                  row.marksDoseTaken.equals(true),
            ))
            .getSingleOrNull();
    if (taken != null) return null;
    final skipped =
        await (_database.select(_database.phoneDoseActionEvents)..where(
              (row) =>
                  row.deviceId.equals(request.deviceId) &
                  row.occurrenceId.equals(occurrence.id) &
                  row.kind.equals(PhoneDoseActionKind.skipped.storageValue),
            ))
            .getSingleOrNull();
    if (skipped != null) return null;
    return _insertActionAndLog(request, token, enqueueOutbox: false);
  }

  Future<PhoneDoseActionResult> _record(PhoneDoseActionRequest request) async {
    // Acquire writer intent before reading action or inventory state.
    await _database.customUpdate(
      'UPDATE app_settings SET updated_at = updated_at WHERE key = ?',
      variables: [Variable<String>('_phone_dose_writer_intent')],
    );
    final occurrence = request.occurrence;
    final token = _canonicalIntentToken(request);
    final key = _idempotencyKey(
      request.deviceId,
      occurrence,
      request.kind,
      token,
    );
    final existing = await (_database.select(
      _database.phoneDoseActionEvents,
    )..where((row) => row.idempotencyKey.equals(key))).getSingleOrNull();
    if (existing != null) {
      _verify(existing, request);
      return PhoneDoseActionResult(
        eventId: existing.id,
        inserted: false,
        occurredAt: existing.occurredAt.toUtc(),
      );
    }
    if (request.kind == PhoneDoseActionKind.takenConfirmed) {
      final taken =
          await (_database.select(_database.phoneDoseActionEvents)..where(
                (row) =>
                    row.occurrenceId.equals(occurrence.id) &
                    row.marksDoseTaken.equals(true),
              ))
              .getSingleOrNull();
      if (taken != null) {
        _verify(taken, request, allowDeviceDifference: true);
        return PhoneDoseActionResult(
          eventId: taken.id,
          inserted: false,
          occurredAt: taken.occurredAt.toUtc(),
        );
      }
    }
    if (request.kind.terminal) {
      final terminal =
          await (_database.select(_database.phoneDoseActionEvents)..where(
                (row) =>
                    row.deviceId.equals(request.deviceId) &
                    row.occurrenceId.equals(occurrence.id) &
                    row.kind.isIn(const ['taken_confirmed', 'skipped']),
              ))
              .getSingleOrNull();
      if (terminal != null) {
        throw StateError(
          'A terminal action already exists for this device and occurrence.',
        );
      }
    }
    if (request.kind.marksTaken) {
      final prescription =
          await (_database.select(_database.prescriptions)
                ..where((row) => row.id.equals(occurrence.medicationId)))
              .getSingleOrNull();
      if (prescription == null) {
        throw StateError('Occurrence prescription does not exist.');
      }
      if (prescription.availableDoses > 0 && prescription.remainingDoses > 0) {
        await (_database.update(
          _database.prescriptions,
        )..where((row) => row.id.equals(prescription.id))).write(
          PrescriptionsCompanion(
            availableDoses: Value(prescription.availableDoses - 1),
            remainingDoses: Value(prescription.remainingDoses - 1),
          ),
        );
      }
    }
    return _insertActionAndLog(request, token);
  }

  Future<PhoneDoseActionResult> _insertActionAndLog(
    PhoneDoseActionRequest request,
    String? token, {
    bool enqueueOutbox = true,
  }) async {
    final occurrence = request.occurrence;
    final key = _idempotencyKey(
      request.deviceId,
      occurrence,
      request.kind,
      token,
    );
    final id = _eventId(request.deviceId, occurrence, request.kind, token);
    final occurredAt = _normalizeOccurredAt(request.occurredAt);
    await _database
        .into(_database.phoneDoseActionEvents)
        .insert(
          PhoneDoseActionEventsCompanion.insert(
            id: id,
            deviceId: request.deviceId,
            occurrenceId: occurrence.id,
            scheduleId: occurrence.scheduleId,
            scheduleRevision: occurrence.scheduleRevision,
            scheduledAt: occurrence.scheduledAtUtc,
            localDate: occurrence.localDate,
            timezoneId: occurrence.timezoneId,
            medicationId: occurrence.medicationId,
            kind: request.kind.storageValue,
            occurredAt: occurredAt,
            marksDoseTaken: request.kind.marksTaken,
            idempotencyKey: key,
            createdAt: occurredAt,
          ),
        );
    await _database
        .into(_database.doseLogEvents)
        .insert(
          DoseLogEventsCompanion.insert(
            id: 'phone:$id',
            kind: _legacyKind(request.kind).name,
            doseId: occurrence.id,
            occurredAt: occurredAt,
            marksDoseTaken: request.kind.marksTaken,
          ),
        );
    if (enqueueOutbox && request.kind.outboxEligible) {
      await _database
          .into(_database.syncOutboxMutations)
          .insert(
            SyncOutboxMutationsCompanion.insert(
              mutationId: _id('mutation', key),
              deviceId: request.deviceId,
              idempotencyKey: key,
              entityType: 'dose_event',
              operation: 'append',
              entityId: id,
              payloadJson: jsonEncode({
                'medicationId': occurrence.medicationId,
                'profileId': occurrence.profileId,
                'kind': request.kind.storageValue,
                'occurredAt': occurredAt.toIso8601String(),
                'occurrence': {
                  'occurrenceId': occurrence.id,
                  'scheduleId': occurrence.scheduleId,
                  'scheduleRevision': occurrence.scheduleRevision,
                  'scheduledAtUtc': occurrence.scheduledAtUtc.toIso8601String(),
                  'localDate': occurrence.localDate,
                  'timezoneId': occurrence.timezoneId,
                },
              }),
              createdAt: occurredAt,
              updatedAt: occurredAt,
            ),
          );
    }
    return PhoneDoseActionResult(
      eventId: id,
      inserted: true,
      occurredAt: occurredAt,
    );
  }

  static void _validateRequest(PhoneDoseActionRequest request) {
    if (request.deviceId.trim().isEmpty) {
      throw ArgumentError.value(request.deviceId, 'deviceId');
    }
    if (!request.occurredAt.isUtc) {
      throw ArgumentError.value(request.occurredAt, 'occurredAt');
    }
    _canonicalIntentToken(request);
  }

  static void _verify(
    PhoneDoseActionEventRow row,
    PhoneDoseActionRequest request, {
    bool allowDeviceDifference = false,
  }) {
    final o = request.occurrence;
    final token = _canonicalIntentToken(request);
    final expectedKey = _idempotencyKey(row.deviceId, o, request.kind, token);
    final expectedId = _eventId(row.deviceId, o, request.kind, token);
    if (row.id != expectedId ||
        row.idempotencyKey != expectedKey ||
        (!allowDeviceDifference && row.deviceId != request.deviceId) ||
        row.occurrenceId != o.id ||
        row.scheduleId != o.scheduleId ||
        row.scheduleRevision != o.scheduleRevision ||
        row.scheduledAt.millisecondsSinceEpoch ~/ 1000 !=
            o.scheduledAtUtc.millisecondsSinceEpoch ~/ 1000 ||
        row.localDate != o.localDate ||
        row.timezoneId != o.timezoneId ||
        row.medicationId != o.medicationId ||
        row.kind != request.kind.storageValue) {
      throw StateError(
        'Existing action does not match the immutable occurrence snapshot.',
      );
    }
  }

  static DateTime _normalizeOccurredAt(DateTime value) =>
      DateTime.fromMillisecondsSinceEpoch(
        (value.toUtc().millisecondsSinceEpoch ~/ 1000) * 1000,
        isUtc: true,
      );

  static String _idempotencyKey(
    String deviceId,
    ReminderOccurrence occurrence,
    PhoneDoseActionKind kind,
    String? token,
  ) => _id(
    'dose-action',
    jsonEncode(
      token == null
          ? [deviceId, occurrence.id, kind.storageValue]
          : [deviceId, token],
    ),
  );

  static String _eventId(
    String deviceId,
    ReminderOccurrence occurrence,
    PhoneDoseActionKind kind,
    String? token,
  ) => _id(
    'event',
    jsonEncode([
      deviceId,
      occurrence.id,
      occurrence.scheduleId,
      occurrence.scheduleRevision,
      occurrence.scheduledAtUtc.toIso8601String(),
      occurrence.localDate,
      occurrence.timezoneId,
      occurrence.medicationId,
      occurrence.profileId,
      kind.storageValue,
      ...?(token == null ? null : [token]),
    ]),
  );

  static String? _canonicalIntentToken(PhoneDoseActionRequest request) {
    final requiresToken =
        request.kind == PhoneDoseActionKind.snoozed ||
        request.kind == PhoneDoseActionKind.helpRequested;
    final token = request.intentToken?.trim();
    if (requiresToken) {
      if (token == null || token.isEmpty || token.length > 128) {
        throw ArgumentError.value(request.intentToken, 'intentToken');
      }
      return token;
    }
    if (token != null) {
      throw ArgumentError.value(request.intentToken, 'intentToken');
    }
    return null;
  }

  static String _id(String prefix, String input) {
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

  static DoseLogEventKind _legacyKind(PhoneDoseActionKind kind) =>
      switch (kind) {
        PhoneDoseActionKind.takenConfirmed =>
          DoseLogEventKind.doseTakenConfirmed,
        PhoneDoseActionKind.skipped => DoseLogEventKind.doseSkipped,
        PhoneDoseActionKind.snoozed => DoseLogEventKind.doseSnoozed,
        PhoneDoseActionKind.helpRequested =>
          DoseLogEventKind.caregiverHelpRequested,
        PhoneDoseActionKind.missed => DoseLogEventKind.doseMissed,
        PhoneDoseActionKind.missedAcknowledged =>
          DoseLogEventKind.doseMissedRecognized,
      };
}
