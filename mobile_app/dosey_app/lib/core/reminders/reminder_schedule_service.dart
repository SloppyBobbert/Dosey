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
    // Persist first. Notification failures should warn the user, not discard
    // the reminder they just configured.
    await repository.upsertSchedule(schedule);
    try {
      if (!schedule.isEnabled) {
        await scheduler.cancelDoseReminder(schedule.id);
        return const ReminderScheduleSaveResult.persisted();
      }
      await scheduler.requestPermission();
      await _scheduleNotification(schedule);
      return const ReminderScheduleSaveResult.persisted();
    } on Exception catch (error) {
      return ReminderScheduleSaveResult.persisted(notificationError: error);
    }
  }

  Future<void> syncScheduledNotifications() async {
    final schedules = await repository.watchSchedules().first;
    for (final schedule in schedules.where((schedule) => !schedule.isEnabled)) {
      try {
        await scheduler.cancelDoseReminder(schedule.id);
      } on Exception {
        // Startup reconciliation is best-effort; keep processing other schedules.
      }
    }
    for (final schedule in schedules.where((schedule) => schedule.isEnabled)) {
      try {
        await _scheduleNotification(schedule);
      } on Exception {
        // Startup reconciliation is best-effort; keep processing other schedules.
      }
    }
  }

  Future<ReminderScheduleSaveResult> sendTestNotification() async {
    try {
      await scheduler.requestPermission();
      await scheduler.scheduleDoseReminder(
        doseId: 'dosey-test-reminder',
        scheduledFor: _now().add(const Duration(seconds: 5)),
        label: 'Dosey test reminder',
        repeatsDaily: false,
      );
      return const ReminderScheduleSaveResult.persisted();
    } on Exception catch (error) {
      return ReminderScheduleSaveResult.persisted(notificationError: error);
    }
  }

  Future<ReminderScheduleDeleteResult> deleteSchedule(String id) async {
    try {
      await scheduler.cancelDoseReminder(id);
    } on Exception catch (error) {
      // Keep the schedule if the platform reminder may still exist; otherwise
      // the user would lose the only local handle to cancel it later.
      return ReminderScheduleDeleteResult.retained(notificationError: error);
    }
    await repository.deleteSchedule(id);
    return const ReminderScheduleDeleteResult.deleted();
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
    // Daily reminders missed for today roll to tomorrow instead of firing
    // immediately on save/startup.
    return today.add(const Duration(days: 1));
  }
}

class ReminderScheduleSaveResult {
  const ReminderScheduleSaveResult.persisted({this.notificationError});

  final Object? notificationError;

  bool get hasNotificationWarning => notificationError != null;
}

class ReminderScheduleDeleteResult {
  const ReminderScheduleDeleteResult._({
    required this.deleted,
    this.notificationError,
  });

  const ReminderScheduleDeleteResult.deleted() : this._(deleted: true);

  const ReminderScheduleDeleteResult.retained({
    required Object notificationError,
  }) : this._(deleted: false, notificationError: notificationError);

  final bool deleted;
  final Object? notificationError;

  bool get hasNotificationWarning => notificationError != null;
}
