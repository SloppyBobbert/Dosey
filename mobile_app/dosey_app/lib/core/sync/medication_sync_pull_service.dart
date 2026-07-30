import 'appwrite_medication_sync_gateway.dart';
import 'domain_contracts.dart';
import 'medication_sync_pull_repository.dart';

class MedicationSyncPullResult {
  const MedicationSyncPullResult({required this.pagesApplied});

  final int pagesApplied;
}

final class MedicationSyncPullService {
  MedicationSyncPullService({
    required this._repository,
    required this._gateway,
    this.pageLimit = 100,
    this.maximumPages = 1000,
  });

  final DriftMedicationSyncPullRepository _repository;
  final MedicationSyncPullGateway _gateway;
  final int pageLimit;
  final int maximumPages;
  Future<MedicationSyncPullResult>? _activePull;

  Future<MedicationSyncPullResult> pull(AuthorizedCachedSyncScope scope) {
    final active = _activePull;
    if (active != null) return active;
    final operation = _pull(scope);
    _activePull = operation;
    return operation.whenComplete(() {
      if (identical(_activePull, operation)) _activePull = null;
    });
  }

  Future<MedicationSyncPullResult> _pull(
    AuthorizedCachedSyncScope scope,
  ) async {
    if (pageLimit < 1 || pageLimit > 100) {
      throw RangeError.range(pageLimit, 1, 100, 'pageLimit');
    }
    if (maximumPages < 1) {
      throw RangeError.range(maximumPages, 1, null, 'maximumPages');
    }

    var state = await _repository.readState(scope);
    if (state?.isTerminal ?? false) {
      return const MedicationSyncPullResult(pagesApplied: 0);
    }
    var pagesApplied = 0;
    while (pagesApplied < maximumPages) {
      final page = await _gateway.pull(
        MedicationSyncPullRequest(
          robotId: scope.robotId,
          cursor: state?.cursor,
          checkpoint: state?.checkpoint,
          limit: pageLimit,
        ),
      );
      await _repository.applyPage(scope: scope, page: page);
      pagesApplied += 1;
      if (!page.hasMore) {
        return MedicationSyncPullResult(pagesApplied: pagesApplied);
      }
      state = MedicationSyncPullState(
        cursor: page.nextCursor,
        checkpoint: page.checkpoint,
      );
    }
    throw StateError('Medication sync pull exceeded the page safety limit.');
  }
}
