import 'dart:async';
import 'dart:developer' as developer;

import 'package:dosey_app/core/auth/app_auth_service.dart';
import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/auth/google_auth_service.dart';
import 'package:dosey_app/core/auth/local_auth_repository.dart';
import 'package:dosey_app/core/android/method_channel_robot_phone_setup_gateway.dart';
import 'package:dosey_app/core/android/robot_phone_setup_gateway.dart';
import 'package:dosey_app/core/audit/admin_audit_repository.dart';
import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:dosey_app/core/bluetooth/flutter_blue_plus_ble_gateway.dart';
import 'package:dosey_app/core/backup/backup_file_gateway.dart';
import 'package:dosey_app/core/backup/local_backup_service.dart';
import 'package:dosey_app/core/backup/local_backup_store.dart';
import 'package:dosey_app/core/build/app_build_profile.dart';
import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';
import 'package:dosey_app/core/cloud/cloud_google_account_gateway.dart';
import 'package:dosey_app/core/connectivity/connectivity_gateway.dart';
import 'package:dosey_app/core/connectivity/connectivity_plus_gateway.dart';
import 'package:dosey_app/core/carousel/local_guided_carousel_load_repository.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/controller/ble_controller_gateway.dart';
import 'package:dosey_app/core/controller/controller_bench_service.dart';
import 'package:dosey_app/core/controller/controller_health_supervisor.dart';
import 'package:dosey_app/core/controller/controller_lifecycle_service.dart';
import 'package:dosey_app/core/controller/local_controller_command_repository.dart';
import 'package:dosey_app/core/controller/local_controller_health_event_repository.dart';
import 'package:dosey_app/core/controller/simulated_controller_gateway.dart';
import 'package:dosey_app/core/display/screen_awake_gateway.dart';
import 'package:dosey_app/core/demo/demo_data_repository.dart';
import 'package:dosey_app/core/demo/demo_external_services.dart';
import 'package:dosey_app/core/demo/demo_scenario_service.dart';
import 'package:dosey_app/core/audit/local_admin_audit_repository.dart';
import 'package:dosey_app/core/household/local_household_repository.dart';
import 'package:dosey_app/core/household/local_household_cache_repository.dart';
import 'package:dosey_app/core/household/household_sync_gateway.dart';
import 'package:dosey_app/core/household/household_management_gateway.dart';
import 'package:dosey_app/core/household/household_membership_notifier.dart';
import 'package:dosey_app/core/household/robot_pairing_gateway.dart';
import 'package:dosey_app/core/household/paired_robot_readiness_gateway.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/logging/phone_dose_action_service.dart';
import 'package:dosey_app/core/notifications/flutter_local_notification_scheduler.dart';
import 'package:dosey_app/core/notifications/reminder_notification_tap_controller.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/permissions/ble_permission_preparer.dart';
import 'package:dosey_app/core/permissions/notification_permission_gateway.dart';
import 'package:dosey_app/core/permissions/permission_handler_gateway.dart';
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/missed_dose_reconciliation_service.dart';
import 'package:dosey_app/core/reminders/phone_only_missed_dose_reconciliation_service.dart';
import 'package:dosey_app/core/reminders/reminder_schedule_service.dart';
import 'package:dosey_app/core/runtime/runtime_capability.dart';
import 'package:dosey_app/core/runtime/local_phone_device_identity_repository.dart';
import 'package:dosey_app/core/schedules/local_schedule_profile_repository.dart';
import 'package:dosey_app/core/settings/current_device_platform.dart';
import 'package:dosey_app/core/settings/action_pin_gate.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/effective_device_role_source.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/sync/medication_sync_outbox_coordinator.dart';
import 'package:dosey_app/core/sync/sync_outbox_repository.dart';
import 'package:dosey_app/core/time/app_clock.dart';
import 'package:dosey_app/core/voice/voice_player.dart';
import 'package:dosey_app/core/display/flutter_system_ui_gateway.dart';
import 'package:dosey_app/core/display/system_ui_gateway.dart';
import 'package:dosey_app/features/robot_face/demo_face_lab_controller.dart';
import 'package:dosey_app/features/robot_face/robot_face_controller.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings_repository.dart';
import 'package:dosey_app/features/shell/external_action_resume_guard.dart';
import 'package:dosey_app/features/doses/dose_action_service.dart';
import 'package:flutter/widgets.dart';

class DoseyAppScope extends StatefulWidget {
  const DoseyAppScope({
    super.key,
    required this.child,
    this.database,
    this.reminderScheduler,
    this.permissionGateway,
    this.androidSdkGateway,
    this.notificationTapController,
    this.missedDoseReconciliationService,
    this.bleGateway,
    this.connectivityGateway,
    this.voicePlayer,
    this.screenAwakeGateway,
    this.systemUiGateway,
    this.backupFileGateway,
    this.appClock,
    this.controllerGateway,
    this.cloudIdentityGateway,
    this.householdSyncGateway,
    this.householdManagementGateway,
    this.robotPairingGateway,
    this.pairedRobotReadinessGateway,
    this.buildProfile,
    this.robotPhoneSetupGateway,
    this.runtimeCapability,
    this.localTimezoneGateway,
    this.bleGatewayFactory,
    this.permissionGatewayFactory,
    this.notificationPermissionGateway,
    this.medicationSyncOutboxDrain,
    this.enableDemoFaceLab = false,
  });

  final Widget child;
  final DoseyDatabase? database;
  final ReminderScheduler? reminderScheduler;
  final AppPermissionGateway? permissionGateway;
  final AndroidSdkGateway? androidSdkGateway;
  final ReminderNotificationTapController? notificationTapController;
  final MissedDoseReconciler? missedDoseReconciliationService;
  final BleGateway? bleGateway;
  final ConnectivityGateway? connectivityGateway;
  final DoseyVoicePlayer? voicePlayer;
  final ScreenAwakeGateway? screenAwakeGateway;
  final SystemUiGateway? systemUiGateway;
  final BackupFileGateway? backupFileGateway;
  final AppClock? appClock;
  final StagedControllerGateway? controllerGateway;
  final CloudIdentityGateway? cloudIdentityGateway;
  final HouseholdSyncGateway? householdSyncGateway;
  final HouseholdManagementGateway? householdManagementGateway;
  final RobotPairingGateway? robotPairingGateway;
  final PairedRobotReadinessGateway? pairedRobotReadinessGateway;
  final AppBuildProfile? buildProfile;
  final RobotPhoneSetupGateway? robotPhoneSetupGateway;
  final RuntimeCapability? runtimeCapability;
  final LocalTimezoneGateway? localTimezoneGateway;
  final BleGateway Function()? bleGatewayFactory;
  final AppPermissionGateway Function()? permissionGatewayFactory;
  final NotificationPermissionGateway? notificationPermissionGateway;
  final MedicationSyncOutboxDrain? medicationSyncOutboxDrain;
  final bool enableDemoFaceLab;

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

class _DoseyAppScopeState extends State<DoseyAppScope>
    with WidgetsBindingObserver {
  static const _missedDoseReconciliationInterval = Duration(minutes: 15);
  static final _demoSeedTime = DateTime.utc(2040, 1, 2, 8);

  late final DoseyDatabase _database;
  late final bool _ownsDatabase;
  late final bool _ownsNotificationTapController;
  late final AppClock _appClock;
  late final bool _ownsAppClock;
  Timer? _missedDoseReconciliationTimer;
  late final MissedDoseReconciler _missedDoseReconciliation;
  late final DoseyAppDependencies _dependencies;
  Future<void>? _shutdownFuture;
  bool _dependenciesInitialized = false;
  StreamSubscription<AppDeviceRole>? _controllerRoleSubscription;
  ControllerHealthSupervisor? _controllerHealthSupervisor;
  MedicationSyncOutboxCoordinator? _medicationSyncOutboxCoordinator;
  AppDeviceRole? _controllerRole;
  bool _isForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isForeground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _database = widget.database ?? DoseyDatabase();
    _ownsDatabase = widget.database == null;
    assert(
      !_database.isDemo ||
          widget.controllerGateway == null ||
          widget.controllerGateway is SimulatedControllerGateway,
      'Demo mode requires a SimulatedControllerGateway.',
    );
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
    final householdCache = LocalHouseholdCacheRepository(_database);
    final cloudIdentity =
        widget.cloudIdentityGateway ?? const DisabledCloudIdentityGateway();
    final householdSync =
        widget.householdSyncGateway ?? const DisabledHouseholdSyncGateway();
    final householdManagement =
        widget.householdManagementGateway ??
        const DisabledHouseholdManagementGateway();
    final householdMembership = HouseholdMembershipNotifier();
    final robotPairing =
        widget.robotPairingGateway ?? const DisabledRobotPairingGateway();
    final pairedRobotReadiness =
        widget.pairedRobotReadinessGateway ??
        const DisabledPairedRobotReadinessGateway();
    final cloudGoogleAuth = cloudIdentity is DisabledCloudIdentityGateway
        ? null
        : GoogleAuthService(
            localAuth,
            googleAccountGateway: CloudGoogleAccountGateway(cloudIdentity),
          );
    final buildProfile = widget.buildProfile ?? AppBuildProfile.current;
    final runtimeCapability =
        widget.runtimeCapability ?? RuntimeCapability.hardwareAssisted;
    final reminders = LocalReminderRepository(
      _database,
      hardwareEffectsEnabled:
          runtimeCapability == RuntimeCapability.hardwareAssisted,
    );
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
    final effectiveRole = EffectiveDeviceRoleSource(
      settings,
      profile: buildProfile,
      platform: currentAppDevicePlatform(),
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
    final demoStageGate = _database.isDemo ? DemoStageGate() : null;
    final demoIdGenerator = _database.isDemo
        ? DemoCommandSessionIdGenerator()
        : null;
    final connectivity = _database.isDemo
        ? const DemoConnectivityGateway()
        : widget.connectivityGateway ?? ConnectivityPlusGateway();
    final phoneDeviceIdentity = LocalPhoneDeviceIdentityRepository(_database);
    final phoneDoseActions = PhoneDoseActionService(_database);
    final timezoneGateway =
        widget.localTimezoneGateway ??
        const PlatformChannelLocalTimezoneGateway();
    final notificationPermissions =
        widget.notificationPermissionGateway ??
        PermissionHandlerNotificationPermissionGateway();
    final phone = runtimeCapability == RuntimeCapability.phoneOnly
        ? PhoneRuntimeDependencies(
            doseActions: phoneDoseActions,
            deviceIdentity: phoneDeviceIdentity,
            timezoneId: timezoneGateway.localTimezoneName,
          )
        : null;
    if (phone != null) {
      _medicationSyncOutboxCoordinator = MedicationSyncOutboxCoordinator(
        repository: DriftSyncOutboxRepository(_database),
        drain:
            widget.medicationSyncOutboxDrain ??
            const DisabledMedicationSyncOutboxDrain(),
        connectivity: connectivity,
        now: _appClock.now,
      );
    }
    HardwareRuntimeDependencies? hardware;
    StagedControllerGateway? controller;
    ControllerLifecycleService? controllerLifecycle;
    ControllerBenchService? controllerBench;
    LocalControllerCommandRepository? commandRepository;
    LocalControllerHealthEventRepository? controllerHealthEvents;
    BleGateway? ble;
    AppPermissionGateway? permissions;
    LocalCarouselSlotRepository? carouselSlots;
    LocalGuidedCarouselLoadRepository? guidedCarouselLoads;
    DoseActionService? physicalDoseActions;
    if (runtimeCapability == RuntimeCapability.hardwareAssisted) {
      carouselSlots = LocalCarouselSlotRepository(_database);
      guidedCarouselLoads = LocalGuidedCarouselLoadRepository(
        _database,
        urgentShortageNotifier: urgentShortageNotifier,
      );
      physicalDoseActions = DoseActionService(
        database: _database,
        carouselSlots: carouselSlots,
        guidedCarouselLoads: guidedCarouselLoads,
        prescriptions: prescriptions,
        doseLog: doseLog,
      );
      ble = _database.isDemo
          ? const DemoBleGateway()
          : widget.bleGateway ??
                widget.bleGatewayFactory?.call() ??
                FlutterBluePlusBleGateway();
      permissions = _database.isDemo
          ? const DemoPermissionGateway()
          : widget.permissionGateway ??
                widget.permissionGatewayFactory?.call() ??
                PermissionHandlerGateway();
      if (widget.controllerGateway != null) {
        controller = widget.controllerGateway!;
      } else if (_database.isDemo || ble is! DoseyBleGateway) {
        controller = SimulatedControllerGateway(
          canHostRobot: () async =>
              (await effectiveRole.getDeviceRole()).canHostRobot,
          delay: demoStageGate?.wait,
        );
      } else {
        final transportController = BleControllerGateway(
          transport: ble,
          canHostRobot: () async =>
              (await effectiveRole.getDeviceRole()).canHostRobot,
          prepareBleAccess: () => BlePermissionPreparer(
            permissions: permissions!,
            platform: currentAppDevicePlatform(),
            androidSdk:
                widget.androidSdkGateway ??
                const MethodChannelAndroidSdkGateway(),
          ).prepare(),
          commandTimeout: const Duration(seconds: 5),
        );
        controller = ControllerHealthSupervisor(
          delegate: transportController,
          availability: ble.watchAvailability(),
          eventSink: LocalControllerHealthEventRepository(_database),
          now: _appClock.now,
        );
      }
      if (!_database.isDemo && controller is ControllerHealthSupervisor) {
        _controllerHealthSupervisor = controller;
        _controllerRoleSubscription = effectiveRole.watchDeviceRole().listen((
          role,
        ) {
          _controllerRole = role;
          unawaited(_updateControllerMonitoring());
        });
      }
      commandRepository = LocalControllerCommandRepository(
        _database,
        sessionIdGenerator: demoIdGenerator?.call,
      );
      controllerHealthEvents = LocalControllerHealthEventRepository(_database);
      controllerLifecycle = ControllerLifecycleService(
        controller: controller,
        commandRepository: commandRepository,
        doseLog: doseLog,
        carouselSlots: carouselSlots,
        guidedCarouselLoads: guidedCarouselLoads,
        database: _database,
        now: _appClock.now,
      );
      controllerBench = ControllerBenchService(
        controller: controller,
        lifecycle: controllerLifecycle,
        commandRepository: commandRepository,
        now: _appClock.now,
      );
      hardware = HardwareRuntimeDependencies(
        controller: controller,
        controllerLifecycle: controllerLifecycle,
        controllerCommands: commandRepository,
        controllerHealthEvents: controllerHealthEvents,
        controllerBench: controllerBench,
        ble: ble,
        permissions: permissions,
        robotPhoneSetup:
            widget.robotPhoneSetupGateway ??
            MethodChannelRobotPhoneSetupGateway(permissions: permissions),
        carouselSlots: carouselSlots,
        guidedCarouselLoads: guidedCarouselLoads,
        doseActions: physicalDoseActions,
      );
    }
    final robotFaceController = RobotFaceController(
      roleStream: effectiveRole.watchDeviceRole(),
      robotFaceSettings: robotFaceSettings,
      controller: controller,
      controllerLifecycle: controllerLifecycle,
      scheduleProfiles: scheduleProfiles,
      reminders: reminders,
      doseLog: doseLog,
      carouselSlots: hardware == null ? null : carouselSlots,
      shortageAlerts: hardware == null
          ? null
          : guidedCarouselLoads!.watchAllActiveShortageAlerts(),
      connectivity: _database.isDemo ? null : connectivity.watchConnectivity(),
      clock: _appClock.ticks,
      now: _appClock.now,
    );
    _missedDoseReconciliation =
        widget.missedDoseReconciliationService ??
        (phone != null
            ? PhoneOnlyMissedDoseReconciliationService(
                reminders: reminders,
                actions: phoneDoseActions,
                deviceId: phoneDeviceIdentity.getOrCreate,
                timezoneId: timezoneGateway.localTimezoneName,
                now: _appClock.now,
              )
            : MissedDoseReconciliationService(
                reminders: reminders,
                doseLog: doseLog,
                carouselSlots: carouselSlots!,
                database: _database,
                now: _appClock.now,
              ));
    if (!_database.isDemo) {
      _missedDoseReconciliationTimer = Timer.periodic(
        _missedDoseReconciliationInterval,
        (_) => unawaited(_runMissedDoseReconciliation()),
      );
    }
    final demoFaceLab = _database.isDemo && widget.enableDemoFaceLab
        ? DemoFaceLabController()
        : null;
    final demoScenarios = _database.isDemo && hardware != null
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
            controller: controller! as SimulatedControllerGateway,
            stageGate: demoStageGate!,
            idGenerator: demoIdGenerator!,
            lifecycle: controllerLifecycle!,
            bench: controllerBench!,
            commandRepository: commandRepository!,
            doseActions: physicalDoseActions!,
            reconciliation:
                _missedDoseReconciliation as MissedDoseReconciliationService,
            onReset: demoFaceLab?.reset,
          )
        : null;
    _dependencies = DoseyAppDependencies(
      database: _database,
      isDemo: _database.isDemo,
      appClock: _appClock,
      settings: settings,
      buildProfile: buildProfile,
      runtimeCapability: runtimeCapability,
      hardware: hardware,
      phone: phone,
      robotFaceController: robotFaceController,
      notificationPermissions: notificationPermissions,
      effectiveRole: effectiveRole,
      actionPinGate: actionPinGate,
      prescriptions: prescriptions,
      scheduleProfiles: scheduleProfiles,
      reminders: reminders,
      reminderSchedules: reminderSchedules,
      backups: backups,
      doseLog: doseLog,
      adminAudit: adminAudit,
      household: household,
      householdCache: householdCache,
      cloudIdentity: cloudIdentity,
      householdSync: householdSync,
      householdManagement: householdManagement,
      householdMembership: householdMembership,
      robotPairing: robotPairing,
      pairedRobotReadiness: pairedRobotReadiness,
      phoneDeviceIdentity: phoneDeviceIdentity,
      localAuth: localAuth,
      auth: AppAuthService(
        localAuth: localAuth,
        householdCache: householdCache,
        googleAuthService: cloudGoogleAuth,
      ),
      demoScenarios: demoScenarios,
      demoFaceLab: demoFaceLab,
      robotFaceSettings: robotFaceSettings,
      connectivity: connectivity,
      reminderScheduler: reminderScheduler,
      voicePlayer:
          widget.voicePlayer ??
          DoseyVoicePlayer(playbackGateway: JustAudioVoicePlaybackGateway()),
      notificationTaps: notificationTaps,
      // Keeping a mounted display awake is reversible device behavior, unlike
      // the network, notification, and backup effects disabled in demo mode.
      screenAwake:
          widget.screenAwakeGateway ?? const MethodChannelScreenAwakeGateway(),
      systemUi: widget.systemUiGateway ?? FlutterSystemUiGateway(),
      externalActionResumeGuard: ExternalActionResumeGuard<String>(),
      runMissedDoseReconciliation: _runMissedDoseReconciliation,
    );
    _dependenciesInitialized = true;
    final medicationSyncCoordinator = _medicationSyncOutboxCoordinator;
    if (medicationSyncCoordinator != null) {
      unawaited(_startMedicationSync(medicationSyncCoordinator));
    }
    if (_database.isDemo && hardware != null) {
      unawaited(_connectDemoController());
    } else {
      unawaited(_runStartupMaintenance());
    }
  }

  Future<void> _connectDemoController() async {
    try {
      await _dependencies.hardware!.controller.connect();
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

  Future<void> _startMedicationSync(
    MedicationSyncOutboxCoordinator coordinator,
  ) async {
    try {
      await coordinator.start();
    } on Object catch (error, stackTrace) {
      developer.log(
        'Medication sync startup failed; preserving the local outbox.',
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (!_dependenciesInitialized) return;
    if (!_isForeground) {
      unawaited(_dependencies.voicePlayer.stop());
    }
    unawaited(_updateControllerMonitoring());
  }

  Future<void> _updateControllerMonitoring() async {
    final supervisor = _controllerHealthSupervisor;
    final role = _controllerRole;
    if (supervisor == null || role == null) return;
    final eligible =
        _isForeground &&
        currentAppDevicePlatform() == AppDevicePlatform.android &&
        role == AppDeviceRole.androidRobot;
    await supervisor.setMonitoringEligible(eligible);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _missedDoseReconciliationTimer?.cancel();
    if (_dependenciesInitialized) {
      unawaited(_shutdownFuture ??= _shutdownDependencies());
    }
    super.dispose();
  }

  Future<void> _shutdownDependencies() async {
    Object? firstError;
    StackTrace? firstStackTrace;

    Future<void> attempt(Future<void> Function() action) async {
      try {
        await action();
      } on Object catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    void attemptSync(void Function() action) {
      try {
        action();
      } on Object catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    _isForeground = false;
    final roleSubscriptionCancellation = _controllerRoleSubscription?.cancel();
    _controllerRoleSubscription = null;
    final monitoringDisable = _controllerHealthSupervisor
        ?.setMonitoringEligible(false);
    if (_ownsAppClock) {
      if (_appClock case final SystemAppClock clock) {
        attemptSync(clock.stop);
      }
    }

    await attempt(() async => roleSubscriptionCancellation);
    await attempt(() async => monitoringDisable);
    await attempt(() async => _medicationSyncOutboxCoordinator?.dispose());
    await attempt(() async => _dependencies.demoScenarios?.close());
    await attempt(() async => _dependencies.demoFaceLab?.close());
    await attempt(_dependencies.robotFaceController.close);
    final hardware = _dependencies.hardware;
    await attempt(_dependencies.voicePlayer.dispose);
    attemptSync(_dependencies.householdMembership.dispose);

    // Consumers must release their subscriptions before producer gateways close.
    if (hardware != null) {
      await attempt(hardware.controller.close);
      await attempt(hardware.ble.close);
    }
    if (_ownsAppClock) {
      await attempt(() async {
        switch (_appClock) {
          case final SystemAppClock clock:
            await clock.close();
          case final ControllableAppClock clock:
            await clock.close();
        }
      });
    }
    if (_ownsNotificationTapController) {
      attemptSync(_dependencies.notificationTaps.dispose);
    }
    if (_ownsDatabase) {
      await attempt(_database.close);
    }

    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DoseyAppScopeInherited(
      dependencies: _dependencies,
      child: widget.child,
    );
  }
}

class HardwareRuntimeDependencies {
  const HardwareRuntimeDependencies({
    required this.controller,
    required this.controllerLifecycle,
    required this.controllerCommands,
    required this.controllerHealthEvents,
    required this.controllerBench,
    required this.ble,
    required this.permissions,
    required this.robotPhoneSetup,
    required this.carouselSlots,
    required this.guidedCarouselLoads,
    required this.doseActions,
  });

  final ControllerGateway controller;
  final ControllerLifecycleService controllerLifecycle;
  final ControllerCommandRepository controllerCommands;
  final LocalControllerHealthEventRepository controllerHealthEvents;
  final ControllerBenchService controllerBench;
  final BleGateway ble;
  final AppPermissionGateway permissions;
  final RobotPhoneSetupGateway robotPhoneSetup;
  final LocalCarouselSlotRepository carouselSlots;
  final LocalGuidedCarouselLoadRepository guidedCarouselLoads;
  final DoseActionService doseActions;
}

class PhoneRuntimeDependencies {
  const PhoneRuntimeDependencies({
    required this.doseActions,
    required this.deviceIdentity,
    required this.timezoneId,
  });

  final PhoneDoseActionService doseActions;
  final LocalPhoneDeviceIdentityRepository deviceIdentity;
  final Future<String> Function() timezoneId;
}

class DoseyAppDependencies {
  const DoseyAppDependencies({
    required this.database,
    required this.isDemo,
    required this.appClock,
    required this.settings,
    required this.buildProfile,
    required this.runtimeCapability,
    required this.hardware,
    required this.phone,
    required this.robotFaceController,
    required this.notificationPermissions,
    required this.effectiveRole,
    required this.actionPinGate,
    required this.prescriptions,
    required this.scheduleProfiles,
    required this.reminders,
    required this.reminderSchedules,
    required this.backups,
    required this.doseLog,
    required this.adminAudit,
    required this.household,
    required this.householdCache,
    required this.cloudIdentity,
    required this.householdSync,
    required this.householdManagement,
    required this.householdMembership,
    required this.robotPairing,
    required this.pairedRobotReadiness,
    required this.phoneDeviceIdentity,
    required this.localAuth,
    required this.auth,
    required this.demoScenarios,
    required this.demoFaceLab,
    required this.robotFaceSettings,
    required this.connectivity,
    required this.reminderScheduler,
    required this.voicePlayer,
    required this.notificationTaps,
    required this.screenAwake,
    required this.systemUi,
    required this.externalActionResumeGuard,
    required this.runMissedDoseReconciliation,
  });

  final DoseyDatabase database;
  final bool isDemo;
  final AppClock appClock;
  final LocalAppSettingsRepository settings;
  final AppBuildProfile buildProfile;
  final RuntimeCapability runtimeCapability;
  final HardwareRuntimeDependencies? hardware;
  final PhoneRuntimeDependencies? phone;
  final RobotFaceController robotFaceController;
  final NotificationPermissionGateway notificationPermissions;
  final EffectiveDeviceRoleSource effectiveRole;
  final ActionPinGate actionPinGate;
  final LocalPrescriptionRepository prescriptions;
  final LocalScheduleProfileRepository scheduleProfiles;
  final LocalReminderRepository reminders;
  final ReminderScheduleService reminderSchedules;
  final LocalBackupService backups;
  final DriftDoseLogRepository doseLog;
  final AdminAuditRepository adminAudit;
  final LocalHouseholdRepository household;
  final LocalHouseholdCacheRepository householdCache;
  final CloudIdentityGateway cloudIdentity;
  final HouseholdSyncGateway householdSync;
  final HouseholdManagementGateway householdManagement;
  final HouseholdMembershipNotifier householdMembership;
  final RobotPairingGateway robotPairing;
  final PairedRobotReadinessGateway pairedRobotReadiness;
  final LocalPhoneDeviceIdentityRepository phoneDeviceIdentity;
  final LocalAuthRepository localAuth;
  final AuthService auth;
  final DemoScenarioService? demoScenarios;
  final DemoFaceLabController? demoFaceLab;
  final RobotFaceSettingsRepository robotFaceSettings;
  final ConnectivityGateway connectivity;
  final ReminderScheduler reminderScheduler;
  final DoseyVoicePlayer voicePlayer;
  final ReminderNotificationTapController notificationTaps;
  final ScreenAwakeGateway screenAwake;
  final SystemUiGateway systemUi;
  final ExternalActionResumeGuard<String> externalActionResumeGuard;
  final Future<void> Function() runMissedDoseReconciliation;

  ControllerGateway get controller => hardware!.controller;
  ControllerLifecycleService get controllerLifecycle =>
      hardware!.controllerLifecycle;
  ControllerCommandRepository get controllerCommands =>
      hardware!.controllerCommands;
  LocalControllerHealthEventRepository get controllerHealthEvents =>
      hardware!.controllerHealthEvents;
  ControllerBenchService get controllerBench => hardware!.controllerBench;
  BleGateway get ble => hardware!.ble;
  AppPermissionGateway get permissions => hardware!.permissions;
  RobotPhoneSetupGateway get robotPhoneSetup => hardware!.robotPhoneSetup;
  LocalCarouselSlotRepository get carouselSlots => hardware!.carouselSlots;
  LocalGuidedCarouselLoadRepository get guidedCarouselLoads =>
      hardware!.guidedCarouselLoads;
  DoseActionService get doseActions => hardware!.doseActions;
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
