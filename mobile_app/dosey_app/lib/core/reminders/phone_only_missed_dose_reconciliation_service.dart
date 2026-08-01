import 'dart:async';
import 'dart:convert';

import 'package:dosey_app/core/logging/phone_dose_action_service.dart';
import 'package:dosey_app/core/reminders/reminder_occurrence.dart';
import 'package:dosey_app/core/reminders/reminder_occurrence_resolver.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';
import 'package:sqlite3/common.dart' show SqlError, SqliteException;

class PhoneOnlyMissedDoseReconciliationService {
  PhoneOnlyMissedDoseReconciliationService(
    this._database, {
    required this._deviceId,
    required this._timezoneId,
    required this._now,
    Duration gracePeriod = const Duration(hours: 2),
    Duration maxWindow = const Duration(days: 7),
    this._resolver = const ReminderOccurrenceResolver(),
  }) : _gracePeriod = _positive(gracePeriod, 'gracePeriod'),
       _maxWindow = _positive(maxWindow, 'maxWindow') {
    if (maxWindow > const Duration(days: 7)) {
      throw ArgumentError.value(
        maxWindow,
        'maxWindow',
        'Must not exceed 7 days.',
      );
    }
  }

  static const checkpointKey = 'phone_missed_reconciliation_checkpoint_v1';

  final DoseyDatabase _database;
  final String Function() _deviceId;
  final String Function() _timezoneId;
  final DateTime Function() _now;
  final Duration _gracePeriod;
  final Duration _maxWindow;
  final ReminderOccurrenceResolver _resolver;
  Future<void>? _inFlight;

  Future<void> reconcile() {
    final active = _inFlight;
    if (active != null) return active;
    final completer = Completer<void>();
    _inFlight = completer.future;
    () async {
      try {
        await _reconcile();
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        _inFlight = null;
      }
    }();
    return completer.future;
  }

  Future<void> _reconcile() async {
    final deviceId = _requireNonBlank(_deviceId(), 'deviceId');
    final timezoneId = _requireNonBlank(_timezoneId(), 'timezoneId');
    _resolver.locationFor(timezoneId);
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        await _database.transaction(
          () => _reconcileInTransaction(deviceId, timezoneId),
        );
        return;
      } on SqliteException catch (error) {
        if (error.resultCode != SqlError.SQLITE_BUSY || attempt == 3) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 10 * (attempt + 1)));
      }
    }
  }

  Future<void> _reconcileInTransaction(
    String deviceId,
    String timezoneId,
  ) async {
    await _database.customUpdate(
      phoneDoseWriterIntentSql,
      variables: [Variable<String>('_phone_dose_writer_intent')],
    );
    final observedAt = _requireUtc(_now());
    final checkpointRow = await (_database.select(
      _database.appSettings,
    )..where((row) => row.key.equals(checkpointKey))).getSingleOrNull();
    final schedules = await _database.select(_database.reminderSchedules).get();
    schedules.sort((left, right) => left.id.compareTo(right.id));
    final current = _currentSchedules(schedules);
    final checkpoint = _Checkpoint.tryDecode(checkpointRow?.value);
    final trusted =
        checkpoint != null &&
        checkpoint.deviceId == deviceId &&
        checkpoint.timezoneId == timezoneId &&
        !checkpoint.observedAtUtc.isAfter(observedAt) &&
        _sameSchedules(checkpoint.schedules, current);
    if (trusted) {
      final lowerExclusive =
          checkpoint.observedAtUtc.isAfter(observedAt.subtract(_maxWindow))
          ? checkpoint.observedAtUtc
          : observedAt.subtract(_maxWindow);
      final seen = <String>{};
      final actionService = PhoneDoseActionService(_database);
      for (final candidate in _candidates(
        current,
        lowerExclusive: lowerExclusive,
        observedAt: observedAt,
        timezoneId: timezoneId,
      )) {
        if (!seen.add(candidate.id)) continue;
        await actionService.recordMissedIfNoTerminalInCurrentTransaction(
          PhoneDoseActionRequest(
            occurrence: candidate,
            kind: PhoneDoseActionKind.missed,
            deviceId: deviceId,
            occurredAt: observedAt,
          ),
        );
      }
    }
    final next = _Checkpoint(
      deviceId: deviceId,
      observedAtUtc: observedAt,
      timezoneId: timezoneId,
      schedules: current,
    );
    await _database
        .into(_database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: checkpointKey,
            value: next.encode(),
            updatedAt: observedAt,
          ),
        );
  }

  Iterable<ReminderOccurrence> _candidates(
    List<_ScheduleCheckpoint> schedules, {
    required DateTime lowerExclusive,
    required DateTime observedAt,
    required String timezoneId,
  }) sync* {
    final firstDate = _resolver.localDateFor(
      lowerExclusive.subtract(_gracePeriod),
      timezoneId,
    );
    final lastDate = _resolver.localDateFor(
      observedAt.subtract(_gracePeriod),
      timezoneId,
    );
    for (
      var date = firstDate;
      !date.isAfter(lastDate);
      date = date.add(const Duration(days: 1))
    ) {
      for (final schedule in schedules) {
        if (!schedule.isEnabled ||
            schedule.prescriptionId == null ||
            schedule.prescriptionId!.trim().isEmpty) {
          continue;
        }
        final resolved = _resolver.resolve(
          localDate: date,
          hour: schedule.hour,
          minute: schedule.minute,
          timezoneId: timezoneId,
        );
        final deadline = resolved.scheduledAtUtc.add(_gracePeriod);
        if (!deadline.isAfter(lowerExclusive) || deadline.isAfter(observedAt)) {
          continue;
        }
        yield ReminderOccurrence(
          scheduleId: schedule.id,
          scheduleRevision: schedule.revision,
          scheduledAtUtc: resolved.scheduledAtUtc,
          localDate: resolved.localDate,
          timezoneId: timezoneId,
          medicationId: schedule.prescriptionId!,
          profileId: schedule.profileId,
        );
      }
    }
  }

  List<_ScheduleCheckpoint> _currentSchedules(List<ReminderScheduleRow> rows) {
    final schedules = <_ScheduleCheckpoint>[];
    for (final row in rows) {
      schedules.add(_ScheduleCheckpoint.fromRow(row));
    }
    return schedules;
  }

  static bool _sameSchedules(
    List<_ScheduleCheckpoint> left,
    List<_ScheduleCheckpoint> right,
  ) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  static Duration _positive(Duration value, String name) {
    if (value <= Duration.zero) {
      throw ArgumentError.value(value, name, 'Must be positive.');
    }
    return value;
  }

  static String _requireNonBlank(String value, String name) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, name, 'Must not be blank.');
    }
    return value;
  }

  static DateTime _requireUtc(DateTime value) {
    if (!value.isUtc) throw ArgumentError.value(value, 'now', 'Must be UTC.');
    return value.toUtc();
  }
}

class _Checkpoint {
  const _Checkpoint({
    required this.deviceId,
    required this.observedAtUtc,
    required this.timezoneId,
    required this.schedules,
  });

  final String deviceId;
  final DateTime observedAtUtc;
  final String timezoneId;
  final List<_ScheduleCheckpoint> schedules;

  String encode() => jsonEncode({
    'version': 1,
    'deviceId': deviceId,
    'observedAtUtc': observedAtUtc.toIso8601String(),
    'timezoneId': timezoneId,
    'schedules': [for (final schedule in schedules) schedule.toJson()],
  });

  static _Checkpoint? tryDecode(String? value) {
    try {
      final data = jsonDecode(value ?? '');
      if (data is! Map<String, dynamic> ||
          !_exactKeys(data, const {
            'version',
            'deviceId',
            'observedAtUtc',
            'timezoneId',
            'schedules',
          }) ||
          data['version'] != 1) {
        return null;
      }
      final deviceId = _string(data['deviceId']);
      final timezoneId = _string(data['timezoneId']);
      final observedAtUtc = _utc(data['observedAtUtc']);
      final rawSchedules = data['schedules'];
      if (rawSchedules is! List) return null;
      final schedules = <_ScheduleCheckpoint>[];
      final ids = <String>{};
      String? previousId;
      for (final raw in rawSchedules) {
        if (raw is! Map<String, dynamic>) {
          return null;
        }
        final schedule = _ScheduleCheckpoint.tryDecode(raw);
        if (schedule == null ||
            !ids.add(schedule.id) ||
            (previousId != null && previousId.compareTo(schedule.id) >= 0)) {
          return null;
        }
        previousId = schedule.id;
        schedules.add(schedule);
      }
      if (deviceId == null || timezoneId == null || observedAtUtc == null) {
        return null;
      }
      return _Checkpoint(
        deviceId: deviceId,
        observedAtUtc: observedAtUtc,
        timezoneId: timezoneId,
        schedules: schedules,
      );
    } catch (_) {
      return null;
    }
  }

  static String? _string(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;

  static bool _exactKeys(Map<String, dynamic> data, Set<String> keys) =>
      data.length == keys.length && data.keys.toSet().containsAll(keys);

  static DateTime? _utc(Object? value) {
    if (value is! String) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null || !parsed.isUtc || parsed.toIso8601String() != value) {
      return null;
    }
    return parsed;
  }
}

class _ScheduleCheckpoint {
  const _ScheduleCheckpoint({
    required this.id,
    required this.revision,
    required this.hour,
    required this.minute,
    required this.prescriptionId,
    required this.profileId,
    required this.isEnabled,
    required this.createdAtUtc,
  });

  final String id;
  final int revision;
  final int hour;
  final int minute;
  final String? prescriptionId;
  final String profileId;
  final bool isEnabled;
  final DateTime createdAtUtc;

  factory _ScheduleCheckpoint.fromRow(ReminderScheduleRow row) {
    if (row.id.trim().isEmpty ||
        row.revision <= 0 ||
        row.hour < 0 ||
        row.hour > 23 ||
        row.minute < 0 ||
        row.minute > 59 ||
        row.profileId.trim().isEmpty) {
      throw FormatException('Invalid current reminder schedule.');
    }
    return _ScheduleCheckpoint(
      id: row.id,
      revision: row.revision,
      hour: row.hour,
      minute: row.minute,
      prescriptionId: row.prescriptionId,
      profileId: row.profileId,
      isEnabled: row.isEnabled,
      createdAtUtc: row.createdAt.toUtc(),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'revision': revision,
    'hour': hour,
    'minute': minute,
    'prescriptionId': prescriptionId,
    'profileId': profileId,
    'isEnabled': isEnabled,
    'createdAtUtc': createdAtUtc.toIso8601String(),
  };

  static _ScheduleCheckpoint? tryDecode(Map<String, dynamic> data) {
    if (!_Checkpoint._exactKeys(data, const {
      'id',
      'revision',
      'hour',
      'minute',
      'prescriptionId',
      'profileId',
      'isEnabled',
      'createdAtUtc',
    })) {
      return null;
    }
    final id = data['id'];
    final revision = data['revision'];
    final hour = data['hour'];
    final minute = data['minute'];
    final prescriptionId = data['prescriptionId'];
    final profileId = data['profileId'];
    final isEnabled = data['isEnabled'];
    final createdAtUtc = _Checkpoint._utc(data['createdAtUtc']);
    if (id is! String ||
        id.trim().isEmpty ||
        revision is! int ||
        revision <= 0 ||
        hour is! int ||
        hour < 0 ||
        hour > 23 ||
        minute is! int ||
        minute < 0 ||
        minute > 59 ||
        (prescriptionId != null && prescriptionId is! String) ||
        profileId is! String ||
        profileId.trim().isEmpty ||
        isEnabled is! bool ||
        createdAtUtc == null) {
      return null;
    }
    return _ScheduleCheckpoint(
      id: id,
      revision: revision,
      hour: hour,
      minute: minute,
      prescriptionId: prescriptionId as String?,
      profileId: profileId,
      isEnabled: isEnabled,
      createdAtUtc: createdAtUtc,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _ScheduleCheckpoint &&
      id == other.id &&
      revision == other.revision &&
      hour == other.hour &&
      minute == other.minute &&
      prescriptionId == other.prescriptionId &&
      profileId == other.profileId &&
      isEnabled == other.isEnabled &&
      createdAtUtc == other.createdAtUtc;

  @override
  int get hashCode => Object.hash(
    id,
    revision,
    hour,
    minute,
    prescriptionId,
    profileId,
    isEnabled,
    createdAtUtc,
  );
}
