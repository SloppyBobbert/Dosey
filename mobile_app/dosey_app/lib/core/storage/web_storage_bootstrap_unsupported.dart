import 'package:dosey_app/core/storage/web_storage_types.dart';
export 'web_storage_types.dart';

Future<WebStorageBootstrapResult> bootstrapWebDoseyDatabase({
  String databaseName = 'dosey',
}) async {
  return WebStorageStartupRecovery(
    error: UnsupportedError('Web storage bootstrap is only available on web.'),
    stackTrace: StackTrace.current,
    missingFeatures: const {},
  );
}
