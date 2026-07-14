import 'dart:async';
import 'dart:developer' as developer;

import 'package:dosey_app/core/auth/app_auth_service.dart';
import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/auth/local_auth_repository.dart';
import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:dosey_app/core/bluetooth/flutter_blue_plus_ble_gateway.dart';
import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/connectivity/connectivity_gateway.dart';
import 'package:dosey_app/core/connectivity/connectivity_plus_gateway.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/controller/controller_lifecycle_service.dart';
import 'package:dosey_app/core/controller/local_controller_command_repository.dart';
import 'package:dosey_app/core/controller/simulated_controller_gateway.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/notifications/flutter_local_notification_scheduler.dart';
import 'package:dosey_app/core/notifications/reminder_notification_tap_controller.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/permissions/permission_handler_gateway.dart';
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/missed_dose_reconciliation_service.dart';
import 'package:dosey_app/core/reminders/reminder_schedule_service.dart';
import 'package:dosey_app/core/schedules/local_schedule_profile_repository.dart';
import 'package:dosey_app/core/settings/current_device_platform.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/robot_face/robot_face_controller.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings_repository.dart';
import 'package:flutter/widgets.dart';

class DoseyAppScope extends StatefulWidget {
  const DoseyAppScope({
    super.key,
    required this.child,
    this.database,
    this.reminderScheduler,
    this.permissionGateway,
    this.notificationTapController,
    this.missedDoseReconciliationService,
    this.bleGateway,
    this.connectivityGateway,
  });

  final Widget child;
  final DoseyDatabase? database;
  final ReminderScheduler? reminderScheduler;
  final AppPermissionGateway? permissionGateway;
  final ReminderNotificationTapController? notificationTapController;
  final MissedDoseReconciliationService? missedDoseReconciliationService;
  final BleGateway? bleGateway;
  final ConnectivityGateway? connectivityGateway;

  static DoseyAppDependencies of(BuildContext context) {
    final dependencies = maybeOf(context);
    assert(
      dependencies != null,
      'DoseyAppScope was not found in the widget tree.',
    );
    return dependencies!;
  }

  static DoseyAppDependencies? maybeOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_DoseyAppScopeInherited>();
    return scope?.dependencies;
  }

  @override
  State<DoseyAppScope> createState() => _DoseyAppScopeState();
}

class _DoseyAppScopeState extends State<DoseyAppScope> {
  static const _missedDoseReconciliationInterval = Duration(minutes: 15);

  late final DoseyDatabase _database;
  late final bool _ownsDatabase;
  late final bool _ownsNotificationTapController;
  late final StreamController<DateTime> _robotFaceClockController;
  late final Timer _robotFaceClockTimer;
  late final Timer _missedDoseReconciliationTimer;
  late final MissedDoseReconciliationService _missedDoseReconciliation;
  late final DoseyAppDependencies _dependencies;

  @override
  void initState() {
    super.initState();
    _database = widget.database ?? DoseyDatabase();
    _ownsDatabase = widget.database == null;
    _robotFaceClockController = StreamController<DateTime>.broadcast();
    // Robot Face only needs coarse time ticks for reminder ramp/sleep state;
    // user actions and dose logs still update it immediately through streams.
    _robotFaceClockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_robotFaceClockController.isClosed) {
        _robotFaceClockController.add(DateTime.now());
      }
    });
    final doseLog = DriftDoseLogRepository(_database);
    final localAuth = LocalAuthRepository(_database);
    final reminders = LocalReminderRepository(_database);
    final notificationTaps =
        widget.notificationTapController ?? ReminderNotificationTapController();
    _ownsNotificationTapController = widget.notificationTapController == null;
    final reminderScheduler =
        widget.reminderScheduler ??
        FlutterLocalNotificationScheduler(
          notificationTapHandler: notificationTaps.handleTap,
        );
    final settings = LocalAppSettingsRepository(
      _database,
      defaultRole: AppDeviceRole.defaultFor(currentAppDevicePlatform()),
    );
    final robotFaceSettings = RobotFaceSettingsRepository(_database);
    final scheduleProfiles = LocalScheduleProfileRepository(_database);
    final carouselSlots = LocalCarouselSlotRepository(_database);
    final controller = SimulatedControllerGateway(
      canHostRobot: () async {
        final platform = currentAppDevicePlatform();
        final storedRole = await settings.getDeviceRole();
        final role = storedRole.isAllowedOn(platform)
            ? storedRole
            : AppDeviceRole.defaultFor(platform);
        return role.canHostRobot;
      },
    );
    final controllerLifecycle = ControllerLifecycleService(
      controller: controller,
      commandRepository: LocalControllerCommandRepository(_database),
      doseLog: doseLog,
      carouselSlots: carouselSlots,
    );
    _missedDoseReconciliation =
        widget.missedDoseReconciliationService ??
        MissedDoseReconciliationService(
          reminders: reminders,
          doseLog: doseLog,
          carouselSlots: carouselSlots,
          database: _database,
        );
    _missedDoseReconciliationTimer = Timer.periodic(
      _missedDoseReconciliationInterval,
      (_) => unawaited(_runMissedDoseReconciliation()),
    );
    _dependencies = DoseyAppDependencies(
      database: _database,
      settings: settings,
      prescriptions: LocalPrescriptionRepository(_database),
      scheduleProfiles: scheduleProfiles,
      reminders: reminders,
      reminderSchedules: ReminderScheduleService(
        repository: reminders,
        scheduler: reminderScheduler,
      ),
      carouselSlots: carouselSlots,
      doseLog: doseLog,
      localAuth: localAuth,
      auth: AppAuthService(localAuth: localAuth),
      controller: controller,
      controllerLifecycle: controllerLifecycle,
      robotFaceSettings: robotFaceSettings,
      robotFaceController: RobotFaceController(
        settings: settings,
        robotFaceSettings: robotFaceSettings,
        controller: controller,
        controllerLifecycle: controllerLifecycle,
        scheduleProfiles: scheduleProfiles,
        reminders: reminders,
        doseLog: doseLog,
        clock: _robotFaceClockController.stream,
      ),
      ble: widget.bleGateway ?? FlutterBluePlusBleGateway(),
      connectivity: widget.connectivityGateway ?? ConnectivityPlusGateway(),
      reminderScheduler: reminderScheduler,
      notificationTaps: notificationTaps,
      permissions: widget.permissionGateway ?? PermissionHandlerGateway(),
    );
    unawaited(_runStartupMaintenance());
  }

  Future<void> _runStartupMaintenance() async {
    try {
      // Startup sync repairs local notification state without blocking app boot.
      await _dependencies.reminderSchedules.syncScheduledNotifications();
    } on Object catch (error, stackTrace) {
      // Startup sync is best-effort; schedule edits still surface errors.
      developer.log(
        'Startup notification sync failed; continuing app startup.',
        name: 'dosey.app_scope',
        level: 1000,
        error: error,
        stackTrace: stackTrace,
      );
    }

    await _runMissedDoseReconciliation();
  }

  Future<void> _runMissedDoseReconciliation() async {
    try {
      await _missedDoseReconciliation.reconcile();
    } on Object catch (error, stackTrace) {
      // Missed-dose reconciliation is best-effort during startup and runtime.
      developer.log(
        'Missed-dose reconciliation failed; continuing app runtime.',
        name: 'dosey.app_scope',
        level: 1000,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void dispose() {
    _robotFaceClockTimer.cancel();
    _missedDoseReconciliationTimer.cancel();
    unawaited(_robotFaceClockController.close());
    unawaited(_dependencies.controller.close());
    unawaited(_dependencies.robotFaceController.close());
    unawaited(_dependencies.ble.close());
    if (_ownsDatabase) {
      unawaited(_database.close());
    }
    if (_ownsNotificationTapController) {
      _dependencies.notificationTaps.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _DoseyAppScopeInherited(
      dependencies: _dependencies,
      child: widget.child,
    );
  }
}

class DoseyAppDependencies {
  const DoseyAppDependencies({
    required this.database,
    required this.settings,
    required this.prescriptions,
    required this.scheduleProfiles,
    required this.reminders,
    required this.reminderSchedules,
    required this.carouselSlots,
    required this.doseLog,
    required this.localAuth,
    required this.auth,
    required this.controller,
    required this.controllerLifecycle,
    required this.robotFaceSettings,
    required this.robotFaceController,
    required this.ble,
    required this.connectivity,
    required this.reminderScheduler,
    required this.notificationTaps,
    required this.permissions,
  });

  final DoseyDatabase database;
  final LocalAppSettingsRepository settings;
  final LocalPrescriptionRepository prescriptions;
  final LocalScheduleProfileRepository scheduleProfiles;
  final LocalReminderRepository reminders;
  final ReminderScheduleService reminderSchedules;
  final LocalCarouselSlotRepository carouselSlots;
  final DriftDoseLogRepository doseLog;
  final LocalAuthRepository localAuth;
  final AuthService auth;
  final ControllerGateway controller;
  final ControllerLifecycleService controllerLifecycle;
  final RobotFaceSettingsRepository robotFaceSettings;
  final RobotFaceController robotFaceController;
  final BleGateway ble;
  final ConnectivityGateway connectivity;
  final ReminderScheduler reminderScheduler;
  final ReminderNotificationTapController notificationTaps;
  final AppPermissionGateway permissions;
}

class _DoseyAppScopeInherited extends InheritedWidget {
  const _DoseyAppScopeInherited({
    required this.dependencies,
    required super.child,
  });

  final DoseyAppDependencies dependencies;

  @override
  bool updateShouldNotify(_DoseyAppScopeInherited oldWidget) {
    return dependencies != oldWidget.dependencies;
  }
}
