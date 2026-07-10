import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/features/today/today_next_dose_helper.dart';

class MissedDoseCandidate {
  const MissedDoseCandidate({
    required this.doseId,
    required this.scheduledAt,
    required this.event,
  });

  final String doseId;
  final DateTime scheduledAt;
  final DoseLogEvent event;
}

class MissedDosePolicy {
  const MissedDosePolicy._();

  static MissedDoseCandidate? overdueDoseForDate(
    ReminderSchedule schedule,
    List<DoseLogEvent> events, {
    required DateTime date,
    required DateTime now,
    Duration gracePeriod = const Duration(hours: 2),
  }) {
    if (!schedule.isEnabled) {
      return null;
    }

    final scheduledAt = DateTime(
      date.year,
      date.month,
      date.day,
      schedule.hour,
      schedule.minute,
    );
    if (!_canProveScheduleExistedAt(schedule, scheduledAt)) {
      return null;
    }
    if (!now.isAfter(scheduledAt.add(gracePeriod))) {
      return null;
    }

    final doseId = TodayNextDoseHelper.doseIdForDate(schedule.id, scheduledAt);
    if (TodayNextDoseHelper.hasTerminalEventForDose(events, doseId)) {
      return null;
    }

    return MissedDoseCandidate(
      doseId: doseId,
      scheduledAt: scheduledAt,
      event: DoseLogEvent.doseMissed(doseId: doseId, occurredAt: now),
    );
  }

  static bool _canProveScheduleExistedAt(
    ReminderSchedule schedule,
    DateTime scheduledAt,
  ) {
    return !schedule.createdAt.isAfter(scheduledAt) &&
        !schedule.updatedAt.isAfter(scheduledAt);
  }
}
