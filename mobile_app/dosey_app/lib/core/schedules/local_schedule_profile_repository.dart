import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';

abstract interface class ScheduleProfileRepository {
  Stream<List<ScheduleProfile>> watchProfiles();

  Stream<ScheduleProfile> watchActiveProfile();

  Future<void> upsertProfile(ScheduleProfile profile);

  Future<void> setActiveProfile(String id);
}

class LocalScheduleProfileRepository implements ScheduleProfileRepository {
  const LocalScheduleProfileRepository(this._database);

  final DoseyDatabase _database;

  /// Watches saved schedule profiles so the app can switch routines without
  /// deleting older robot schedules.
  @override
  Stream<List<ScheduleProfile>> watchProfiles() {
    final query = _database.select(_database.scheduleProfiles)
      ..orderBy([(profile) => OrderingTerm.asc(profile.createdAt)]);
    return query.watch().map((rows) => rows.map(_fromRow).toList());
  }

  /// Emits the single active schedule profile used by Today and robot dosing.
  @override
  Stream<ScheduleProfile> watchActiveProfile() {
    final query = _database.select(_database.scheduleProfiles)
      ..where((profile) => profile.isActive.equals(true))
      ..limit(1);
    return query.watchSingle().map(_fromRow);
  }

  @override
  Future<void> upsertProfile(ScheduleProfile profile) {
    _validateProfile(profile);
    return _database
        .into(_database.scheduleProfiles)
        .insertOnConflictUpdate(
          ScheduleProfilesCompanion.insert(
            id: profile.id,
            name: profile.name.trim(),
            isActive: profile.isActive,
            createdAt: profile.createdAt.toUtc(),
            updatedAt: profile.updatedAt.toUtc(),
          ),
        );
  }

  /// Activates one profile at a time so only one robot routine can drive Today.
  @override
  Future<void> setActiveProfile(String id) async {
    final existing =
        await (_database.select(_database.scheduleProfiles)
              ..where((profile) => profile.id.equals(id))
              ..limit(1))
            .getSingleOrNull();
    if (existing == null) {
      throw ArgumentError('Schedule profile not found.');
    }

    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      await _database
          .update(_database.scheduleProfiles)
          .write(
            ScheduleProfilesCompanion(
              isActive: const Value(false),
              updatedAt: Value(now),
            ),
          );
      await (_database.update(
        _database.scheduleProfiles,
      )..where((profile) => profile.id.equals(id))).write(
        ScheduleProfilesCompanion(
          isActive: const Value(true),
          updatedAt: Value(now),
        ),
      );
    });
  }

  static ScheduleProfile _fromRow(ScheduleProfileRow row) {
    return ScheduleProfile(
      id: row.id,
      name: row.name,
      isActive: row.isActive,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }

  static void _validateProfile(ScheduleProfile profile) {
    if (profile.name.trim().isEmpty) {
      throw ArgumentError.value(profile.name, 'name', 'Must not be blank.');
    }
  }
}
