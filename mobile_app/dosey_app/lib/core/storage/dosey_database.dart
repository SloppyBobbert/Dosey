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
  tables: [AppSettings, ReminderSchedules, AuthSessions, DoseLogEvents],
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
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _seedOnboardingCompleted(completed: false);
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
    },
  );

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
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'dosey');
}
