import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import 'caregiver_snapshot.dart';

enum CaregiverDoseStatus {
  upcoming,
  due,
  missed,
  taken,
  skipped,
  snoozed,
  helpRequested,
}

class CaregiverDoseProjection {
  const CaregiverDoseProjection({
    required this.schedule,
    required this.medication,
    required this.scheduledFor,
    required this.status,
    this.event,
  });

  final CaregiverSchedule schedule;
  final CaregiverMedication medication;
  final DateTime scheduledFor;
  final CaregiverDoseStatus status;
  final CaregiverDoseEvent? event;
}

List<CaregiverDoseProjection> projectCaregiverDay({
  required CaregiverSnapshot snapshot,
  required DateTime now,
  Duration dueWindow = const Duration(minutes: 30),
}) {
  final medications = {
    for (final medication in snapshot.medications) medication.id: medication,
  };
  final result = <CaregiverDoseProjection>[];
  for (final schedule in snapshot.schedules) {
    final medication = medications[schedule.medicationId];
    if (!schedule.enabled || medication == null || !medication.active) continue;
    final scheduledFor = _scheduledFor(
      now,
      schedule.hour,
      schedule.minute,
      schedule.timezoneId,
    );
    final event = snapshot.events
        .where(
          (candidate) =>
              candidate.scheduleId == schedule.id &&
              _sameMinute(candidate.scheduledFor, scheduledFor),
        )
        .lastOrNull;
    result.add(
      CaregiverDoseProjection(
        schedule: schedule,
        medication: medication,
        scheduledFor: scheduledFor,
        event: event,
        status: event == null
            ? _derivedStatus(now, scheduledFor, dueWindow)
            : switch (event.action) {
                CaregiverDoseAction.taken => CaregiverDoseStatus.taken,
                CaregiverDoseAction.skipped => CaregiverDoseStatus.skipped,
                CaregiverDoseAction.snoozed => CaregiverDoseStatus.snoozed,
                CaregiverDoseAction.helpRequested =>
                  CaregiverDoseStatus.helpRequested,
              },
      ),
    );
  }
  result.sort((left, right) => left.scheduledFor.compareTo(right.scheduledFor));
  return List.unmodifiable(result);
}

CaregiverDoseStatus _derivedStatus(
  DateTime now,
  DateTime scheduledFor,
  Duration dueWindow,
) {
  if (now.isBefore(scheduledFor)) return CaregiverDoseStatus.upcoming;
  if (now.difference(scheduledFor) <= dueWindow) return CaregiverDoseStatus.due;
  return CaregiverDoseStatus.missed;
}

bool _sameMinute(DateTime left, DateTime right) =>
    left.toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute ==
    right.toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute;

DateTime _scheduledFor(DateTime now, int hour, int minute, String timezoneId) {
  if (!timezone.timeZoneDatabase.isInitialized) {
    timezone_data.initializeTimeZones();
  }
  final location = timezoneId == 'UTC'
      ? timezone.UTC
      : timezone.getLocation(timezoneId);
  final localNow = timezone.TZDateTime.from(now, location);
  final instant = timezone.TZDateTime(
    location,
    localNow.year,
    localNow.month,
    localNow.day,
    hour,
    minute,
  ).toUtc();
  return now.isUtc ? instant : instant.toLocal();
}
