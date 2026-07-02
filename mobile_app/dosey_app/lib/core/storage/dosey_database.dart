import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'dosey_database.g.dart';

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('ReminderScheduleRow')
class ReminderSchedules extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  TextColumn get prescriptionId => text().nullable()();
  TextColumn get profileId =>
      text().withDefault(const Constant('schedule-1'))();
  IntColumn get hour => integer()();
  IntColumn get minute => integer()();
  BoolColumn get isEnabled => boolean()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<String> get customConstraints => const [
    'CHECK (hour >= 0 AND hour <= 23)',
    'CHECK (minute >= 0 AND minute <= 59)',
  ];

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ScheduleProfileRow')
class ScheduleProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get isActive => boolean()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PrescriptionRow')
class Prescriptions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get pillType => text()();
  IntColumn get remainingDoses => integer().withDefault(const Constant(0))();
  IntColumn get refillThreshold => integer().withDefault(const Constant(3))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<String> get customConstraints => const [
    'CHECK (remaining_doses >= 0)',
    'CHECK (refill_threshold >= 0)',
  ];

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PrescriptionRefillRow')
class PrescriptionRefills extends Table {
  TextColumn get id => text()();
  TextColumn get prescriptionId => text()();
  IntColumn get doseDelta => integer()();
  IntColumn get remainingAfter => integer()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get note => text().nullable()();

  @override
  List<String> get customConstraints => const [
    'CHECK (dose_delta > 0)',
    'CHECK (remaining_after >= 0)',
  ];

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CarouselSlotRow')
class CarouselSlots extends Table {
  TextColumn get id => text()();
  IntColumn get slotNumber => integer()();
  TextColumn get prescriptionId => text()();
  TextColumn get scheduleId => text()();
  TextColumn get profileId => text()();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<String> get customConstraints => const [
    'CHECK (slot_number > 0)',
    "CHECK (status IN ('assigned', 'loaded', 'dispensed', 'needs_review'))",
    'UNIQUE (profile_id, slot_number)',
    'UNIQUE (profile_id, schedule_id)',
  ];

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AuthSessionRow')
class AuthSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get email => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get photoUrl => text().nullable()();
  TextColumn get provider => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DoseLogEventRow')
class DoseLogEvents extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get doseId => text()();
  DateTimeColumn get occurredAt => dateTime()();
  BoolColumn get marksDoseTaken => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    AppSettings,
    ReminderSchedules,
    Prescriptions,
    PrescriptionRefills,
    ScheduleProfiles,
    CarouselSlots,
    AuthSessions,
    DoseLogEvents,
  ],
)
class DoseyDatabase extends _$DoseyDatabase {
  DoseyDatabase([QueryExecutor? executor])
    : super(executor ?? _openConnection());

  factory DoseyDatabase.inMemory() {
    return DoseyDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  }

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _seedOnboardingCompleted(completed: false);
      await _seedDefaultScheduleProfile();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(reminderSchedules);
      }
      if (from < 3) {
        await migrator.createTable(authSessions);
      }
      if (from >= 2 && from < 4) {
        await migrator.alterTable(TableMigration(reminderSchedules));
      }
      if (from < 5) {
        await _seedOnboardingCompleted(completed: true);
      }
      if (from < 6) {
        await migrator.createTable(prescriptions);
        if (from >= 2) {
          await migrator.addColumn(
            reminderSchedules,
            reminderSchedules.prescriptionId,
          );
        }
      }
      if (from < 7) {
        await migrator.createTable(scheduleProfiles);
        if (from >= 2) {
          await migrator.addColumn(
            reminderSchedules,
            reminderSchedules.profileId,
          );
        }
        await _seedDefaultScheduleProfile();
      }
      if (from < 8) {
        await migrator.createTable(carouselSlots);
      }
      if (from < 9) {
        await _createDoseLogEventsIfMissing();
      }
      if (from >= 8 && from < 9) {
        await _normalizeLegacyCarouselSlotStatuses();
        await migrator.alterTable(TableMigration(carouselSlots));
      }
      if (from < 10) {
        if (from >= 6) {
          await migrator.addColumn(prescriptions, prescriptions.remainingDoses);
          await migrator.addColumn(
            prescriptions,
            prescriptions.refillThreshold,
          );
        }
        await migrator.createTable(prescriptionRefills);
      }
    },
  );

  Future<void> _createDoseLogEventsIfMissing() {
    return customStatement('''
      CREATE TABLE IF NOT EXISTS dose_log_events (
        id TEXT NOT NULL PRIMARY KEY,
        kind TEXT NOT NULL,
        dose_id TEXT NOT NULL,
        occurred_at INTEGER NOT NULL,
        marks_dose_taken INTEGER NOT NULL CHECK (marks_dose_taken IN (0, 1))
      );
    ''');
  }

  Future<void> _normalizeLegacyCarouselSlotStatuses() {
    return customStatement('''
      UPDATE carousel_slots
      SET status = 'needs_review'
      WHERE status NOT IN ('assigned', 'loaded', 'dispensed', 'needs_review');
    ''');
  }

  Future<void> _seedOnboardingCompleted({required bool completed}) async {
    await into(appSettings).insert(
      AppSettingsCompanion.insert(
        key: 'onboarding_completed',
        value: completed.toString(),
        updatedAt: DateTime.now().toUtc(),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> _seedDefaultScheduleProfile() async {
    final now = DateTime.now().toUtc();
    await into(scheduleProfiles).insert(
      ScheduleProfilesCompanion.insert(
        id: 'schedule-1',
        name: 'Schedule 1',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'dosey');
}
