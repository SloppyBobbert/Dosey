import 'package:dosey_app/core/reminders/reminder_occurrence.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class ReminderOccurrenceResolver {
  const ReminderOccurrenceResolver();

  ReminderOccurrence resolve({
    required ReminderSchedule schedule,
    required DateTime localDate,
    required String timezoneId,
  }) {
    final location = _location(timezoneId);
    final scheduledLocal = timezone.TZDateTime(
      location,
      localDate.year,
      localDate.month,
      localDate.day,
      schedule.hour,
      schedule.minute,
    );
    return ReminderOccurrence(
      scheduleId: schedule.id,
      scheduleRevision: schedule.revision,
      scheduledAt: scheduledLocal.toUtc(),
      localDate: _dateString(scheduledLocal),
      timezoneId: timezoneId,
    );
  }

  DateTime localDateFor(DateTime instant, String timezoneId) {
    final local = timezone.TZDateTime.from(
      instant.toUtc(),
      _location(timezoneId),
    );
    return DateTime.utc(local.year, local.month, local.day);
  }

  static timezone.Location _location(String timezoneId) {
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
}
