import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';

abstract interface class ReminderRepository {
  Stream<List<ReminderSchedule>> watchSchedules({String? profileId});

  Future<void> upsertSchedule(ReminderSchedule schedule);

  Future<void> deleteSchedule(String id);
}

class LocalReminderRepository implements ReminderRepository {
  const LocalReminderRepository(this._database);

  final DoseyDatabase _database;

  /// Watches schedules in clock order so Today and Schedule share one ordering.
  @override
  Stream<List<ReminderSchedule>> watchSchedules({String? profileId}) {
    final query = _database.select(_database.reminderSchedules)
      ..orderBy([
        (schedule) => OrderingTerm.asc(schedule.hour),
        (schedule) => OrderingTerm.asc(schedule.minute),
      ]);
    if (profileId != null) {
      query.where((schedule) => schedule.profileId.equals(profileId));
    }

    return query.watch().map((rows) => rows.map(_fromRow).toList());
  }

  /// Saves schedule timing plus its optional prescription link for newer flows.
  @override
  Future<void> upsertSchedule(ReminderSchedule schedule) async {
    _validateSchedule(schedule);
    await _rejectDuplicatePrescriptionTime(schedule);

    final existing = await (_database.select(
      _database.reminderSchedules,
    )..where((row) => row.id.equals(schedule.id))).getSingleOrNull();
    final clearsLoadedSlot =
        existing != null &&
        (!schedule.isEnabled ||
            existing.prescriptionId != schedule.prescriptionId ||
            existing.profileId != schedule.profileId);

    await _database.transaction(() async {
      if (clearsLoadedSlot) {
        await (_database.delete(
          _database.carouselSlots,
        )..where((slot) => slot.scheduleId.equals(schedule.id))).go();
      }
      await _database
          .into(_database.reminderSchedules)
          .insertOnConflictUpdate(
            ReminderSchedulesCompanion.insert(
              id: schedule.id,
              label: schedule.label,
              prescriptionId: Value(schedule.prescriptionId),
              profileId: Value(schedule.profileId),
              hour: schedule.hour,
              minute: schedule.minute,
              isEnabled: schedule.isEnabled,
              createdAt: schedule.createdAt.toUtc(),
              updatedAt: schedule.updatedAt.toUtc(),
            ),
          );
    });
  }

  @override
  Future<void> deleteSchedule(String id) {
    return _database.transaction(() async {
      await (_database.delete(
        _database.carouselSlots,
      )..where((slot) => slot.scheduleId.equals(id))).go();
      await (_database.delete(
        _database.reminderSchedules,
      )..where((schedule) => schedule.id.equals(id))).go();
    });
  }

  static ReminderSchedule _fromRow(ReminderScheduleRow row) {
    return ReminderSchedule(
      id: row.id,
      label: row.label,
      prescriptionId: row.prescriptionId,
      profileId: row.profileId,
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

  /// Prevents accidental duplicate schedule rows for the same medication time.
  Future<void> _rejectDuplicatePrescriptionTime(
    ReminderSchedule schedule,
  ) async {
    final prescriptionId = schedule.prescriptionId;
    if (prescriptionId == null) return;

    final duplicate =
        await (_database.select(_database.reminderSchedules)
              ..where(
                (row) =>
                    row.prescriptionId.equals(prescriptionId) &
                    row.profileId.equals(schedule.profileId) &
                    row.hour.equals(schedule.hour) &
                    row.minute.equals(schedule.minute) &
                    row.id.equals(schedule.id).not(),
              )
              ..limit(1))
            .getSingleOrNull();
    if (duplicate == null) return;

    throw ArgumentError(
      'A schedule already exists for this prescription at ${schedule.timeLabel}.',
    );
  }
}
