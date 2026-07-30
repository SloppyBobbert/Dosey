import 'dart:async';

import '../connectivity/connectivity_gateway.dart';
import 'sync_outbox_repository.dart';
import 'sync_outbox_scope.dart';

final class MedicationSyncOutboxCoordinator {
  MedicationSyncOutboxCoordinator({
    required DriftSyncOutboxRepository repository,
    required MedicationSyncOutboxDrain drain,
    required ConnectivityGateway connectivity,
    required DateTime Function() now,
    Future<SyncOutboxScope?> Function()? scope,
    this.staleAttemptAge = const Duration(minutes: 15),
  }) : _outboxRepository = repository,
       _outboxDrain = drain,
       _connectivityGateway = connectivity,
       _clock = now,
       _scopeProvider = scope;

  final DriftSyncOutboxRepository _outboxRepository;
  final MedicationSyncOutboxDrain _outboxDrain;
  final ConnectivityGateway _connectivityGateway;
  final DateTime Function() _clock;
  final Future<SyncOutboxScope?> Function()? _scopeProvider;
  final Duration staleAttemptAge;

  StreamSubscription<ConnectivityState>? _connectivitySubscription;
  Future<void>? _activeDrain;
  bool _drainRequested = false;
  bool _started = false;
  bool _disposed = false;

  Future<void> start() async {
    if (_disposed) throw StateError('Coordinator is disposed.');
    if (_started) return;
    _started = true;
    final now = _clock().toUtc();
    final scope = await _scopeProvider?.call();
    if (scope != null) {
      await _outboxRepository.recoverStaleInFlight(
        scope: scope,
        staleBefore: now.subtract(staleAttemptAge),
        recoveredAt: now,
      );
    }
    _connectivitySubscription = _connectivityGateway.watchConnectivity().listen(
      _onConnectivity,
    );
    if (await _connectivityGateway.currentConnectivity() !=
        ConnectivityState.offline) {
      await _requestDrain();
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  void _onConnectivity(ConnectivityState state) {
    if (_disposed || state == ConnectivityState.offline) return;
    unawaited(_requestDrain().catchError((Object _) {}));
  }

  Future<void> _requestDrain() {
    final active = _activeDrain;
    if (active != null) {
      _drainRequested = true;
      return active;
    }
    final future = _drainUntilIdle();
    _activeDrain = future;
    return future.whenComplete(() {
      if (identical(_activeDrain, future)) _activeDrain = null;
    });
  }

  Future<void> _drainUntilIdle() async {
    do {
      _drainRequested = false;
      await _outboxDrain.drain();
    } while (_drainRequested && !_disposed);
  }
}
