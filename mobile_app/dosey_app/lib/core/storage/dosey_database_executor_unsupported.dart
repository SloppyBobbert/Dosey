import 'package:drift/drift.dart';

QueryExecutor openDoseyPersistentExecutor({required String name}) {
  throw UnsupportedError(
    'DoseyDatabase requires an explicit qualified executor on this platform.',
  );
}

DatabaseConnection openDoseyInMemoryExecutor() {
  throw UnsupportedError(
    'DoseyDatabase.inMemory is unavailable on this platform.',
  );
}
