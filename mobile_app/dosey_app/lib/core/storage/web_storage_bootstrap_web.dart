import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/storage/web_storage_types.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/wasm.dart';

export 'web_storage_types.dart';

Future<WebStorageBootstrapResult> bootstrapWebDoseyDatabase() async {
  return bootstrapWebDoseyDatabaseWithProbe(
    () => WasmDatabase.probe(
      databaseName: 'dosey',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    ),
  );
}

Future<WebStorageBootstrapResult> bootstrapWebDoseyDatabaseWithProbe(
  Future<WasmProbeResult> Function() loadProbe,
) async {
  try {
    final probe = await loadProbe();
    final missingFeatures = _mapMissingFeatures(probe.missingFeatures);
    if (missingFeatures.contains(WebMissingBrowserFeature.workerError)) {
      const failure = WebStorageSelectionFailure.probeIncomplete;
      return WebStorageStartupRecovery(
        error: const WebStorageSelectionException(failure),
        stackTrace: StackTrace.current,
        selectionFailure: failure,
        missingFeatures: missingFeatures,
      );
    }
    final decision = selectWebStorage(
      available: probe.availableStorages.map(_mapImplementation).toSet(),
      existingLocations: {
        for (final (location, name) in probe.existingDatabases)
          if (name == 'dosey') _mapLocation(location),
      },
    );
    switch (decision) {
      case WebStorageDemoOnlyDecision():
        return WebStorageDemoOnly(
          classification: _demoOnlyClassification(probe.availableStorages),
          missingFeatures: missingFeatures,
        );
      case WebStorageRecoveryDecision(:final failure):
        return WebStorageStartupRecovery(
          error: WebStorageSelectionException(failure),
          stackTrace: StackTrace.current,
          selectionFailure: failure,
          missingFeatures: missingFeatures,
        );
      case WebStorageOpenDecision(:final implementation):
        return _openSelectedStorage(probe, implementation, missingFeatures);
    }
  } catch (error, stackTrace) {
    return WebStorageStartupRecovery(
      error: error,
      stackTrace: stackTrace,
      missingFeatures: const {},
    );
  }
}

Future<WebStorageBootstrapResult> _openSelectedStorage(
  WasmProbeResult probe,
  WebStorageImplementation implementation,
  Set<WebMissingBrowserFeature> missingFeatures,
) async {
  DatabaseConnection? executor;
  DoseyDatabase? database;
  try {
    executor = await probe.open(_toWasmImplementation(implementation), 'dosey');
    database = DoseyDatabase(executor);
    await database.customSelect('SELECT 1').get();
    return WebStorageReady(
      database: database,
      classification: classifyWebStorage(implementation),
      missingFeatures: missingFeatures,
    );
  } catch (error, stackTrace) {
    try {
      if (database != null) {
        await database.close();
      } else if (executor != null) {
        await executor.close();
      }
    } catch (_) {
      // Preserve the startup error that rejected this executor.
    }
    return WebStorageStartupRecovery(
      error: error,
      stackTrace: stackTrace,
      missingFeatures: missingFeatures,
    );
  }
}

WebStorageClassification _demoOnlyClassification(
  List<WasmStorageImplementation> available,
) {
  final implementation =
      available.contains(WasmStorageImplementation.unsafeIndexedDb)
      ? WebStorageImplementation.unsafeIndexedDb
      : WebStorageImplementation.inMemory;
  return classifyWebStorage(implementation);
}

WebStorageImplementation _mapImplementation(
  WasmStorageImplementation implementation,
) {
  return switch (implementation) {
    WasmStorageImplementation.opfsShared => WebStorageImplementation.opfsShared,
    WasmStorageImplementation.opfsLocks => WebStorageImplementation.opfsLocks,
    WasmStorageImplementation.sharedIndexedDb =>
      WebStorageImplementation.sharedIndexedDb,
    WasmStorageImplementation.unsafeIndexedDb =>
      WebStorageImplementation.unsafeIndexedDb,
    WasmStorageImplementation.inMemory => WebStorageImplementation.inMemory,
  };
}

WasmStorageImplementation _toWasmImplementation(
  WebStorageImplementation implementation,
) {
  return switch (implementation) {
    WebStorageImplementation.opfsShared => WasmStorageImplementation.opfsShared,
    WebStorageImplementation.opfsLocks => WasmStorageImplementation.opfsLocks,
    WebStorageImplementation.sharedIndexedDb =>
      WasmStorageImplementation.sharedIndexedDb,
    WebStorageImplementation.unsafeIndexedDb ||
    WebStorageImplementation.inMemory => throw ArgumentError.value(
      implementation,
      'implementation',
    ),
  };
}

WebStorageLocation _mapLocation(WebStorageApi location) {
  return switch (location) {
    WebStorageApi.opfs => WebStorageLocation.opfs,
    WebStorageApi.indexedDb => WebStorageLocation.indexedDb,
  };
}

Set<WebMissingBrowserFeature> _mapMissingFeatures(
  Set<MissingBrowserFeature> missingFeatures,
) {
  return {
    for (final feature in missingFeatures)
      switch (feature) {
        MissingBrowserFeature.sharedWorkers =>
          WebMissingBrowserFeature.sharedWorkers,
        MissingBrowserFeature.dedicatedWorkers =>
          WebMissingBrowserFeature.dedicatedWorkers,
        MissingBrowserFeature.dedicatedWorkersInSharedWorkers =>
          WebMissingBrowserFeature.dedicatedWorkersInSharedWorkers,
        MissingBrowserFeature.fileSystemAccess =>
          WebMissingBrowserFeature.fileSystemAccess,
        MissingBrowserFeature.indexedDb => WebMissingBrowserFeature.indexedDb,
        MissingBrowserFeature.sharedArrayBuffers =>
          WebMissingBrowserFeature.sharedArrayBuffers,
        MissingBrowserFeature.workerError =>
          WebMissingBrowserFeature.workerError,
      },
  };
}
