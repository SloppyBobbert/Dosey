import 'package:dosey_app/core/audit/admin_audit_event.dart';
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
    ReminderSchedule schedule, {
    AdminAuditEvent? auditEvent,
  }) async {
    // Persist first. Notification failures should warn the user, not discard
    // the reminder they just configured.
    await repository.upsertSchedule(schedule, auditEvent: auditEvent);
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

  Future<NotificationRepairResult> syncScheduledNotifications() async {
    final schedules = await repository.watchSchedules().first;
    var attemptedCount = 0;
    var succeededCount = 0;
    final failures = <NotificationRepairFailure>[];
    for (final schedule in schedules.where((schedule) => !schedule.isEnabled)) {
      attemptedCount += 1;
      try {
        await scheduler.cancelDoseReminder(schedule.id);
        succeededCount += 1;
      } on Exception catch (error, stackTrace) {
        failures.add(
          NotificationRepairFailure(
            scheduleId: schedule.id,
            operation: NotificationRepairOperation.cancel,
            error: error,
            stackTrace: stackTrace,
          ),
        );
      }
    }
    for (final schedule in schedules.where((schedule) => schedule.isEnabled)) {
      attemptedCount += 1;
      try {
        await _scheduleNotification(schedule);
        succeededCount += 1;
      } on Exception catch (error, stackTrace) {
        failures.add(
          NotificationRepairFailure(
            scheduleId: schedule.id,
            operation: NotificationRepairOperation.schedule,
            error: error,
            stackTrace: stackTrace,
          ),
        );
      }
    }
    return NotificationRepairResult(
      attemptedCount: attemptedCount,
      succeededCount: succeededCount,
      failures: failures,
    );
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

  Future<ReminderScheduleDeleteResult> deleteSchedule(
    String id, {
    AdminAuditEvent? auditEvent,
  }) async {
    try {
      await scheduler.cancelDoseReminder(id);
    } on Exception catch (error) {
      // Keep the schedule if the platform reminder may still exist; otherwise
      // the user would lose the only local handle to cancel it later.
      return ReminderScheduleDeleteResult.retained(notificationError: error);
    }
    final deleted = await repository.deleteSchedule(id, auditEvent: auditEvent);
    if (deleted == 0) {
      return const ReminderScheduleDeleteResult.retainedWithoutWarning();
    }
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

enum NotificationRepairOperation { cancel, schedule }

class NotificationRepairFailure {
  const NotificationRepairFailure({
    required this.scheduleId,
    required this.operation,
    required this.error,
    required this.stackTrace,
  });

  final String scheduleId;
  final NotificationRepairOperation operation;
  final Object error;
  final StackTrace stackTrace;
}

class NotificationRepairResult {
  NotificationRepairResult({
    required this.attemptedCount,
    required this.succeededCount,
    required List<NotificationRepairFailure> failures,
  }) : failures = List.unmodifiable(failures);

  final int attemptedCount;
  final int succeededCount;
  final List<NotificationRepairFailure> failures;
  bool get hasFailures => failures.isNotEmpty;
}

class NotificationRepairException implements Exception {
  const NotificationRepairException(this.result);
  final NotificationRepairResult result;
  @override
  String toString() =>
      'Notification repair failed for ${result.failures.length} schedule(s).';
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

  const ReminderScheduleDeleteResult.retainedWithoutWarning()
    : this._(deleted: false);

  final bool deleted;
  final Object? notificationError;

  bool get hasNotificationWarning => notificationError != null;
}
