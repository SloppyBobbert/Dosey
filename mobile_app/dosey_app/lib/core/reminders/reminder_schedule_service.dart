import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';

class ReminderScheduleService {
  ReminderScheduleService({
    required this.repository,
    required this.scheduler,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ReminderRepository repository;
  final ReminderScheduler scheduler;
  final DateTime Function() _now;

  Future<void> saveSchedule(ReminderSchedule schedule) async {
    await repository.upsertSchedule(schedule);
    if (!schedule.isEnabled) {
      await scheduler.cancelDoseReminder(schedule.id);
      return;
    }
    await scheduler.requestPermission();
    await scheduler.scheduleDoseReminder(
      doseId: schedule.id,
      scheduledFor: _nextOccurrence(schedule),
      label: schedule.label,
      repeatsDaily: true,
    );
  }

  Future<void> deleteSchedule(String id) async {
    await scheduler.cancelDoseReminder(id);
    await repository.deleteSchedule(id);
  }

  DateTime _nextOccurrence(ReminderSchedule schedule) {
    final current = _now();
    final today = DateTime(
      current.year,
      current.month,
      current.day,
      schedule.hour,
      schedule.minute,
    );
    if (today.isAfter(current)) {
      return today;
    }
    return today.add(const Duration(days: 1));
  }
}
