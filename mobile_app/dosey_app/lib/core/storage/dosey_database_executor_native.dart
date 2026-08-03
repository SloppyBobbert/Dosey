import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

QueryExecutor openDoseyPersistentExecutor({required String name}) {
  return driftDatabase(name: name);
}

DatabaseConnection openDoseyInMemoryExecutor() {
  return DatabaseConnection(
    NativeDatabase.memory(),
    closeStreamsSynchronously: true,
  );
}
