import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:dosey_app/core/connectivity/connectivity_gateway.dart';
import 'package:dosey_app/core/notifications/reminder_notification_tap_controller.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/reminders/missed_dose_reconciliation_service.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/onboarding/onboarding_gate.dart';
import 'package:flutter/material.dart';

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
  });

  final DoseyDatabase? database;
  final ReminderScheduler? reminderScheduler;
  final AppPermissionGateway? permissionGateway;
  final ReminderNotificationTapController? notificationTapController;
  final MissedDoseReconciliationService? missedDoseReconciliationService;
  final BleGateway? bleGateway;
  final ConnectivityGateway? connectivityGateway;
  final bool shellForceTodayTab;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2F6F5E);

    return DoseyAppScope(
      database: database,
      reminderScheduler: reminderScheduler,
      permissionGateway: permissionGateway,
      notificationTapController: notificationTapController,
      missedDoseReconciliationService: missedDoseReconciliationService,
      bleGateway: bleGateway,
      connectivityGateway: connectivityGateway,
      child: MaterialApp(
        title: 'Dosey',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: seed),
          useMaterial3: true,
        ),
        home: OnboardingGate(shellForceTodayTab: shellForceTodayTab),
      ),
    );
  }
}
