import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/reminders/reminder_schedule_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('enabled save persists and schedules a daily notification', () async {
    final repository = _FakeReminderRepository();
    final scheduler = _FakeReminderScheduler();
    final service = ReminderScheduleService(
      repository: repository,
      scheduler: scheduler,
      now: () => DateTime(2026, 6, 29, 7, 15),
    );
    final schedule = _schedule(
      id: 'morning-vitamin',
      label: 'Vitamin D',
      hour: 8,
      minute: 30,
      isEnabled: true,
    );

    await service.saveSchedule(schedule);

    expect(repository.savedSchedules, [schedule]);
    expect(scheduler.permissionRequests, 1);
    expect(scheduler.scheduledReminders, [
      _ScheduledReminder(
        doseId: 'morning-vitamin',
        scheduledFor: DateTime(2026, 6, 29, 8, 30),
        label: 'Vitamin D',
        repeatsDaily: true,
      ),
    ]);
    expect(scheduler.cancelledDoseIds, isEmpty);
    expect(repository.operations, ['save:morning-vitamin']);
    expect(scheduler.operations, ['permission', 'schedule:morning-vitamin']);
  });

  test('enabled save schedules tomorrow when today time has passed', () async {
    final repository = _FakeReminderRepository();
    final scheduler = _FakeReminderScheduler();
    final service = ReminderScheduleService(
      repository: repository,
      scheduler: scheduler,
      now: () => DateTime(2026, 6, 29, 21, 0),
    );

    await service.saveSchedule(
      _schedule(
        id: 'evening-dose',
        label: 'Evening dose',
        hour: 20,
        minute: 0,
        isEnabled: true,
      ),
    );

    expect(
      scheduler.scheduledReminders.single.scheduledFor,
      DateTime(2026, 6, 30, 20),
    );
  });

  test('disabled save persists and cancels the notification', () async {
    final repository = _FakeReminderRepository();
    final scheduler = _FakeReminderScheduler();
    final service = ReminderScheduleService(
      repository: repository,
      scheduler: scheduler,
      now: () => DateTime(2026, 6, 29, 7, 15),
    );
    final schedule = _schedule(
      id: 'morning-vitamin',
      label: 'Vitamin D',
      hour: 8,
      minute: 30,
      isEnabled: false,
    );

    await service.saveSchedule(schedule);

    expect(repository.savedSchedules, [schedule]);
    expect(scheduler.permissionRequests, 0);
    expect(scheduler.scheduledReminders, isEmpty);
    expect(scheduler.cancelledDoseIds, ['morning-vitamin']);
  });

  test('delete cancels notification before deleting the schedule', () async {
    final repository = _FakeReminderRepository();
    final scheduler = _FakeReminderScheduler();
    final operations = <String>[];
    repository.sharedOperations = operations;
    scheduler.sharedOperations = operations;
    final service = ReminderScheduleService(
      repository: repository,
      scheduler: scheduler,
      now: () => DateTime(2026, 6, 29, 7, 15),
    );

    await service.deleteSchedule('morning-vitamin');

    expect(scheduler.cancelledDoseIds, ['morning-vitamin']);
    expect(repository.deletedScheduleIds, ['morning-vitamin']);
    expect(operations, ['cancel:morning-vitamin', 'delete:morning-vitamin']);
  });

  test('scheduling failure surfaces after saving schedule', () async {
    final repository = _FakeReminderRepository();
    final scheduler = _FakeReminderScheduler()
      ..scheduleError = StateError('notifications unavailable');
    final service = ReminderScheduleService(
      repository: repository,
      scheduler: scheduler,
      now: () => DateTime(2026, 6, 29, 7, 15),
    );
    final schedule = _schedule(
      id: 'morning-vitamin',
      label: 'Vitamin D',
      hour: 8,
      minute: 30,
      isEnabled: true,
    );

    expect(() => service.saveSchedule(schedule), throwsA(isA<StateError>()));
    expect(repository.savedSchedules, [schedule]);
  });
}

ReminderSchedule _schedule({
  required String id,
  required String label,
  required int hour,
  required int minute,
  required bool isEnabled,
}) {
  final now = DateTime.utc(2026, 6, 29, 7, 15);
  return ReminderSchedule(
    id: id,
    label: label,
    hour: hour,
    minute: minute,
    isEnabled: isEnabled,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeReminderRepository implements ReminderRepository {
  final savedSchedules = <ReminderSchedule>[];
  final deletedScheduleIds = <String>[];
  final operations = <String>[];
  List<String>? sharedOperations;

  @override
  Stream<List<ReminderSchedule>> watchSchedules({String? profileId}) {
    return Stream<List<ReminderSchedule>>.value(savedSchedules);
  }

  @override
  Future<void> upsertSchedule(ReminderSchedule schedule) async {
    savedSchedules.add(schedule);
    operations.add('save:${schedule.id}');
    sharedOperations?.add('save:${schedule.id}');
  }

  @override
  Future<void> deleteSchedule(String id) async {
    deletedScheduleIds.add(id);
    operations.add('delete:$id');
    sharedOperations?.add('delete:$id');
  }
}

class _FakeReminderScheduler implements ReminderScheduler {
  int permissionRequests = 0;
  final scheduledReminders = <_ScheduledReminder>[];
  final cancelledDoseIds = <String>[];
  final operations = <String>[];
  List<String>? sharedOperations;
  Object? scheduleError;

  @override
  Future<void> requestPermission() async {
    permissionRequests += 1;
    operations.add('permission');
    sharedOperations?.add('permission');
  }

  @override
  Future<void> scheduleDoseReminder({
    required String doseId,
    required DateTime scheduledFor,
    required String label,
    required bool repeatsDaily,
  }) async {
    final error = scheduleError;
    if (error != null) throw error;
    scheduledReminders.add(
      _ScheduledReminder(
        doseId: doseId,
        scheduledFor: scheduledFor,
        label: label,
        repeatsDaily: repeatsDaily,
      ),
    );
    operations.add('schedule:$doseId');
    sharedOperations?.add('schedule:$doseId');
  }

  @override
  Future<void> cancelDoseReminder(String doseId) async {
    cancelledDoseIds.add(doseId);
    operations.add('cancel:$doseId');
    sharedOperations?.add('cancel:$doseId');
  }
}

class _ScheduledReminder {
  const _ScheduledReminder({
    required this.doseId,
    required this.scheduledFor,
    required this.label,
    required this.repeatsDaily,
  });

  final String doseId;
  final DateTime scheduledFor;
  final String label;
  final bool repeatsDaily;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _ScheduledReminder &&
            other.doseId == doseId &&
            other.scheduledFor == scheduledFor &&
            other.label == label &&
            other.repeatsDaily == repeatsDaily;
  }

  @override
  int get hashCode => Object.hash(doseId, scheduledFor, label, repeatsDaily);
}
