import 'dart:async';
import 'dart:developer' as developer;

import 'package:dosey_app/core/auth/app_auth_service.dart';
import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/auth/local_auth_repository.dart';
import 'package:dosey_app/core/audit/admin_audit_repository.dart';
import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:dosey_app/core/bluetooth/flutter_blue_plus_ble_gateway.dart';
import 'package:dosey_app/core/backup/backup_file_gateway.dart';
import 'package:dosey_app/core/backup/local_backup_service.dart';
import 'package:dosey_app/core/backup/local_backup_store.dart';
import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/connectivity/connectivity_gateway.dart';
import 'package:dosey_app/core/connectivity/connectivity_plus_gateway.dart';
import 'package:dosey_app/core/carousel/local_guided_carousel_load_repository.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/controller/ble_controller_gateway.dart';
import 'package:dosey_app/core/controller/controller_bench_service.dart';
import 'package:dosey_app/core/controller/controller_lifecycle_service.dart';
import 'package:dosey_app/core/controller/local_controller_command_repository.dart';
import 'package:dosey_app/core/controller/simulated_controller_gateway.dart';
import 'package:dosey_app/core/display/screen_awake_gateway.dart';
import 'package:dosey_app/core/demo/demo_data_repository.dart';
import 'package:dosey_app/core/demo/demo_external_services.dart';
import 'package:dosey_app/core/demo/demo_scenario_service.dart';
import 'package:dosey_app/core/audit/local_admin_audit_repository.dart';
import 'package:dosey_app/core/household/local_household_repository.dart';
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
import 'package:dosey_app/core/settings/action_pin_gate.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/time/app_clock.dart';
import 'package:dosey_app/core/voice/voice_player.dart';
import 'package:dosey_app/features/robot_face/robot_face_controller.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings_repository.dart';
import 'package:dosey_app/features/doses/dose_action_service.dart';
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
    this.voicePlayer,
    this.screenAwakeGateway,
    this.backupFileGateway,
    this.appClock,
    this.controllerGateway,
  });

  final Widget child;
  final DoseyDatabase? database;
  final ReminderScheduler? reminderScheduler;
  final AppPermissionGateway? permissionGateway;
  final ReminderNotificationTapController? notificationTapController;
  final MissedDoseReconciliationService? missedDoseReconciliationService;
  final BleGateway? bleGateway;
  final ConnectivityGateway? connectivityGateway;
  final DoseyVoicePlayer? voicePlayer;
  final ScreenAwakeGateway? screenAwakeGateway;
  final BackupFileGateway? backupFileGateway;
  final AppClock? appClock;
  final SimulatedControllerGateway? controllerGateway;

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
  static final _demoSeedTime = DateTime.utc(2040, 1, 2, 8);

  late final DoseyDatabase _database;
  late final bool _ownsDatabase;
  late final bool _ownsNotificationTapController;
  late final AppClock _appClock;
  late final bool _ownsAppClock;
  Timer? _missedDoseReconciliationTimer;
  late final MissedDoseReconciliationService _missedDoseReconciliation;
  late final DoseyAppDependencies _dependencies;

  @override
  void initState() {
    super.initState();
    _database = widget.database ?? DoseyDatabase();
    _ownsDatabase = widget.database == null;
    if (_database.isDemo &&
        widget.appClock != null &&
        widget.appClock is! ControllableAppClock) {
      throw ArgumentError('Demo mode requires a controllable app clock.');
    }
    _appClock =
        widget.appClock ??
        (_database.isDemo
            ? ControllableAppClock(_demoSeedTime)
            : SystemAppClock());
    _ownsAppClock = widget.appClock == null;
    final doseLog = DriftDoseLogRepository(_database);
    final adminAudit = LocalAdminAuditRepository(_database);
    final localAuth = LocalAuthRepository(_database);
    final household = LocalHouseholdRepository(_database);
    final reminders = LocalReminderRepository(_database);
    final notificationTaps =
        widget.notificationTapController ?? ReminderNotificationTapController();
    _ownsNotificationTapController = widget.notificationTapController == null;
    final reminderScheduler = _database.isDemo
        ? const DemoReminderScheduler()
        : widget.reminderScheduler ??
              FlutterLocalNotificationScheduler(
                notificationTapHandler: notificationTaps.handleTap,
              );
    final reminderSchedules = ReminderScheduleService(
      repository: reminders,
      scheduler: reminderScheduler,
    );
    final urgentShortageNotifier = reminderScheduler is UrgentShortageNotifier
        ? reminderScheduler as UrgentShortageNotifier
        : null;
    final settings = LocalAppSettingsRepository(
      _database,
      defaultRole: AppDeviceRole.defaultFor(currentAppDevicePlatform()),
    );
    final actionPinGate = ActionPinGate(settings);
    final backups = LocalBackupService(
      database: _database,
      store: LocalBackupStore(_database),
      gateway: _database.isDemo
          ? const DemoBackupFileGateway()
          : widget.backupFileGateway ?? const PluginBackupFileGateway(),
      syncNotifications: reminderSchedules.syncScheduledNotifications,
    );
    final robotFaceSettings = RobotFaceSettingsRepository(_database);
    final scheduleProfiles = LocalScheduleProfileRepository(_database);
    final prescriptions = LocalPrescriptionRepository(_database);
    final carouselSlots = LocalCarouselSlotRepository(_database);
    final guidedCarouselLoads = LocalGuidedCarouselLoadRepository(
      _database,
      urgentShortageNotifier: urgentShortageNotifier,
    );
    final demoStageGate = _database.isDemo ? DemoStageGate() : null;
    final demoIdGenerator = _database.isDemo
        ? DemoCommandSessionIdGenerator()
        : null;
    final ble = _database.isDemo
        ? const DemoBleGateway()
        : widget.bleGateway ?? FlutterBluePlusBleGateway();
    final permissions = _database.isDemo
        ? const DemoPermissionGateway()
        : widget.permissionGateway ?? PermissionHandlerGateway();
    final controller =
        widget.controllerGateway ??
        (!_database.isDemo && ble is DoseyBleGateway
            ? BleControllerGateway(
                transport: ble,
                canHostRobot: () => _canHostRobot(settings),
                prepareBleAccess: () => _prepareBleAccess(permissions),
              )
            : SimulatedControllerGateway(
                canHostRobot: () => _canHostRobot(settings),
                delay: demoStageGate?.wait,
              ));
    final commandRepository = LocalControllerCommandRepository(
      _database,
      sessionIdGenerator: demoIdGenerator?.call,
    );
    final controllerLifecycle = ControllerLifecycleService(
      controller: controller,
      commandRepository: commandRepository,
      doseLog: doseLog,
      carouselSlots: carouselSlots,
      guidedCarouselLoads: guidedCarouselLoads,
      database: _database,
      now: _appClock.now,
    );
    _missedDoseReconciliation =
        widget.missedDoseReconciliationService ??
        MissedDoseReconciliationService(
          reminders: reminders,
          doseLog: doseLog,
          carouselSlots: carouselSlots,
          database: _database,
          now: _appClock.now,
        );
    if (!_database.isDemo) {
      _missedDoseReconciliationTimer = Timer.periodic(
        _missedDoseReconciliationInterval,
        (_) => unawaited(_runMissedDoseReconciliation()),
      );
    }
    final controllerBench = ControllerBenchService(
      controller: controller,
      lifecycle: controllerLifecycle,
      commandRepository: commandRepository,
      now: _appClock.now,
    );
    final doseActions = DoseActionService(
      database: _database,
      carouselSlots: carouselSlots,
      guidedCarouselLoads: guidedCarouselLoads,
      prescriptions: prescriptions,
      doseLog: doseLog,
    );
    final demoScenarios = _database.isDemo
        ? DemoScenarioService(
            data: DemoDataRepository(
              _database,
              seedTime: _appClock.now(),
              deviceRole:
                  currentAppDevicePlatform() == AppDevicePlatform.android
                  ? AppDeviceRole.androidRobot
                  : AppDeviceRole.iosPersonal,
            ),
            database: _database,
            clock: _appClock as ControllableAppClock,
            controller: controller as SimulatedControllerGateway,
            stageGate: demoStageGate!,
            idGenerator: demoIdGenerator!,
            lifecycle: controllerLifecycle,
            bench: controllerBench,
            commandRepository: commandRepository,
            doseActions: doseActions,
            reconciliation: _missedDoseReconciliation,
          )
        : null;
    _dependencies = DoseyAppDependencies(
      database: _database,
      isDemo: _database.isDemo,
      appClock: _appClock,
      settings: settings,
      actionPinGate: actionPinGate,
      prescriptions: prescriptions,
      doseActions: doseActions,
      scheduleProfiles: scheduleProfiles,
      reminders: reminders,
      reminderSchedules: reminderSchedules,
      backups: backups,
      carouselSlots: carouselSlots,
      guidedCarouselLoads: guidedCarouselLoads,
      doseLog: doseLog,
      adminAudit: adminAudit,
      household: household,
      localAuth: localAuth,
      auth: AppAuthService(localAuth: localAuth),
      controller: controller,
      controllerLifecycle: controllerLifecycle,
      controllerCommands: commandRepository,
      controllerBench: controllerBench,
      demoScenarios: demoScenarios,
      robotFaceSettings: robotFaceSettings,
      robotFaceController: RobotFaceController(
        settings: settings,
        robotFaceSettings: robotFaceSettings,
        controller: controller,
        controllerLifecycle: controllerLifecycle,
        scheduleProfiles: scheduleProfiles,
        reminders: reminders,
        doseLog: doseLog,
        carouselSlots: carouselSlots,
        shortageAlerts: guidedCarouselLoads.watchAllActiveShortageAlerts(),
        clock: _appClock.ticks,
        now: _appClock.now,
      ),
      ble: ble,
      connectivity: _database.isDemo
          ? const DemoConnectivityGateway()
          : widget.connectivityGateway ?? ConnectivityPlusGateway(),
      reminderScheduler: reminderScheduler,
      voicePlayer:
          widget.voicePlayer ??
          DoseyVoicePlayer(playbackGateway: JustAudioVoicePlaybackGateway()),
      notificationTaps: notificationTaps,
      permissions: permissions,
      // Keeping a mounted display awake is reversible device behavior, unlike
      // the network, notification, and backup effects disabled in demo mode.
      screenAwake:
          widget.screenAwakeGateway ?? const MethodChannelScreenAwakeGateway(),
      runMissedDoseReconciliation: _runMissedDoseReconciliation,
    );
    if (_database.isDemo) {
      unawaited(_connectDemoController());
    } else {
      unawaited(_runStartupMaintenance());
    }
  }

  Future<bool> _canHostRobot(LocalAppSettingsRepository settings) async {
    final platform = currentAppDevicePlatform();
    final storedRole = await settings.getDeviceRole();
    final role = storedRole.isAllowedOn(platform)
        ? storedRole
        : AppDeviceRole.defaultFor(platform);
    return role.canHostRobot;
  }

  Future<bool> _prepareBleAccess(AppPermissionGateway permissions) async {
    for (final permission in const [
      AppPermission.bluetoothScan,
      AppPermission.bluetoothConnect,
    ]) {
      var state = await permissions.check(permission);
      if (state != AppPermissionState.granted) {
        state = await permissions.request(permission);
      }
      if (state != AppPermissionState.granted) return false;
    }
    return true;
  }

  Future<void> _connectDemoController() async {
    try {
      await _dependencies.controller.connect();
    } on Object catch (error, stackTrace) {
      developer.log(
        'Demo controller connection failed; continuing app startup.',
        name: 'dosey.app_scope',
        level: 1000,
        error: error,
        stackTrace: stackTrace,
      );
    }
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
    _missedDoseReconciliationTimer?.cancel();
    if (_ownsAppClock) {
      if (_appClock case final SystemAppClock clock) {
        unawaited(clock.close());
      } else if (_appClock case final ControllableAppClock clock) {
        unawaited(clock.close());
      }
    }
    unawaited(_dependencies.controller.close());
    unawaited(_dependencies.demoScenarios?.close());
    unawaited(_dependencies.robotFaceController.close());
    unawaited(_dependencies.ble.close());
    unawaited(_dependencies.voicePlayer.dispose());
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
    required this.isDemo,
    required this.appClock,
    required this.settings,
    required this.actionPinGate,
    required this.prescriptions,
    required this.doseActions,
    required this.scheduleProfiles,
    required this.reminders,
    required this.reminderSchedules,
    required this.backups,
    required this.carouselSlots,
    required this.guidedCarouselLoads,
    required this.doseLog,
    required this.adminAudit,
    required this.household,
    required this.localAuth,
    required this.auth,
    required this.controller,
    required this.controllerLifecycle,
    required this.controllerCommands,
    required this.controllerBench,
    required this.demoScenarios,
    required this.robotFaceSettings,
    required this.robotFaceController,
    required this.ble,
    required this.connectivity,
    required this.reminderScheduler,
    required this.voicePlayer,
    required this.notificationTaps,
    required this.permissions,
    required this.screenAwake,
    required this.runMissedDoseReconciliation,
  });

  final DoseyDatabase database;
  final bool isDemo;
  final AppClock appClock;
  final LocalAppSettingsRepository settings;
  final ActionPinGate actionPinGate;
  final LocalPrescriptionRepository prescriptions;
  final DoseActionService doseActions;
  final LocalScheduleProfileRepository scheduleProfiles;
  final LocalReminderRepository reminders;
  final ReminderScheduleService reminderSchedules;
  final LocalBackupService backups;
  final LocalCarouselSlotRepository carouselSlots;
  final LocalGuidedCarouselLoadRepository guidedCarouselLoads;
  final DriftDoseLogRepository doseLog;
  final AdminAuditRepository adminAudit;
  final LocalHouseholdRepository household;
  final LocalAuthRepository localAuth;
  final AuthService auth;
  final ControllerGateway controller;
  final ControllerLifecycleService controllerLifecycle;
  final ControllerCommandRepository controllerCommands;
  final ControllerBenchService controllerBench;
  final DemoScenarioService? demoScenarios;
  final RobotFaceSettingsRepository robotFaceSettings;
  final RobotFaceController robotFaceController;
  final BleGateway ble;
  final ConnectivityGateway connectivity;
  final ReminderScheduler reminderScheduler;
  final DoseyVoicePlayer voicePlayer;
  final ReminderNotificationTapController notificationTaps;
  final AppPermissionGateway permissions;
  final ScreenAwakeGateway screenAwake;
  final Future<void> Function() runMissedDoseReconciliation;
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
