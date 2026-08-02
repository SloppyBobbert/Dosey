import 'dart:async';

class DoseyAppLifecycleController {
  _LifecycleAttachment? _scope;
  _LifecycleAttachment? _host;
  bool _isFinalizing = false;
  Future<void>? _finalShutdown;

  void attachScope(Object owner, Future<void> Function() shutdown) {
    _ensureAcceptingAttachments();
    if (_scope != null) {
      throw StateError('A scope is already attached.');
    }
    _scope = _LifecycleAttachment(owner, shutdown);
  }

  void detachScope(Object owner) {
    final scope = _scope;
    if (scope == null || !identical(scope.owner, owner)) return;
    if (scope._shutdownFuture == null) {
      throw StateError('A live scope must be shut down before detaching.');
    }
  }

  void attachHost(
    Object owner,
    Future<void> Function() shutdownOwnedResources,
  ) {
    _ensureAcceptingAttachments();
    if (_host != null) {
      throw StateError('A host is already attached.');
    }
    _host = _LifecycleAttachment(owner, shutdownOwnedResources);
  }

  void detachHost(Object owner) {
    final host = _host;
    if (host == null || !identical(host.owner, owner)) return;
    if (host._shutdownFuture == null) {
      throw StateError('A live host must be shut down before detaching.');
    }
  }

  Future<void> shutdownCurrentScope() {
    final scope = _scope;
    if (scope == null) return Future.value();
    final active = scope._shutdownFuture;
    if (active != null) return active;

    final completion = Completer<void>();
    scope._shutdownFuture = completion.future;
    unawaited(_runScopeShutdown(scope, completion));
    return completion.future;
  }

  Future<void> shutdown() {
    final active = _finalShutdown;
    if (active != null) return active;

    _isFinalizing = true;
    final completion = Completer<void>();
    _finalShutdown = completion.future;
    unawaited(_runFinalShutdown(completion));
    return completion.future;
  }

  Future<void> _runScopeShutdown(
    _LifecycleAttachment scope,
    Completer<void> completion,
  ) async {
    try {
      await scope.shutdown();
      completion.complete();
    } on Object catch (error, stackTrace) {
      completion.completeError(error, stackTrace);
    } finally {
      if (identical(_scope, scope)) {
        _scope = null;
      }
    }
  }

  Future<void> _runFinalShutdown(Completer<void> completion) async {
    Object? firstError;
    StackTrace? firstStackTrace;
    try {
      await shutdownCurrentScope();
    } on Object catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    }

    final host = _host;
    if (host != null) {
      try {
        await _shutdownHost(host);
      } on Object catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    if (firstError == null) {
      completion.complete();
    } else {
      completion.completeError(firstError, firstStackTrace!);
    }
  }

  Future<void> _shutdownHost(_LifecycleAttachment host) {
    final active = host._shutdownFuture;
    if (active != null) return active;

    final completion = Completer<void>();
    host._shutdownFuture = completion.future;
    unawaited(_runHostShutdown(host, completion));
    return completion.future;
  }

  Future<void> _runHostShutdown(
    _LifecycleAttachment host,
    Completer<void> completion,
  ) async {
    try {
      await host.shutdown();
      completion.complete();
    } on Object catch (error, stackTrace) {
      completion.completeError(error, stackTrace);
    } finally {
      if (identical(_host, host)) {
        _host = null;
      }
    }
  }

  void _ensureAcceptingAttachments() {
    if (_isFinalizing) {
      throw StateError('The lifecycle controller is shutting down.');
    }
  }
}

class _LifecycleAttachment {
  _LifecycleAttachment(this.owner, this.shutdown);

  final Object owner;
  final Future<void> Function() shutdown;
  Future<void>? _shutdownFuture;
}
