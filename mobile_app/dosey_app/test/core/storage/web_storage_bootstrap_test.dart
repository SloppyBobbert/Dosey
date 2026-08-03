import 'package:dosey_app/core/storage/web_storage_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyWebStorage', () {
    test('accepts both OPFS implementations for real data', () {
      for (final implementation in [
        WebStorageImplementation.opfsShared,
        WebStorageImplementation.opfsLocks,
      ]) {
        final classification = classifyWebStorage(implementation);

        expect(classification.permitsRealData, isTrue);
        expect(classification.isDurable, isTrue);
      }
    });

    test('accepts synchronized IndexedDB for real data', () {
      final classification = classifyWebStorage(
        WebStorageImplementation.sharedIndexedDb,
      );

      expect(classification.permitsRealData, isTrue);
      expect(classification.isDurable, isTrue);
    });

    test('rejects unsafe IndexedDB as demo-only', () {
      final classification = classifyWebStorage(
        WebStorageImplementation.unsafeIndexedDb,
      );

      expect(classification.permitsRealData, isFalse);
      expect(classification.isDurable, isFalse);
    });

    test('rejects in-memory storage as demo-only', () {
      final classification = classifyWebStorage(
        WebStorageImplementation.inMemory,
      );

      expect(classification.permitsRealData, isFalse);
      expect(classification.isDurable, isFalse);
    });
  });

  group('selectWebStorage', () {
    test('selects OPFS when it is the only approved family', () {
      expect(
        selectWebStorage(
          available: {WebStorageImplementation.opfsLocks},
          existingLocations: const {},
        ),
        const WebStorageOpenDecision(WebStorageImplementation.opfsLocks),
      );
    });

    test(
      'selects synchronized IndexedDB when it is the only approved family',
      () {
        expect(
          selectWebStorage(
            available: {WebStorageImplementation.sharedIndexedDb},
            existingLocations: const {},
          ),
          const WebStorageOpenDecision(
            WebStorageImplementation.sharedIndexedDb,
          ),
        );
      },
    );

    test('rejects unsafe and in-memory-only probes without opening', () {
      for (final available in [
        {WebStorageImplementation.unsafeIndexedDb},
        {WebStorageImplementation.inMemory},
      ]) {
        expect(
          selectWebStorage(available: available, existingLocations: const {}),
          const WebStorageDemoOnlyDecision(),
        );
      }
    });

    test('rejects multiple existing storage locations without opening', () {
      expect(
        selectWebStorage(
          available: {
            WebStorageImplementation.opfsShared,
            WebStorageImplementation.sharedIndexedDb,
          },
          existingLocations: {
            WebStorageLocation.opfs,
            WebStorageLocation.indexedDb,
          },
        ),
        const WebStorageRecoveryDecision(
          WebStorageSelectionFailure.multipleExistingLocations,
        ),
      );
    });

    test('stays with an existing approved IndexedDB location', () {
      expect(
        selectWebStorage(
          available: {
            WebStorageImplementation.opfsShared,
            WebStorageImplementation.sharedIndexedDb,
          },
          existingLocations: {WebStorageLocation.indexedDb},
        ),
        const WebStorageOpenDecision(WebStorageImplementation.sharedIndexedDb),
      );
    });

    test('rejects an existing location without an approved implementation', () {
      expect(
        selectWebStorage(
          available: {WebStorageImplementation.unsafeIndexedDb},
          existingLocations: {WebStorageLocation.indexedDb},
        ),
        const WebStorageRecoveryDecision(
          WebStorageSelectionFailure.existingLocationUnavailable,
        ),
      );
    });

    test('never switches an existing database to another storage family', () {
      final cases = [
        (
          existing: WebStorageLocation.opfs,
          available: {WebStorageImplementation.sharedIndexedDb},
          expected: const WebStorageRecoveryDecision(
            WebStorageSelectionFailure.existingLocationUnavailable,
          ),
        ),
        (
          existing: WebStorageLocation.opfs,
          available: {
            WebStorageImplementation.opfsLocks,
            WebStorageImplementation.sharedIndexedDb,
          },
          expected: const WebStorageOpenDecision(
            WebStorageImplementation.opfsLocks,
          ),
        ),
        (
          existing: WebStorageLocation.indexedDb,
          available: {WebStorageImplementation.opfsShared},
          expected: const WebStorageRecoveryDecision(
            WebStorageSelectionFailure.existingLocationUnavailable,
          ),
        ),
      ];

      for (final testCase in cases) {
        final decision = selectWebStorage(
          available: testCase.available,
          existingLocations: {testCase.existing},
        );

        expect(decision, testCase.expected);
        if (decision case WebStorageRecoveryDecision(:final failure)) {
          expect(
            failure,
            WebStorageSelectionFailure.existingLocationUnavailable,
          );
        }
      }
    });
  });

  test('classification is immutable and supports value equality', () {
    final first = classifyWebStorage(WebStorageImplementation.opfsShared);
    final second = classifyWebStorage(WebStorageImplementation.opfsShared);

    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });

  test('recovery result never exposes a database', () {
    final error = StateError('worker unavailable');
    final missingFeatures = {WebMissingBrowserFeature.workerError};
    final result = WebStorageStartupRecovery(
      error: error,
      stackTrace: StackTrace.empty,
      missingFeatures: missingFeatures,
    );
    missingFeatures.add(WebMissingBrowserFeature.indexedDb);

    expect(result.database, isNull);
    expect(result, isNot(isA<WebStorageDemoOnly>()));
    expect(result.error, same(error));
    expect(result.missingFeatures, {WebMissingBrowserFeature.workerError});
    expect(
      () => result.missingFeatures.add(WebMissingBrowserFeature.indexedDb),
      throwsUnsupportedError,
    );
  });
}
