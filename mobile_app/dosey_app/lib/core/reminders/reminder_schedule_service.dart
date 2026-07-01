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

  Future<ReminderScheduleSaveResult> saveSchedule(
    ReminderSchedule schedule,
  ) async {
    await repository.upsertSchedule(schedule);
    try {
      if (!schedule.isEnabled) {
        await scheduler.cancelDoseReminder(schedule.id);
        return const ReminderScheduleSaveResult.saved();
      }
      await scheduler.requestPermission();
      await _scheduleNotification(schedule);
      return const ReminderScheduleSaveResult.saved();
    } on Object catch (error) {
      return ReminderScheduleSaveResult.saved(notificationError: error);
    }
  }

  Future<void> syncScheduledNotifications() async {
    final schedules = await repository.watchSchedules().first;
    for (final schedule in schedules.where((schedule) => !schedule.isEnabled)) {
      await scheduler.cancelDoseReminder(schedule.id);
    }
    for (final schedule in schedules.where((schedule) => schedule.isEnabled)) {
      await _scheduleNotification(schedule);
    }
  }

  Future<void> sendTestNotification() async {
    await scheduler.requestPermission();
    await scheduler.scheduleDoseReminder(
      doseId: 'dosey-test-reminder',
      scheduledFor: _now().add(const Duration(seconds: 5)),
      label: 'Dosey test reminder',
      repeatsDaily: false,
    );
  }

  Future<void> deleteSchedule(String id) async {
    await scheduler.cancelDoseReminder(id);
    await repository.deleteSchedule(id);
  }

  Future<void> _scheduleNotification(ReminderSchedule schedule) {
    return scheduler.scheduleDoseReminder(
      doseId: schedule.id,
      scheduledFor: _nextOccurrence(schedule),
      label: schedule.label,
      repeatsDaily: true,
    );
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
    if (!today.isBefore(current)) {
      return today;
    }
    return today.add(const Duration(days: 1));
  }
}

class ReminderScheduleSaveResult {
  const ReminderScheduleSaveResult.saved({this.notificationError});

  final Object? notificationError;

  bool get hasNotificationWarning => notificationError != null;
}
