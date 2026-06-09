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

@DriftDatabase(tables: [AppSettings, DoseLogEvents])
class DoseyDatabase extends _$DoseyDatabase {
  DoseyDatabase([QueryExecutor? executor])
    : super(executor ?? _openConnection());

  factory DoseyDatabase.inMemory() {
    return DoseyDatabase(NativeDatabase.memory());
  }

  @override
  int get schemaVersion => 1;
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'dosey');
}
