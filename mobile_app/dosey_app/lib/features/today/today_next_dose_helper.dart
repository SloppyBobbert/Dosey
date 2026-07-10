import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';

class TodayNextDoseHelper {
  const TodayNextDoseHelper._();

  static final Set<String> _terminalDoseEventKinds = <String>{
    DoseLogEventKind.doseTakenConfirmed.name,
    DoseLogEventKind.doseAlreadyTaken.name,
    DoseLogEventKind.doseTakenEarly.name,
    DoseLogEventKind.doseTakenLate.name,
    DoseLogEventKind.doseSkipped.name,
    DoseLogEventKind.doseMissed.name,
  };

  static final List<String> _terminalDoseEventKindNames =
      List<String>.unmodifiable(_terminalDoseEventKinds);

  static ReminderSchedule? currentSchedule(
    List<ReminderSchedule> schedules,
    List<DoseLogEvent> events, {
    DateTime? now,
  }) {
    final referenceTime = now ?? DateTime.now();
    for (final schedule in schedules) {
      final doseId = doseIdForDate(schedule.id, referenceTime);
      if (schedule.isEnabled && !hasTerminalEventForDose(events, doseId)) {
        return schedule;
      }
    }
    return null;
  }

  static ReminderSchedule? currentOrLatestDueSchedule(
    List<ReminderSchedule> schedules,
    List<DoseLogEvent> events, {
    DateTime? now,
  }) {
    final referenceTime = now ?? DateTime.now();
    ReminderSchedule? latestDueSchedule;
    DateTime? latestDueTime;

    for (final schedule in schedules) {
      if (!schedule.isEnabled) {
        continue;
      }
      final scheduledTime = DateTime(
        referenceTime.year,
        referenceTime.month,
        referenceTime.day,
        schedule.hour,
        schedule.minute,
      );
      if (scheduledTime.isAfter(referenceTime)) {
        continue;
      }
      // Remember the latest due schedule even if it is resolved, so Today and
      // Robot Face do not jump ahead before the current dose state is visible.
      if (latestDueTime == null || scheduledTime.isAfter(latestDueTime)) {
        latestDueTime = scheduledTime;
        latestDueSchedule = schedule;
      }

      final doseId = doseIdForDate(schedule.id, referenceTime);
      if (!hasTerminalEventForDose(events, doseId)) {
        return schedule;
      }
    }

    return latestDueSchedule ??
        currentSchedule(schedules, events, now: referenceTime);
  }

  static DoseLogEvent? latestEventForDose(
    List<DoseLogEvent> events,
    String doseId,
  ) {
    DoseLogEvent? latest;
    for (final event in events) {
      // Log streams are usually newest-first, but compare timestamps so callers
      // are correct even after database or test ordering changes.
      if (event.doseId == doseId &&
          (latest == null || event.occurredAt.isAfter(latest.occurredAt))) {
        latest = event;
      }
    }
    return latest;
  }

  static bool hasTerminalEventForDose(
    List<DoseLogEvent> events,
    String doseId,
  ) {
    for (final event in events) {
      if (event.doseId == doseId && isTerminalDoseEventKind(event.kind)) {
        return true;
      }
    }
    return false;
  }

  static bool isTerminalDoseEventKind(DoseLogEventKind kind) {
    return _terminalDoseEventKinds.contains(kind.name);
  }

  static List<String> get terminalDoseEventKindNames =>
      _terminalDoseEventKindNames;

  static String doseIdForDate(String scheduleId, DateTime now) {
    // Dose ids are per local calendar day, matching how daily reminders are
    // shown and resolved in the prototype.
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$scheduleId:${now.year}-$month-$day';
  }
}
