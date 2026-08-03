@TestOn('browser')
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:dosey_app/core/storage/web_storage_bootstrap_web.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/wasm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a worker-error probe returns recovery before selection or open',
    () async {
      final probe = _Probe(
        availableStorages: [WasmStorageImplementation.opfsShared],
        missingFeatures: {MissingBrowserFeature.workerError},
      );

      final result = await bootstrapWebDoseyDatabaseWithProbe(
        () async => probe,
      );

      expect(result, isA<WebStorageStartupRecovery>());
      final recovery = result as WebStorageStartupRecovery;
      expect(
        recovery.selectionFailure,
        WebStorageSelectionFailure.probeIncomplete,
      );
      expect(recovery.missingFeatures, {WebMissingBrowserFeature.workerError});
      expect(probe.openCalls, 0);
    },
  );

  test('unsafe implementations never reach probe.open', () async {
    for (final implementation in [
      WasmStorageImplementation.unsafeIndexedDb,
      WasmStorageImplementation.inMemory,
    ]) {
      final probe = _Probe(availableStorages: [implementation]);

      final result = await bootstrapWebDoseyDatabaseWithProbe(
        () async => probe,
      );

      expect(result, isA<WebStorageDemoOnly>());
      expect(probe.openCalls, 0);
    }
  });

  test('multiple mapped database locations fail before probe.open', () async {
    final probe = _Probe(
      availableStorages: [
        WasmStorageImplementation.opfsShared,
        WasmStorageImplementation.sharedIndexedDb,
      ],
      existingDatabases: [
        (WebStorageApi.opfs, 'dosey'),
        (WebStorageApi.indexedDb, 'dosey'),
        (WebStorageApi.opfs, 'other'),
      ],
    );

    final result = await bootstrapWebDoseyDatabaseWithProbe(() async => probe);

    expect(result, isA<WebStorageStartupRecovery>());
    expect(
      (result as WebStorageStartupRecovery).selectionFailure,
      WebStorageSelectionFailure.multipleExistingLocations,
    );
    expect(probe.openCalls, 0);
  });
}

final class _Probe implements WasmProbeResult {
  _Probe({
    required this.availableStorages,
    this.existingDatabases = const [],
    this.missingFeatures = const {},
  });

  @override
  final List<WasmStorageImplementation> availableStorages;
  @override
  final List<ExistingDatabase> existingDatabases;
  @override
  final Set<MissingBrowserFeature> missingFeatures;
  int openCalls = 0;

  @override
  Future<DatabaseConnection> open(
    WasmStorageImplementation implementation,
    String name, {
    FutureOr<Uint8List?> Function()? initializeDatabase,
    WasmDatabaseSetup? localSetup,
    bool enableMigrations = true,
  }) async {
    openCalls += 1;
    throw StateError('probe.open must not be called');
  }

  @override
  Future<void> deleteDatabase(ExistingDatabase database) async {}

  @override
  Future<Uint8List?> exportDatabase(ExistingDatabase database) async => null;

  @override
  Future<void> moveFromIndexedDBToOpfs(String databaseName) async {}
}
