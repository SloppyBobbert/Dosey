import 'dart:async';

import 'package:dosey_app/core/demo/demo_data_repository.dart';
import 'package:dosey_app/core/settings/current_device_platform.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/time/app_clock.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

typedef DemoDatabaseFactory = DoseyDatabase Function();
typedef AppVersionResolver = Future<String> Function();
typedef DemoModeBuilder =
    Widget Function(BuildContext context, DemoModeSession session);

class DemoModeSession {
  const DemoModeSession({
    required this.isDemo,
    required this.database,
    required this.clock,
  });

  final bool isDemo;
  final DoseyDatabase database;
  final AppClock clock;
}

class DemoModeController {
  const DemoModeController._({
    required this.isDemo,
    required this.enter,
    required this.exit,
    required this.completeGuidedTrial,
    required this.productionSettings,
  });

  final bool isDemo;
  final Future<void> Function() enter;
  final Future<void> Function() exit;
  final Future<void> Function() completeGuidedTrial;
  final LocalAppSettingsRepository productionSettings;

  bool get isGuidedTrial => isDemo;
  Future<void> startGuidedTrial() => enter();
  Future<void> exitGuidedTrial() => exit();
}

class DemoModeHost extends StatefulWidget {
  const DemoModeHost({
    super.key,
    required this.builder,
    this.productionDatabase,
    this.productionClock,
    this.demoDatabaseFactory,
    this.devicePlatform,
    this.appVersionResolver,
    this.now,
  });

  final DemoModeBuilder builder;
  final DoseyDatabase? productionDatabase;
  final AppClock? productionClock;
  final DemoDatabaseFactory? demoDatabaseFactory;
  final AppDevicePlatform? devicePlatform;
  final AppVersionResolver? appVersionResolver;
  final DateTime Function()? now;

  static DemoModeController of(BuildContext context) {
    final host = context
        .dependOnInheritedWidgetOfExactType<_DemoModeInherited>();
    assert(host != null, 'DemoModeHost was not found in the widget tree.');
    return host!.controller;
  }

  static DemoModeController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_DemoModeInherited>()
        ?.controller;
  }

  @override
  State<DemoModeHost> createState() => _DemoModeHostState();
}

class _DemoModeHostState extends State<DemoModeHost> {
  static final _seedTime = DateTime.utc(2040, 1, 2, 8);

  late final DoseyDatabase _productionDatabase;
  late final AppClock _productionClock;
  late final bool _ownsProductionDatabase;
  late final bool _ownsProductionClock;
  DoseyDatabase? _demoDatabase;
  ControllableAppClock? _demoClock;
  bool _isDemo = false;
  bool _switching = false;

  LocalAppSettingsRepository get _productionSettings =>
      LocalAppSettingsRepository(
        _productionDatabase,
        defaultRole: AppDeviceRole.defaultFor(
          widget.devicePlatform ?? currentAppDevicePlatform(),
        ),
      );

  @override
  void initState() {
    super.initState();
    _productionDatabase = widget.productionDatabase ?? DoseyDatabase();
    _productionClock = widget.productionClock ?? SystemAppClock();
    _ownsProductionDatabase = widget.productionDatabase == null;
    _ownsProductionClock = widget.productionClock == null;
  }

  Future<void> _enter() async {
    if (_isDemo || _switching) return;
    _switching = true;
    try {
      final database = _demoDatabase ??=
          widget.demoDatabaseFactory?.call() ?? DoseyDatabase.demo();
      final clock = _demoClock ??= ControllableAppClock(_seedTime);
      final platform = widget.devicePlatform ?? currentAppDevicePlatform();
      await DemoDataRepository(
        database,
        seedTime: _seedTime,
        deviceRole: platform == AppDevicePlatform.android
            ? AppDeviceRole.androidRobot
            : AppDeviceRole.iosPersonal,
      ).resetAndSeed();
      clock.set(_seedTime);
      if (!mounted) return;
      setState(() => _isDemo = true);
    } finally {
      _switching = false;
    }
  }

  Future<void> _exit() async {
    if (!_isDemo || _switching) return;
    _switching = true;
    try {
      if (!mounted) return;
      setState(() => _isDemo = false);
    } finally {
      _switching = false;
    }
  }

  Future<void> _completeGuidedTrial() async {
    if (!_isDemo) return;
    final version = await (widget.appVersionResolver ?? _resolveAppVersion)();
    await _productionSettings.setGuidedTrialCompleted(
      completedAt: (widget.now ?? DateTime.now)().toUtc(),
      appVersion: version,
    );
  }

  static Future<String> _resolveAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  @override
  void dispose() {
    if (_ownsProductionClock && _productionClock is SystemAppClock) {
      unawaited(_productionClock.close());
    }
    unawaited(_demoClock?.close());
    if (_ownsProductionDatabase) {
      unawaited(_productionDatabase.close());
    }
    if (widget.demoDatabaseFactory == null) {
      unawaited(_demoDatabase?.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _isDemo
        ? DemoModeSession(
            isDemo: true,
            database: _demoDatabase!,
            clock: _demoClock!,
          )
        : DemoModeSession(
            isDemo: false,
            database: _productionDatabase,
            clock: _productionClock,
          );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: _DemoModeInherited(
        controller: DemoModeController._(
          isDemo: _isDemo,
          enter: _enter,
          exit: _exit,
          completeGuidedTrial: _completeGuidedTrial,
          productionSettings: _productionSettings,
        ),
        child: Column(
          children: [
            if (_isDemo)
              Semantics(
                container: true,
                label: 'Guided trial fake data is active',
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFFFFD54F),
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: const Text(
                    'GUIDED TRIAL - FAKE DATA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF3E2723),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Builder(
                builder: (context) => widget.builder(context, session),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoModeInherited extends InheritedWidget {
  const _DemoModeInherited({required this.controller, required super.child});

  final DemoModeController controller;

  @override
  bool updateShouldNotify(_DemoModeInherited oldWidget) {
    return controller.isDemo != oldWidget.controller.isDemo;
  }
}
