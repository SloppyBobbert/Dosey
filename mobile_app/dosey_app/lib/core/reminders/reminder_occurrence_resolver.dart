import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class ReminderOccurrenceResolver {
  const ReminderOccurrenceResolver();

  ResolvedReminderTime resolve({
    required DateTime localDate,
    required int hour,
    required int minute,
    required String timezoneId,
  }) => resolveAtLocation(
    localDate: localDate,
    hour: hour,
    minute: minute,
    location: locationFor(timezoneId),
  );

  ResolvedReminderTime resolveAtLocation({
    required DateTime localDate,
    required int hour,
    required int minute,
    required timezone.Location location,
  }) {
    _validateLocalDateMarker(localDate);
    if (hour < 0 || hour > 23) {
      throw ArgumentError.value(hour, 'hour', 'Must be 0 through 23.');
    }
    if (minute < 0 || minute > 59) {
      throw ArgumentError.value(minute, 'minute', 'Must be 0 through 59.');
    }
    final scheduledLocal = timezone.TZDateTime(
      location,
      localDate.year,
      localDate.month,
      localDate.day,
      hour,
      minute,
    );
    return ResolvedReminderTime(
      scheduledAtUtc: scheduledLocal.toUtc(),
      localDate: _dateString(scheduledLocal),
    );
  }

  DateTime localDateFor(DateTime instant, String timezoneId) {
    return localDateForLocation(instant, locationFor(timezoneId));
  }

  DateTime localDateForLocation(DateTime instant, timezone.Location location) {
    final local = timezone.TZDateTime.from(instant.toUtc(), location);
    return DateTime.utc(local.year, local.month, local.day);
  }

  timezone.Location locationFor(String timezoneId) {
    if (!timezone.timeZoneDatabase.isInitialized) {
      timezone_data.initializeTimeZones();
    }
    if (!timezone.timeZoneDatabase.locations.containsKey(timezoneId)) {
      throw FormatException('Unsupported timezone: "$timezoneId".');
    }
    return timezone.getLocation(timezoneId);
  }

  static String _dateString(timezone.TZDateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static void _validateLocalDateMarker(DateTime value) {
    if (!value.isUtc ||
        value.year < 1 ||
        value.year > 9999 ||
        value.hour != 0 ||
        value.minute != 0 ||
        value.second != 0 ||
        value.millisecond != 0 ||
        value.microsecond != 0) {
      throw ArgumentError.value(
        value,
        'localDate',
        'Must be a UTC midnight date marker.',
      );
    }
  }
}

class ResolvedReminderTime {
  const ResolvedReminderTime({
    required this.scheduledAtUtc,
    required this.localDate,
  });

  final DateTime scheduledAtUtc;
  final String localDate;
}
