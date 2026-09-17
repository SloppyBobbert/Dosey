import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/storage/web_storage_types.dart';
import 'package:drift/drift.dart' show DatabaseConnection;

/// The same open/initial-query/cleanup path is used by WASM and injection tests.
Future<WebStorageBootstrapResult> openWebStorage({
  required Future<DatabaseConnection> Function() open,
  required WebStorageImplementation implementation,
  required Set<WebMissingBrowserFeature> missingFeatures,
}) async {
  DatabaseConnection? executor;
  DoseyDatabase? database;
  try {
    final classification = classifyWebStorage(implementation);
    if (!classification.permitsRealData) {
      throw ArgumentError.value(implementation, 'implementation');
    }
    executor = await open();
    database = DoseyDatabase(executor);
    await database.customSelect('SELECT 1').get();
    return WebStorageReady(
      database: database,
      classification: classification,
      missingFeatures: missingFeatures,
    );
  } catch (error, stackTrace) {
    var cleanup = WebStorageCleanup.notNeeded;
    Object? cleanupError;
    StackTrace? cleanupStackTrace;
    try {
      if (database != null) {
        await database.close();
        cleanup = WebStorageCleanup.completed;
      } else if (executor != null) {
        await executor.close();
        cleanup = WebStorageCleanup.completed;
      }
    } catch (error, stackTrace) {
      // An uncertain close must not be turned into permission to open again.
      cleanup = WebStorageCleanup.uncertain;
      cleanupError = error;
      cleanupStackTrace = stackTrace;
    }
    return WebStorageStartupRecovery(
      error: error,
      stackTrace: stackTrace,
      cleanup: cleanup,
      cleanupError: cleanupError,
      cleanupStackTrace: cleanupStackTrace,
      missingFeatures: missingFeatures,
    );
  }
}
