import 'package:dosey_app/core/storage/dosey_database.dart';

enum WebStorageImplementation {
  opfsShared,
  opfsLocks,
  sharedIndexedDb,
  unsafeIndexedDb,
  inMemory,
}

enum WebStorageLocation { opfs, indexedDb }

enum WebStorageSelectionFailure {
  probeIncomplete,
  multipleExistingLocations,
  existingLocationUnavailable,
}

enum WebMissingBrowserFeature {
  sharedWorkers,
  dedicatedWorkers,
  dedicatedWorkersInSharedWorkers,
  fileSystemAccess,
  indexedDb,
  sharedArrayBuffers,
  workerError,
}

enum WebStorageDataSafety { realDataAllowed, demoOnly }

final class WebStorageClassification {
  const WebStorageClassification({
    required this.implementation,
    required this.dataSafety,
    required this.isDurable,
  });

  final WebStorageImplementation implementation;
  final WebStorageDataSafety dataSafety;
  final bool isDurable;

  bool get permitsRealData =>
      dataSafety == WebStorageDataSafety.realDataAllowed;

  @override
  bool operator ==(Object other) {
    return other is WebStorageClassification &&
        other.implementation == implementation &&
        other.dataSafety == dataSafety &&
        other.isDurable == isDurable;
  }

  @override
  int get hashCode => Object.hash(implementation, dataSafety, isDurable);
}

WebStorageClassification classifyWebStorage(
  WebStorageImplementation implementation,
) {
  return switch (implementation) {
    WebStorageImplementation.opfsShared ||
    WebStorageImplementation.opfsLocks ||
    WebStorageImplementation.sharedIndexedDb => WebStorageClassification(
      implementation: implementation,
      dataSafety: WebStorageDataSafety.realDataAllowed,
      isDurable: true,
    ),
    WebStorageImplementation.unsafeIndexedDb ||
    WebStorageImplementation.inMemory => WebStorageClassification(
      implementation: implementation,
      dataSafety: WebStorageDataSafety.demoOnly,
      isDurable: false,
    ),
  };
}

sealed class WebStorageSelectionDecision {
  const WebStorageSelectionDecision();
}

final class WebStorageOpenDecision extends WebStorageSelectionDecision {
  const WebStorageOpenDecision(this.implementation);

  final WebStorageImplementation implementation;

  @override
  bool operator ==(Object other) =>
      other is WebStorageOpenDecision && other.implementation == implementation;

  @override
  int get hashCode => implementation.hashCode;
}

final class WebStorageDemoOnlyDecision extends WebStorageSelectionDecision {
  const WebStorageDemoOnlyDecision();

  @override
  bool operator ==(Object other) => other is WebStorageDemoOnlyDecision;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class WebStorageRecoveryDecision extends WebStorageSelectionDecision {
  const WebStorageRecoveryDecision(this.failure);

  final WebStorageSelectionFailure failure;

  @override
  bool operator ==(Object other) =>
      other is WebStorageRecoveryDecision && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}

final class WebStorageSelectionException implements Exception {
  const WebStorageSelectionException(this.failure);

  final WebStorageSelectionFailure failure;

  @override
  String toString() => 'WebStorageSelectionException($failure)';
}

WebStorageSelectionDecision selectWebStorage({
  required Set<WebStorageImplementation> available,
  required Set<WebStorageLocation> existingLocations,
}) {
  if (existingLocations.length > 1) {
    return const WebStorageRecoveryDecision(
      WebStorageSelectionFailure.multipleExistingLocations,
    );
  }

  final approved = [
    WebStorageImplementation.opfsShared,
    WebStorageImplementation.opfsLocks,
    WebStorageImplementation.sharedIndexedDb,
  ].where(available.contains).toList();

  if (existingLocations.isEmpty) {
    if (approved.isEmpty) return const WebStorageDemoOnlyDecision();
    return WebStorageOpenDecision(approved.first);
  }

  final existing = existingLocations.single;
  final compatible = approved.where((implementation) {
    return switch (existing) {
      WebStorageLocation.opfs =>
        implementation == WebStorageImplementation.opfsShared ||
            implementation == WebStorageImplementation.opfsLocks,
      WebStorageLocation.indexedDb =>
        implementation == WebStorageImplementation.sharedIndexedDb,
    };
  }).toList();
  if (compatible.isEmpty) {
    return const WebStorageRecoveryDecision(
      WebStorageSelectionFailure.existingLocationUnavailable,
    );
  }
  return WebStorageOpenDecision(compatible.first);
}

sealed class WebStorageBootstrapResult {
  WebStorageBootstrapResult({
    required Set<WebMissingBrowserFeature> missingFeatures,
  }) : missingFeatures = Set.unmodifiable(missingFeatures);

  final Set<WebMissingBrowserFeature> missingFeatures;
  DoseyDatabase? get database;
}

final class WebStorageReady extends WebStorageBootstrapResult {
  factory WebStorageReady({
    required DoseyDatabase database,
    required WebStorageClassification classification,
    required Set<WebMissingBrowserFeature> missingFeatures,
  }) {
    final canonicalClassification = classifyWebStorage(
      classification.implementation,
    );
    if (!canonicalClassification.permitsRealData ||
        classification != canonicalClassification) {
      throw ArgumentError.value(
        classification,
        'classification',
        'WebStorageReady requires a canonical real-data classification.',
      );
    }
    return WebStorageReady._(
      database: database,
      classification: classification,
      missingFeatures: missingFeatures,
    );
  }

  WebStorageReady._({
    required this.database,
    required this.classification,
    required super.missingFeatures,
  });

  @override
  final DoseyDatabase database;
  final WebStorageClassification classification;
}

final class WebStorageDemoOnly extends WebStorageBootstrapResult {
  WebStorageDemoOnly({
    required this.classification,
    required super.missingFeatures,
  });

  @override
  DoseyDatabase? get database => null;
  final WebStorageClassification classification;
}

final class WebStorageStartupRecovery extends WebStorageBootstrapResult {
  WebStorageStartupRecovery({
    required this.error,
    required this.stackTrace,
    this.selectionFailure,
    required super.missingFeatures,
  });

  @override
  DoseyDatabase? get database => null;
  final Object error;
  final StackTrace stackTrace;
  final WebStorageSelectionFailure? selectionFailure;
}
