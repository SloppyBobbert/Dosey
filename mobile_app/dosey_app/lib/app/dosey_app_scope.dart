import 'dart:async';

import 'package:dosey_app/core/auth/app_auth_service.dart';
import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/auth/local_auth_repository.dart';
import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:dosey_app/core/bluetooth/flutter_blue_plus_ble_gateway.dart';
import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/connectivity/connectivity_gateway.dart';
import 'package:dosey_app/core/connectivity/connectivity_plus_gateway.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/controller/simulated_controller_gateway.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/notifications/flutter_local_notification_scheduler.dart';
import 'package:dosey_app/core/notifications/reminder_notification_tap_controller.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/permissions/permission_handler_gateway.dart';
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule_service.dart';
import 'package:dosey_app/core/schedules/local_schedule_profile_repository.dart';
import 'package:dosey_app/core/settings/current_device_platform.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter/widgets.dart';

class DoseyAppScope extends StatefulWidget {
  const DoseyAppScope({
    super.key,
    required this.child,
    this.database,
    this.reminderScheduler,
    this.permissionGateway,
    this.notificationTapController,
  });

  final Widget child;
  final DoseyDatabase? database;
  final ReminderScheduler? reminderScheduler;
  final AppPermissionGateway? permissionGateway;
  final ReminderNotificationTapController? notificationTapController;

  static DoseyAppDependencies of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_DoseyAppScopeInherited>();
    assert(scope != null, 'DoseyAppScope was not found in the widget tree.');
    return scope!.dependencies;
  }

  @override
  State<DoseyAppScope> createState() => _DoseyAppScopeState();
}

class _DoseyAppScopeState extends State<DoseyAppScope> {
  late final DoseyDatabase _database;
  late final bool _ownsDatabase;
  late final bool _ownsNotificationTapController;
  late final DoseyAppDependencies _dependencies;

  @override
  void initState() {
    super.initState();
    _database = widget.database ?? DoseyDatabase();
    _ownsDatabase = widget.database == null;
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
    _dependencies = DoseyAppDependencies(
      database: _database,
      settings: settings,
      prescriptions: LocalPrescriptionRepository(_database),
      scheduleProfiles: LocalScheduleProfileRepository(_database),
      reminders: reminders,
      reminderSchedules: ReminderScheduleService(
        repository: reminders,
        scheduler: reminderScheduler,
      ),
      carouselSlots: LocalCarouselSlotRepository(_database),
      doseLog: doseLog,
      localAuth: localAuth,
      auth: AppAuthService(localAuth: localAuth),
      controller: SimulatedControllerGateway(
        doseLog,
        canHostRobot: () async {
          final platform = currentAppDevicePlatform();
          final storedRole = await settings.getDeviceRole();
          final role = storedRole.isAllowedOn(platform)
              ? storedRole
              : AppDeviceRole.defaultFor(platform);
          return role.canHostRobot;
        },
      ),
      ble: FlutterBluePlusBleGateway(),
      connectivity: ConnectivityPlusGateway(),
      reminderScheduler: reminderScheduler,
      notificationTaps: notificationTaps,
      permissions: widget.permissionGateway ?? PermissionHandlerGateway(),
    );
    unawaited(_syncReminderNotifications());
  }

  Future<void> _syncReminderNotifications() async {
    try {
      await _dependencies.reminderSchedules.syncScheduledNotifications();
    } on Object {
      // Startup sync is best-effort; schedule edits still surface errors.
    }
  }

  @override
  void dispose() {
    unawaited(_dependencies.controller.close());
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
