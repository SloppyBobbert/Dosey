import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';

abstract interface class ReminderRepository {
  Stream<List<ReminderSchedule>> watchSchedules();

  Future<void> upsertSchedule(ReminderSchedule schedule);

  Future<void> deleteSchedule(String id);
}

class LocalReminderRepository implements ReminderRepository {
  const LocalReminderRepository(this._database);

  final DoseyDatabase _database;

  /// Watches schedules in clock order so Today and Schedule share one ordering.
  @override
  Stream<List<ReminderSchedule>> watchSchedules() {
    final query = _database.select(_database.reminderSchedules)
      ..orderBy([
        (schedule) => OrderingTerm.asc(schedule.hour),
        (schedule) => OrderingTerm.asc(schedule.minute),
      ]);

    return query.watch().map((rows) => rows.map(_fromRow).toList());
  }

  /// Saves schedule timing plus its optional prescription link for newer flows.
  @override
  Future<void> upsertSchedule(ReminderSchedule schedule) {
    _validateSchedule(schedule);

    return _database
        .into(_database.reminderSchedules)
        .insertOnConflictUpdate(
          ReminderSchedulesCompanion.insert(
            id: schedule.id,
            label: schedule.label,
            prescriptionId: Value(schedule.prescriptionId),
            hour: schedule.hour,
            minute: schedule.minute,
            isEnabled: schedule.isEnabled,
            createdAt: schedule.createdAt.toUtc(),
            updatedAt: schedule.updatedAt.toUtc(),
          ),
        );
  }

  @override
  Future<void> deleteSchedule(String id) {
    return (_database.delete(
      _database.reminderSchedules,
    )..where((schedule) => schedule.id.equals(id))).go();
  }

  static ReminderSchedule _fromRow(ReminderScheduleRow row) {
    return ReminderSchedule(
      id: row.id,
      label: row.label,
      prescriptionId: row.prescriptionId,
      hour: row.hour,
      minute: row.minute,
      isEnabled: row.isEnabled,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }

  static void _validateSchedule(ReminderSchedule schedule) {
    if (schedule.hour < 0 || schedule.hour > 23) {
      throw ArgumentError.value(schedule.hour, 'hour', 'Must be 0 through 23.');
    }
    if (schedule.minute < 0 || schedule.minute > 59) {
      throw ArgumentError.value(
        schedule.minute,
        'minute',
        'Must be 0 through 59.',
      );
    }
  }
}
