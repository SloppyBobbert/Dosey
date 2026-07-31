import 'package:dosey_app/core/reminders/reminder_occurrence.dart';
import 'package:dosey_app/core/reminders/reminder_occurrence_resolver.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';

class ReminderOccurrenceProjection {
  ReminderOccurrenceProjection(this._database);

  final DoseyDatabase _database;
  static const _resolver = ReminderOccurrenceResolver();

  /// Projects prospective occurrences from the caller's actual observation
  /// instant [asOf], not from a historical query point.
  Future<List<ReminderOccurrence>> project({
    required DateTime asOf,
    required DateTime fromInclusive,
    required DateTime toExclusive,
    required String timezoneId,
    String? profileId,
  }) async {
    _validateRange(asOf, fromInclusive, toExclusive);
    final location = _resolver.locationFor(timezoneId);

    final query = _database.select(_database.reminderSchedules);
    if (profileId != null) {
      query.where((row) => row.profileId.equals(profileId));
    }
    final schedules = await query.get();
    final firstDate = _resolver.localDateForLocation(fromInclusive, location);
    final lastDate = _resolver.localDateForLocation(toExclusive, location);
    final occurrences = <ReminderOccurrence>[];

    for (
      var date = firstDate;
      !date.isAfter(lastDate);
      date = date.add(const Duration(days: 1))
    ) {
      for (final schedule in schedules) {
        final prescriptionId = schedule.prescriptionId;
        if (!schedule.isEnabled ||
            prescriptionId == null ||
            prescriptionId.trim().isEmpty) {
          continue;
        }
        final resolved = _resolver.resolveAtLocation(
          localDate: date,
          hour: schedule.hour,
          minute: schedule.minute,
          location: location,
        );
        final scheduledAtUtc = resolved.scheduledAtUtc;
        if (scheduledAtUtc.isBefore(asOf) ||
            scheduledAtUtc.isBefore(fromInclusive) ||
            !scheduledAtUtc.isBefore(toExclusive)) {
          continue;
        }
        occurrences.add(
          ReminderOccurrence(
            scheduleId: schedule.id,
            scheduleRevision: schedule.revision,
            scheduledAtUtc: scheduledAtUtc,
            localDate: resolved.localDate,
            timezoneId: timezoneId,
            medicationId: prescriptionId,
            profileId: schedule.profileId,
          ),
        );
      }
    }
    occurrences.sort((first, second) {
      final scheduledAt = first.scheduledAtUtc.compareTo(second.scheduledAtUtc);
      if (scheduledAt != 0) return scheduledAt;
      final scheduleId = first.scheduleId.compareTo(second.scheduleId);
      if (scheduleId != 0) return scheduleId;
      return first.scheduleRevision.compareTo(second.scheduleRevision);
    });
    return occurrences;
  }

  static void _validateRange(
    DateTime asOf,
    DateTime fromInclusive,
    DateTime toExclusive,
  ) {
    if (!asOf.isUtc || !fromInclusive.isUtc || !toExclusive.isUtc) {
      throw ArgumentError('asOf, fromInclusive, and toExclusive must be UTC.');
    }
    if (fromInclusive.isBefore(asOf)) {
      throw ArgumentError.value(
        fromInclusive,
        'fromInclusive',
        'Must not be before asOf.',
      );
    }
    if (!toExclusive.isAfter(fromInclusive)) {
      throw ArgumentError.value(
        toExclusive,
        'toExclusive',
        'Must be after fromInclusive.',
      );
    }
  }
}
