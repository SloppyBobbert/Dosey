import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/app/dosey_material_app.dart';
import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:dosey_app/core/android/robot_phone_setup_gateway.dart';
import 'package:dosey_app/core/build/app_build_profile.dart';
import 'package:dosey_app/core/connectivity/connectivity_gateway.dart';
import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';
import 'package:dosey_app/core/demo/demo_mode_host.dart';
import 'package:dosey_app/core/household/household_sync_gateway.dart';
import 'package:dosey_app/core/household/household_management_gateway.dart';
import 'package:dosey_app/core/household/robot_pairing_gateway.dart';
import 'package:dosey_app/core/notifications/reminder_notification_tap_controller.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/reminders/missed_dose_reconciliation_service.dart';
import 'package:dosey_app/core/runtime/runtime_capability.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/time/app_clock.dart';
import 'package:dosey_app/features/onboarding/onboarding_gate.dart';
import 'package:flutter/widgets.dart';

class DoseyApp extends StatelessWidget {
  const DoseyApp({
    super.key,
    this.database,
    this.reminderScheduler,
    this.permissionGateway,
    this.notificationTapController,
    this.missedDoseReconciliationService,
    this.bleGateway,
    this.connectivityGateway,
    this.shellForceTodayTab = false,
    this.appClock,
    this.demoDatabaseFactory,
    this.cloudIdentityGateway,
    this.householdSyncGateway,
    this.householdManagementGateway,
    this.robotPairingGateway,
    this.buildProfile,
    this.robotPhoneSetupGateway,
    this.runtimeCapability,
  });

  final DoseyDatabase? database;
  final ReminderScheduler? reminderScheduler;
  final AppPermissionGateway? permissionGateway;
  final ReminderNotificationTapController? notificationTapController;
  final MissedDoseReconciliationService? missedDoseReconciliationService;
  final BleGateway? bleGateway;
  final ConnectivityGateway? connectivityGateway;
  final bool shellForceTodayTab;
  final AppClock? appClock;
  final DemoDatabaseFactory? demoDatabaseFactory;
  final CloudIdentityGateway? cloudIdentityGateway;
  final HouseholdSyncGateway? householdSyncGateway;
  final HouseholdManagementGateway? householdManagementGateway;
  final RobotPairingGateway? robotPairingGateway;
  final AppBuildProfile? buildProfile;
  final RobotPhoneSetupGateway? robotPhoneSetupGateway;
  final RuntimeCapability? runtimeCapability;

  @override
  Widget build(BuildContext context) {
    return DemoModeHost(
      productionDatabase: database,
      productionClock: appClock,
      demoDatabaseFactory: demoDatabaseFactory,
      builder: (context, session) => DoseyAppScope(
        key: ValueKey(session.isDemo),
        database: session.database,
        reminderScheduler: reminderScheduler,
        permissionGateway: permissionGateway,
        notificationTapController: notificationTapController,
        missedDoseReconciliationService: session.isDemo
            ? null
            : missedDoseReconciliationService,
        bleGateway: bleGateway,
        connectivityGateway: connectivityGateway,
        cloudIdentityGateway: session.isDemo ? null : cloudIdentityGateway,
        householdSyncGateway: session.isDemo ? null : householdSyncGateway,
        householdManagementGateway: session.isDemo
            ? null
            : householdManagementGateway,
        robotPairingGateway: session.isDemo ? null : robotPairingGateway,
        buildProfile: buildProfile,
        robotPhoneSetupGateway: robotPhoneSetupGateway,
        runtimeCapability: runtimeCapability,
        appClock: session.clock,
        child: DoseyMaterialApp(
          home: OnboardingGate(
            shellForceTodayTab: shellForceTodayTab,
            demoMode: session.isDemo,
          ),
        ),
      ),
    );
  }
}
