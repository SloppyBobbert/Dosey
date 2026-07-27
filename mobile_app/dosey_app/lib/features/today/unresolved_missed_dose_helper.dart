import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/features/today/today_next_dose_helper.dart';

class UnresolvedMissedDose {
  const UnresolvedMissedDose({
    required this.schedule,
    required this.doseId,
    required this.scheduledAt,
  });

  final ReminderSchedule schedule;
  final String doseId;
  final DateTime scheduledAt;
}

class UnresolvedMissedDoseHelper {
  const UnresolvedMissedDoseHelper._();

  static UnresolvedMissedDose? latest(
    List<ReminderSchedule> schedules,
    List<DoseLogEvent> events, {
    required DateTime now,
  }) {
    final startOfToday = now.isUtc
        ? DateTime.utc(now.year, now.month, now.day)
        : DateTime(now.year, now.month, now.day);
    final dates = <DateTime>[
      startOfToday.subtract(const Duration(days: 1)),
      startOfToday,
    ];
    UnresolvedMissedDose? latest;

    for (final schedule in schedules.where((schedule) => schedule.isEnabled)) {
      for (final date in dates) {
        final scheduledAt = TodayNextDoseHelper.scheduledTimeForDate(
          schedule,
          date,
        );
        if (scheduledAt.isAfter(now)) continue;
        final doseId = TodayNextDoseHelper.doseIdForDate(schedule.id, date);
        if (!_isUnresolved(doseId, events)) continue;
        if (latest == null || scheduledAt.isAfter(latest.scheduledAt)) {
          latest = UnresolvedMissedDose(
            schedule: schedule,
            doseId: doseId,
            scheduledAt: scheduledAt,
          );
        }
      }
    }
    return latest;
  }

  static bool _isUnresolved(String doseId, List<DoseLogEvent> events) {
    DateTime? missedAt;
    DateTime? recognizedAt;
    for (final event in events.where((event) => event.doseId == doseId)) {
      if (event.kind == DoseLogEventKind.doseMissed &&
          (missedAt == null || event.occurredAt.isAfter(missedAt))) {
        missedAt = event.occurredAt;
      }
      if (event.kind == DoseLogEventKind.doseMissedRecognized &&
          (recognizedAt == null || event.occurredAt.isAfter(recognizedAt))) {
        recognizedAt = event.occurredAt;
      }
    }
    return missedAt != null &&
        (recognizedAt == null || recognizedAt.isBefore(missedAt));
  }
}
