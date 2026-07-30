import 'package:flutter/foundation.dart';

import 'caregiver_snapshot.dart';
import 'caregiver_status_projection.dart';

class CaregiverSyncException implements Exception {
  const CaregiverSyncException(this.message);
  final String message;
}

class CaregiverConflictException extends CaregiverSyncException {
  const CaregiverConflictException()
    : super('Changes conflict with newer data.');
}

class CaregiverPullResult {
  const CaregiverPullResult({
    required this.snapshot,
    required this.cursor,
    required this.checkpoint,
  });

  final CaregiverSnapshot snapshot;
  final String? cursor;
  final String? checkpoint;
}

abstract interface class CaregiverSyncGateway {
  Future<CaregiverPullResult> pull(
    String robotId, {
    String? cursor,
    String? checkpoint,
    int limit = 100,
  });

  Future<void> push(String robotId, List<CaregiverMutation> operations);
}

class DisabledCaregiverSyncGateway implements CaregiverSyncGateway {
  const DisabledCaregiverSyncGateway();

  @override
  Future<CaregiverPullResult> pull(
    String robotId, {
    String? cursor,
    String? checkpoint,
    int limit = 100,
  }) => Future.error(
    const CaregiverSyncException('Medication sync is not configured.'),
  );

  @override
  Future<void> push(String robotId, List<CaregiverMutation> operations) =>
      Future.error(
        const CaregiverSyncException('Medication sync is not configured.'),
      );
}

sealed class CaregiverSnapshotState {
  const CaregiverSnapshotState();
}

class CaregiverLoading extends CaregiverSnapshotState {
  const CaregiverLoading();
}

class CaregiverFresh extends CaregiverSnapshotState {
  const CaregiverFresh(this.snapshot, this.lastUpdatedAt);
  final CaregiverSnapshot snapshot;
  final DateTime lastUpdatedAt;
}

class CaregiverRefreshing extends CaregiverSnapshotState {
  const CaregiverRefreshing(this.snapshot, this.lastUpdatedAt);
  final CaregiverSnapshot snapshot;
  final DateTime lastUpdatedAt;
}

class CaregiverStale extends CaregiverSnapshotState {
  const CaregiverStale({
    required this.snapshot,
    required this.lastUpdatedAt,
    required this.message,
    this.isConflict = false,
  });
  final CaregiverSnapshot snapshot;
  final DateTime lastUpdatedAt;
  final String message;
  final bool isConflict;
}

class CaregiverUnavailable extends CaregiverSnapshotState {
  const CaregiverUnavailable(this.message);
  final String message;
}

class CaregiverSnapshotController extends ChangeNotifier {
  CaregiverSnapshotController({
    required this.householdId,
    required this.gateway,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final String householdId;
  final CaregiverSyncGateway gateway;
  final DateTime Function() _now;
  CaregiverSnapshotState state = const CaregiverLoading();
  int _request = 0;
  bool _isTerminalMutationPending = false;

  bool get isTerminalMutationPending => _isTerminalMutationPending;

  Future<void> load() => _pull(showRefresh: false);
  Future<void> refresh() => _pull(showRefresh: true);

  Future<void> _pull({required bool showRefresh}) async {
    final request = ++_request;
    final previous = _current;
    if (showRefresh && previous != null) {
      state = CaregiverRefreshing(previous.$1, previous.$2);
      notifyListeners();
    }
    try {
      final result = await gateway.pull(householdId);
      if (request != _request) return;
      state = CaregiverFresh(result.snapshot, _now());
    } catch (error) {
      if (request != _request) return;
      final message = _message(error);
      state = previous == null
          ? CaregiverUnavailable(message)
          : CaregiverStale(
              snapshot: previous.$1,
              lastUpdatedAt: previous.$2,
              message: message,
            );
    }
    notifyListeners();
  }

  Future<void> push(CaregiverMutation mutation) async {
    if (_isTerminalDoseMutation(mutation)) {
      return;
    }
    await _push(mutation);
  }

  Future<void> recordTerminalDose({
    required CaregiverOccurrence occurrence,
    required CaregiverDoseAction action,
  }) async {
    if (action != CaregiverDoseAction.taken &&
        action != CaregiverDoseAction.skipped) {
      return;
    }
    if (_isTerminalMutationPending || state is! CaregiverFresh) return;

    _isTerminalMutationPending = true;
    notifyListeners();
    try {
      await refresh();
      final current = _current;
      if (state is! CaregiverFresh || current == null) return;
      final projection = projectCaregiverDay(snapshot: current.$1, now: _now())
          .where((dose) => _sameOccurrence(dose.occurrence, occurrence))
          .firstOrNull;
      if (projection == null || projection.hasTerminalOutcome) {
        state = CaregiverStale(
          snapshot: current.$1,
          lastUpdatedAt: current.$2,
          message: 'Dose changed. Refresh before trying again.',
          isConflict: true,
        );
        notifyListeners();
        return;
      }
      await _push(
        CaregiverMutation.recordDose(occurrence: occurrence, action: action),
      );
    } finally {
      _isTerminalMutationPending = false;
      notifyListeners();
    }
  }

  Future<void> _push(CaregiverMutation mutation) async {
    final previous = _current;
    if (previous == null) return;
    try {
      await gateway.push(householdId, [mutation]);
      await refresh();
    } catch (error) {
      state = CaregiverStale(
        snapshot: previous.$1,
        lastUpdatedAt: previous.$2,
        message: _message(error),
        isConflict: error is CaregiverConflictException,
      );
      notifyListeners();
    }
  }

  bool _sameOccurrence(CaregiverOccurrence left, CaregiverOccurrence right) =>
      left.occurrenceId == right.occurrenceId &&
      left.scheduleId == right.scheduleId &&
      left.scheduleRevision == right.scheduleRevision &&
      left.scheduledFor.toUtc().isAtSameMomentAs(right.scheduledFor.toUtc()) &&
      left.timezoneId == right.timezoneId &&
      left.localDate == right.localDate;

  bool _isTerminalDoseMutation(CaregiverMutation mutation) =>
      mutation.kind == CaregiverMutationKind.recordDose &&
      (mutation.values['action'] == CaregiverDoseAction.taken.name ||
          mutation.values['action'] == CaregiverDoseAction.skipped.name);

  (CaregiverSnapshot, DateTime)? get _current => switch (state) {
    CaregiverFresh(:final snapshot, :final lastUpdatedAt) => (
      snapshot,
      lastUpdatedAt,
    ),
    CaregiverRefreshing(:final snapshot, :final lastUpdatedAt) => (
      snapshot,
      lastUpdatedAt,
    ),
    CaregiverStale(:final snapshot, :final lastUpdatedAt) => (
      snapshot,
      lastUpdatedAt,
    ),
    _ => null,
  };

  String _message(Object error) => switch (error) {
    CaregiverSyncException(:final message) => message,
    _ => 'Caregiver data is unavailable.',
  };
}
