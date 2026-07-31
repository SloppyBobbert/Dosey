import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/audit/local_admin_audit_repository.dart';
import 'package:dosey_app/core/carousel/local_guided_carousel_load_repository.dart';
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';
import 'package:sqlite3/common.dart' show SqlError, SqliteException;

abstract interface class ReminderRepository {
  Stream<List<ReminderSchedule>> watchSchedules({String? profileId});

  Future<void> upsertSchedule(
    ReminderSchedule schedule, {
    AdminAuditEvent? auditEvent,
  });

  Future<int> deleteSchedule(String id, {AdminAuditEvent? auditEvent});
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
  Future<void> upsertSchedule(
    ReminderSchedule schedule, {
    AdminAuditEvent? auditEvent,
  }) async {
    _validateSchedule(schedule);
    await _retryBusy(
      () => _database.transaction(() async {
        await _acquireWriterIntent(schedule.id);
        final prescriptionId = schedule.prescriptionId;
        if (prescriptionId != null) {
          final isDeferredDeleted =
              await LocalPrescriptionRepository.isDeferredDeletedPrescriptionInDatabase(
                _database,
                prescriptionId,
              );
          if (isDeferredDeleted) {
            throw StateError(
              'Prescription "$prescriptionId" is pending guided-load cleanup and cannot be linked to a schedule.',
            );
          }
        }
        await _rejectDuplicatePrescriptionTime(schedule);
        final existing = await (_database.select(
          _database.reminderSchedules,
        )..where((row) => row.id.equals(schedule.id))).getSingleOrNull();
        final revision = _revisionFor(existing, schedule);
        // If the schedule no longer maps to the same enabled dose, clear its slot
        // so the carousel cannot dispense stale loading instructions.
        final clearsLoadedSlot =
            existing != null &&
            (!schedule.isEnabled ||
                existing.prescriptionId != schedule.prescriptionId ||
                existing.profileId != schedule.profileId);
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
                revision: Value(revision),
                isEnabled: schedule.isEnabled,
                createdAt: schedule.createdAt.toUtc(),
                updatedAt: schedule.updatedAt.toUtc(),
              ),
            );
        if (existing != null) {
          final affectedProfiles = <String>{};
          final loadAffectingChange =
              existing.isEnabled != schedule.isEnabled ||
              existing.prescriptionId != schedule.prescriptionId ||
              existing.profileId != schedule.profileId ||
              ((existing.hour != schedule.hour ||
                      existing.minute != schedule.minute) &&
                  (existing.isEnabled || schedule.isEnabled));
          if (loadAffectingChange) {
            affectedProfiles.add(existing.profileId);
            affectedProfiles.add(schedule.profileId);
          }
          for (final profileId in affectedProfiles) {
            await LocalGuidedCarouselLoadRepository.markActiveLoadStaleInDatabase(
              _database,
              profileId: profileId,
              reason: 'schedule_changed',
              occurredAt: schedule.updatedAt,
              details: {'scheduleId': schedule.id},
            );
          }
        }
        if (auditEvent != null) {
          await LocalAdminAuditRepository.insertEventIntoDatabase(
            _database,
            auditEvent,
          );
        }
      }),
    );
  }

  @override
  Future<int> deleteSchedule(String id, {AdminAuditEvent? auditEvent}) {
    return _retryBusy(
      () => _database.transaction(() async {
        await _acquireWriterIntent(id);
        final existing = await (_database.select(
          _database.reminderSchedules,
        )..where((schedule) => schedule.id.equals(id))).getSingleOrNull();
        await (_database.delete(
          _database.carouselSlots,
        )..where((slot) => slot.scheduleId.equals(id))).go();
        final deleted = await (_database.delete(
          _database.reminderSchedules,
        )..where((schedule) => schedule.id.equals(id))).go();
        if (deleted > 0 && existing != null && existing.isEnabled) {
          await LocalGuidedCarouselLoadRepository.markActiveLoadStaleInDatabase(
            _database,
            profileId: existing.profileId,
            reason: 'schedule_deleted',
            occurredAt: DateTime.now().toUtc(),
            details: {'scheduleId': id},
          );
        }
        if (deleted > 0 && auditEvent != null) {
          await LocalAdminAuditRepository.insertEventIntoDatabase(
            _database,
            auditEvent,
          );
        }
        return deleted;
      }),
    );
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

  static int _revisionFor(
    ReminderScheduleRow? existing,
    ReminderSchedule schedule,
  ) {
    if (existing == null) return 1;
    final occurrenceChange =
        existing.hour != schedule.hour ||
        existing.minute != schedule.minute ||
        existing.prescriptionId != schedule.prescriptionId ||
        existing.profileId != schedule.profileId ||
        existing.isEnabled != schedule.isEnabled;
    return occurrenceChange ? existing.revision + 1 : existing.revision;
  }

  Future<void> _acquireWriterIntent(String scheduleId) {
    return _database.customUpdate(
      'UPDATE reminder_schedules SET revision = revision WHERE id = ?',
      variables: [Variable<String>(scheduleId)],
    );
  }

  static Future<T> _retryBusy<T>(Future<T> Function() action) async {
    for (var attempt = 0; attempt < 4; attempt += 1) {
      try {
        return await action();
      } on SqliteException catch (error) {
        if (error.resultCode != SqlError.SQLITE_BUSY || attempt == 3) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 10 * (attempt + 1)));
      }
    }
    throw StateError('Unreachable retry state.');
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
