import 'dart:async';
import 'package:dosey_app/features/shared/personal_setup_scope.dart';

import 'package:dosey_app/app/web_local_personal/web_local_personal_app.dart';
import 'package:dosey_app/app/web_local_personal/web_local_personal_pages.dart';
import 'package:dosey_app/core/runtime/runtime_capability.dart';
import 'package:dosey_app/core/storage/web_storage_types.dart';
import 'package:flutter/material.dart';

/// Owns one local database. No account, hardware or native app scope is created.
class WebLocalPersonalStartup extends ChangeNotifier {
  WebLocalPersonalStartup({required this.bootstrap, this.onShutdownFailure});

  static const databaseName = 'dosey-personal-local';
  static const capability = RuntimeCapability.phoneOnly;
  final Future<WebStorageBootstrapResult> Function() bootstrap;
  final void Function(WebStorageStartupRecovery)? onShutdownFailure;
  WebStorageBootstrapResult? result;
  PersonalSetupDependencies? setup;
  bool loading = false;
  bool _stopped = false;
  bool _disposed = false;
  Future<void>? _opening;
  Future<void>? _shutdown;

  bool get canStart =>
      !loading &&
      !_stopped &&
      result is! WebStorageReady &&
      !(result is WebStorageStartupRecovery &&
          (result as WebStorageStartupRecovery).cleanup ==
              WebStorageCleanup.uncertain);

  Future<void> start() {
    if (!canStart) return Future.value();
    loading = true;
    final opening = _opening = _open();
    notifyListeners();
    return opening;
  }

  Future<void> _open() async {
    WebStorageBootstrapResult opened;
    try {
      opened = await bootstrap();
    } catch (error, stackTrace) {
      opened = WebStorageStartupRecovery(
        error: error,
        stackTrace: stackTrace,
        missingFeatures: const {},
      );
    }
    result = opened;
    if (opened is WebStorageReady) {
      setup = PersonalSetupDependencies.local(opened.database);
      try {
        await setup!.initializeLocalProfile();
      } catch (error, stackTrace) {
        await setup!.drain();
        setup = null;
        await _close();
        final cleanupFailure = result;
        result = WebStorageStartupRecovery(
          error: error,
          stackTrace: stackTrace,
          cleanup: cleanupFailure is WebStorageStartupRecovery
              ? WebStorageCleanup.uncertain
              : WebStorageCleanup.completed,
          cleanupError: cleanupFailure is WebStorageStartupRecovery
              ? cleanupFailure.cleanupError
              : null,
          cleanupStackTrace: cleanupFailure is WebStorageStartupRecovery
              ? cleanupFailure.cleanupStackTrace
              : null,
          missingFeatures: opened.missingFeatures,
        );
      }
    }
    if (_stopped) await _close();
    loading = false;
    if (!_disposed) notifyListeners();
  }

  /// Await this before replacing the root. Browser termination cannot await it.
  /// Drain initialization and guarded setup mutations before closing storage.
  Future<void> shutdown() {
    _stopped = true;
    return _shutdown ??= _drainAndClose();
  }

  Future<void> _drainAndClose() async {
    await _opening;
    await setup?.drain();
    await _close();
  }

  Future<void> _close() async {
    final opened = result;
    if (opened is! WebStorageReady) return;
    result = null; // Release ownership before awaiting; never close twice.
    try {
      await opened.database.close();
    } catch (error, stackTrace) {
      final recovery = WebStorageStartupRecovery(
        error: error,
        stackTrace: stackTrace,
        cleanup: WebStorageCleanup.uncertain,
        cleanupError: error,
        cleanupStackTrace: stackTrace,
        missingFeatures: opened.missingFeatures,
      );
      result = recovery;
      onShutdownFailure?.call(recovery);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(shutdown());
    super.dispose();
  }
}

class WebLocalPersonalStartupApp extends StatefulWidget {
  const WebLocalPersonalStartupApp({
    super.key,
    required this.startup,
    this.routeInformationProvider,
  });
  final RouteInformationProvider? routeInformationProvider;

  /// Fixed for this widget's lifetime; ownership transfers to this widget.
  final WebLocalPersonalStartup startup;

  @override
  State<WebLocalPersonalStartupApp> createState() => _StartupAppState();
}

class _StartupAppState extends State<WebLocalPersonalStartupApp> {
  late final WebLocalPersonalStartup _startup = widget.startup;

  @override
  void dispose() {
    _startup.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _startup,
    builder: (context, _) {
      final result = _startup.result;
      final uncertain =
          result is WebStorageStartupRecovery &&
          result.cleanup == WebStorageCleanup.uncertain;
      final title = _startup.loading
          ? 'Opening local storage…'
          : result is WebStorageDemoOnly
          ? 'Supported local storage is unavailable'
          : result is WebStorageStartupRecovery
          ? 'Local storage needs attention'
          : 'Use Personal on this browser';
      final app = WebLocalPersonalApp(
        storage: result,
        routeInformationProvider: widget.routeInformationProvider,
        startupPage: !_startup.loading && result is WebStorageReady
            ? null
            : Scaffold(
                body: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(28),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Semantics(
                          liveRegion: true,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  title,
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(localPersonalStorageNotice),
                              const SizedBox(height: 16),
                              const Text(
                                'Medication setup is available locally. Today actions and history are not available yet.',
                              ),
                              if (result != null) ...[
                                const SizedBox(height: 16),
                                Text(
                                  uncertain
                                      ? 'Storage cleanup could not be confirmed. Retry is disabled for this session. Do not clear site data to recover.'
                                      : 'Your information has not been opened. No temporary database will be used. Do not clear site data to recover.',
                                ),
                              ],
                              const SizedBox(height: 24),
                              if (_startup.loading)
                                const CircularProgressIndicator()
                              else if (_startup.canStart)
                                OutlinedButton(
                                  onPressed: _startup.start,
                                  child: Text(
                                    result == null
                                        ? 'Continue locally'
                                        : 'Try again',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      );
      // Keep the app/router mounted while consent and storage state change.
      return PersonalSetupScope(
        dependencies: !_startup.loading && result is WebStorageReady
            ? _startup.setup
            : null,
        child: app,
      );
    },
  );
}
