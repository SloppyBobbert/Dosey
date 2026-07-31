import 'package:dosey_app/core/reminders/reminder_occurrence_resolver.dart';
import 'package:timezone/timezone.dart' as timezone;

class ReminderOccurrence {
  ReminderOccurrence({
    required this.scheduleId,
    required this.scheduleRevision,
    required DateTime scheduledAtUtc,
    required this.localDate,
    required this.timezoneId,
    required this.medicationId,
    required this.profileId,
  }) : scheduledAtUtc = _requireUtc(scheduledAtUtc) {
    _requireNonBlank(scheduleId, 'scheduleId');
    _requireNonBlank(timezoneId, 'timezoneId');
    _requireNonBlank(medicationId, 'medicationId');
    _requireNonBlank(profileId, 'profileId');
    if (scheduleRevision <= 0) {
      throw ArgumentError.value(
        scheduleRevision,
        'scheduleRevision',
        'Must be positive.',
      );
    }
    _requireLocalDate(
      localDate,
      scheduledAtUtc,
      const ReminderOccurrenceResolver().locationFor(timezoneId),
    );
  }

  final String scheduleId;
  final int scheduleRevision;
  final DateTime scheduledAtUtc;
  final String localDate;
  final String timezoneId;
  final String medicationId;
  final String profileId;

  String get id =>
      '$scheduleId:$scheduleRevision:${scheduledAtUtc.toIso8601String()}';

  String get occurrenceId => id;

  DateTime get scheduledAt => scheduledAtUtc;

  static DateTime _requireUtc(DateTime value) {
    if (!value.isUtc) {
      throw ArgumentError.value(value, 'scheduledAtUtc', 'Must be UTC.');
    }
    return DateTime.fromMicrosecondsSinceEpoch(
      value.microsecondsSinceEpoch,
      isUtc: true,
    );
  }

  static void _requireNonBlank(String value, String name) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, name, 'Must not be blank.');
    }
  }

  static void _requireLocalDate(
    String value,
    DateTime scheduledAtUtc,
    timezone.Location location,
  ) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      throw ArgumentError.value(value, 'localDate', 'Must be YYYY-MM-DD.');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime.utc(year, month, day);
    if (year < 1 ||
        year > 9999 ||
        parsed.year != year ||
        parsed.month != month ||
        parsed.day != day) {
      throw ArgumentError.value(value, 'localDate', 'Must be a real date.');
    }
    final local = timezone.TZDateTime.from(scheduledAtUtc, location);
    final resolved =
        '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
    if (value != resolved) {
      throw ArgumentError.value(
        value,
        'localDate',
        'Must match scheduledAtUtc in timezone.',
      );
    }
  }
}
