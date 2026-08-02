import 'dart:async';

enum StartupMaintenanceStage {
  identity,
  timezone,
  notifications,
  reconciliation,
}

class StartupMaintenanceFailure {
  const StartupMaintenanceFailure({
    required this.stage,
    required this.error,
    required this.stackTrace,
  });

  final StartupMaintenanceStage stage;
  final Object error;
  final StackTrace stackTrace;
}

typedef StartupMaintenanceFailureReporter =
    void Function(StartupMaintenanceFailure failure);

class StartupResumeMaintenanceCoordinator {
  factory StartupResumeMaintenanceCoordinator({
    required Future<void> Function() initializeIdentity,
    required Future<void> Function() refreshTimezone,
    required Future<void> Function() syncNotifications,
    required Future<void> Function() reconcile,
    StartupMaintenanceFailureReporter? reportFailure,
  }) => StartupResumeMaintenanceCoordinator._(
    initializeIdentity,
    refreshTimezone,
    syncNotifications,
    reconcile,
    reportFailure,
  );

  StartupResumeMaintenanceCoordinator._(
    this._initializeIdentity,
    this._refreshTimezone,
    this._syncNotifications,
    this._reconcile,
    this._reportFailure,
  );

  final Future<void> Function() _initializeIdentity;
  final Future<void> Function() _refreshTimezone;
  final Future<void> Function() _syncNotifications;
  final Future<void> Function() _reconcile;
  final StartupMaintenanceFailureReporter? _reportFailure;
  Future<void>? _active;
  Completer<void>? _queued;
  bool _disposed = false;
  Future<void>? _disposeFuture;

  Future<void> request() {
    if (_disposed) return Future.value();
    final active = _active;
    if (active == null) return _startRun();
    return (_queued ??= Completer<void>()).future;
  }

  Future<void> _startRun() {
    final run = _run();
    _active = run;
    run.whenComplete(_finishRun);
    return run;
  }

  void _finishRun() {
    _active = null;
    final queued = _queued;
    _queued = null;
    if (queued == null) return;
    if (_disposed) {
      queued.complete();
      return;
    }
    final run = _run();
    _active = run;
    run.whenComplete(() {
      queued.complete();
      _finishRun();
    });
  }

  Future<void> _run() async {
    if (!await _runStage(
      StartupMaintenanceStage.identity,
      _initializeIdentity,
    )) {
      return;
    }
    if (!await _runStage(StartupMaintenanceStage.timezone, _refreshTimezone)) {
      return;
    }
    await _runStage(StartupMaintenanceStage.notifications, _syncNotifications);
    await _runStage(StartupMaintenanceStage.reconciliation, _reconcile);
  }

  Future<bool> _runStage(
    StartupMaintenanceStage stage,
    Future<void> Function() callback,
  ) async {
    try {
      await callback();
      return true;
    } on Object catch (error, stackTrace) {
      try {
        _reportFailure?.call(
          StartupMaintenanceFailure(
            stage: stage,
            error: error,
            stackTrace: stackTrace,
          ),
        );
      } on Object {
        // Diagnostics cannot affect maintenance execution.
      }
      return false;
    }
  }

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    _queued?.complete();
    _queued = null;
    await _active;
  }
}
