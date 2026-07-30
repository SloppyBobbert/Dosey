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
    required this.occurrence,
    required this.status,
    this.event,
    this.hasTerminalOutcome = false,
  });

  final CaregiverSchedule schedule;
  final CaregiverMedication medication;
  final DateTime scheduledFor;
  final CaregiverOccurrence occurrence;
  final CaregiverDoseStatus status;
  final CaregiverDoseEvent? event;
  final bool hasTerminalOutcome;
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
    final occurrence = _occurrence(schedule, scheduledFor);
    final events =
        snapshot.events
            .where((candidate) => _matchesOccurrence(candidate, occurrence))
            .toList()
          ..sort(_compareEvents);
    final terminalEvents = events.where(_isTerminal).toList();
    final event = terminalEvents.isNotEmpty
        ? terminalEvents.last
        : events.lastOrNull;
    result.add(
      CaregiverDoseProjection(
        schedule: schedule,
        medication: medication,
        scheduledFor: scheduledFor,
        occurrence: occurrence,
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
        hasTerminalOutcome: terminalEvents.isNotEmpty,
      ),
    );
  }
  result.sort((left, right) {
    final scheduledFor = left.scheduledFor.compareTo(right.scheduledFor);
    if (scheduledFor != 0) return scheduledFor;
    final scheduleId = left.occurrence.scheduleId.compareTo(
      right.occurrence.scheduleId,
    );
    if (scheduleId != 0) return scheduleId;
    return left.occurrence.occurrenceId.compareTo(
      right.occurrence.occurrenceId,
    );
  });
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

bool _isTerminal(CaregiverDoseEvent event) =>
    event.action == CaregiverDoseAction.taken ||
    event.action == CaregiverDoseAction.skipped;

int _compareEvents(CaregiverDoseEvent left, CaregiverDoseEvent right) {
  final occurredAt = left.occurredAt.compareTo(right.occurredAt);
  return occurredAt != 0 ? occurredAt : left.id.compareTo(right.id);
}

CaregiverOccurrence _occurrence(
  CaregiverSchedule schedule,
  DateTime scheduledFor,
) => CaregiverOccurrence(
  occurrenceId:
      '${schedule.id}:${schedule.version}:${_canonicalUtc(scheduledFor)}',
  scheduleId: schedule.id,
  scheduleRevision: schedule.version,
  scheduledFor: scheduledFor,
  timezoneId: schedule.timezoneId,
  localDate: _localDate(scheduledFor, schedule.timezoneId),
);

bool _matchesOccurrence(
  CaregiverDoseEvent event,
  CaregiverOccurrence occurrence,
) =>
    event.occurrenceId == occurrence.occurrenceId &&
    event.scheduleId == occurrence.scheduleId &&
    event.scheduleRevision == occurrence.scheduleRevision &&
    event.scheduledFor.toUtc() == occurrence.scheduledFor.toUtc() &&
    event.timezoneId == occurrence.timezoneId &&
    event.localDate == occurrence.localDate;

String _canonicalUtc(DateTime instant) {
  final value = instant.toUtc();
  String digits(int number, int width) => number.toString().padLeft(width, '0');
  return '${digits(value.year, 4)}-${digits(value.month, 2)}-'
      '${digits(value.day, 2)}T${digits(value.hour, 2)}:'
      '${digits(value.minute, 2)}:${digits(value.second, 2)}.'
      '${digits(value.millisecond, 3)}Z';
}

String _localDate(DateTime scheduledFor, String timezoneId) {
  if (!timezone.timeZoneDatabase.isInitialized) {
    timezone_data.initializeTimeZones();
  }
  final location = timezoneId == 'UTC'
      ? timezone.UTC
      : timezone.getLocation(timezoneId);
  final local = timezone.TZDateTime.from(scheduledFor, location);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
      '${two(local.day)}';
}

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
