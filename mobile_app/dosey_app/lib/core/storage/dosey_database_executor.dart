export 'dosey_database_executor_unsupported.dart'
    if (dart.library.ffi) 'dosey_database_executor_native.dart'
    if (dart.library.js_interop) 'dosey_database_executor_unsupported.dart';
