import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:dosey_app/core/connectivity/connectivity_gateway.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/missed_dose_reconciliation_service.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings_repository.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings.dart';
import 'package:dosey_app/features/settings/settings_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('robot-capable role shows robot face settings controls', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);

    await tester.pumpWidget(_TestSettingsApp(database: database));
    await tester.pumpAndSettle();
    final scope = tester.element(find.byType(MaterialApp));
    await DoseyAppScope.of(
      scope,
    ).settings.setDeviceRole(AppDeviceRole.androidRobot);
    await tester.pumpAndSettle();

    await _scrollToRobotFace(tester);

    expect(find.text('Robot Face'), findsOneWidget);
    expect(find.text('Flip face 180°'), findsOneWidget);
    expect(find.text('Dim after inactivity'), findsOneWidget);
    expect(find.text('Wake before dose'), findsOneWidget);
    expect(find.text('Stay awake after dose'), findsOneWidget);
    expect(find.text('10 minutes'), findsNWidgets(2));
  });

  testWidgets('personal role does not show robot face settings controls', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(
      database,
      role: AppDeviceRole.androidPersonal,
    );

    await tester.pumpWidget(_TestSettingsApp(database: database));
    await tester.pumpAndSettle();
    final scope = tester.element(find.byType(MaterialApp));
    await DoseyAppScope.of(
      scope,
    ).settings.setDeviceRole(AppDeviceRole.androidPersonal);
    await tester.pumpAndSettle();

    expect(find.text('Robot Face'), findsNothing);
    expect(find.text('Flip face 180°'), findsNothing);
    expect(find.text('Dim after inactivity'), findsNothing);

    final listView = tester.widget<ListView>(find.byType(ListView));
    final children =
        (listView.childrenDelegate as SliverChildListDelegate).children;
    final deviceModeIndex = children.indexWhere(
      (child) => child.runtimeType.toString() == '_DeviceModeCard',
    );

    expect(deviceModeIndex, isNonNegative);
    expect(
      children[deviceModeIndex + 1].runtimeType.toString(),
      '_RobotFaceSettingsSection',
    );

    final spacer = children[deviceModeIndex + 2] as SizedBox;
    expect(spacer.height, 12);
    expect(
      children[deviceModeIndex + 3].runtimeType.toString(),
      '_ReminderNotificationCard',
    );
  });

  testWidgets('robot face controls persist and update state', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);

    await tester.pumpWidget(_TestSettingsApp(database: database));
    await tester.pumpAndSettle();
    final scope = tester.element(find.byType(MaterialApp));
    await DoseyAppScope.of(
      scope,
    ).settings.setDeviceRole(AppDeviceRole.androidRobot);
    await tester.pumpAndSettle();

    final repository = DoseyAppScope.of(scope).robotFaceSettings;

    expect(await repository.getSettings(), const RobotFaceSettings());

    await _scrollToRobotFace(tester);

    await tester.tap(find.text('Flip face 180°'));
    await tester.pumpAndSettle();
    expect(
      await repository.getSettings(),
      const RobotFaceSettings(isFlipped: true),
    );

    await tester.tap(find.text('Dim after inactivity'));
    await tester.pumpAndSettle();
    expect(
      await repository.getSettings(),
      const RobotFaceSettings(isFlipped: true, dimAfterInactivity: false),
    );

    await tester.tap(find.text('10 minutes').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('15 minutes').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('10 minutes').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 minutes').last);
    await tester.pumpAndSettle();

    expect(
      await repository.getSettings(),
      const RobotFaceSettings(
        isFlipped: true,
        dimAfterInactivity: false,
        wakeBeforeDoseMinutes: 15,
        stayAwakeAfterDoseMinutes: 30,
      ),
    );

    final switches = tester.widgetList<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switches.first.value, isTrue);
    expect(switches.last.value, isFalse);
    expect(find.text('15 minutes'), findsOneWidget);
    expect(find.text('30 minutes'), findsOneWidget);
  });

  testWidgets('saved robot face timing values render on load', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);

    await RobotFaceSettingsRepository(database).saveSettings(
      const RobotFaceSettings(
        wakeBeforeDoseMinutes: 15,
        stayAwakeAfterDoseMinutes: 30,
      ),
    );

    await tester.pumpWidget(_TestSettingsApp(database: database));
    await tester.pumpAndSettle();

    await _scrollToRobotFace(tester);

    expect(find.text('15 minutes'), findsOneWidget);
    expect(find.text('30 minutes'), findsOneWidget);
  });

  testWidgets('robot face timing dropdowns resync after repository update', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);

    await tester.pumpWidget(_TestSettingsApp(database: database));
    await tester.pumpAndSettle();

    final scope = tester.element(find.byType(MaterialApp));
    final repository = DoseyAppScope.of(scope).robotFaceSettings;

    await _scrollToRobotFace(tester);

    expect(find.text('10 minutes'), findsNWidgets(2));

    await repository.saveSettings(
      const RobotFaceSettings(
        wakeBeforeDoseMinutes: 15,
        stayAwakeAfterDoseMinutes: 30,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('10 minutes'), findsNothing);
    expect(find.text('15 minutes'), findsOneWidget);
    expect(find.text('30 minutes'), findsOneWidget);
  });

  testWidgets('stale robot role stays hidden on iOS personal mode', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    try {
      await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);
      await database
          .into(database.appSettings)
          .insertOnConflictUpdate(
            AppSettingsCompanion.insert(
              key: 'device_role',
              value: 'android_robot',
              updatedAt: DateTime.now().toUtc(),
            ),
          );

      await tester.pumpWidget(_TestSettingsApp(database: database));
      await tester.pumpAndSettle();

      expect(find.text('Robot Face'), findsNothing);
      expect(find.text('Flip face 180°'), findsNothing);
      expect(find.text('Dim after inactivity'), findsNothing);
      expect(find.text('Wake before dose'), findsNothing);
      expect(find.text('Stay awake after dose'), findsNothing);
      expect(find.text('iOS can only be a personal phone.'), findsOneWidget);
      expect(find.text('iOS personal phone'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Future<void> _scrollToRobotFace(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Robot Face'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _markOnboardingComplete(
  DoseyDatabase database, {
  required AppDeviceRole role,
}) async {
  final settings = LocalAppSettingsRepository(
    database,
    defaultRole: AppDeviceRole.androidPersonal,
  );
  await settings.setDeviceRole(role);
  await settings.setOnboardingCompleted(true);
}

class _TestSettingsApp extends StatelessWidget {
  const _TestSettingsApp({required this.database});

  final DoseyDatabase database;

  @override
  Widget build(BuildContext context) {
    return DoseyAppScope(
      database: database,
      bleGateway: _FakeBleGateway(),
      connectivityGateway: _FakeConnectivityGateway(),
      permissionGateway: const _FakePermissionGateway(),
      reminderScheduler: const _NoopReminderScheduler(),
      missedDoseReconciliationService: _FakeMissedDoseReconciliationService(),
      child: MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6F5E)),
          useMaterial3: true,
        ),
        home: const Scaffold(body: SettingsScreen()),
      ),
    );
  }
}

class _FakeMissedDoseReconciliationService
    extends MissedDoseReconciliationService {
  _FakeMissedDoseReconciliationService()
    : super(reminders: _FakeReminderRepository(), doseLog: _FakeDoseLog());

  @override
  Future<void> reconcile() async {}
}

class _FakeReminderRepository implements ReminderRepository {
  @override
  Future<void> deleteSchedule(String id) async {}

  @override
  Future<void> upsertSchedule(ReminderSchedule schedule) async {}

  @override
  Stream<List<ReminderSchedule>> watchSchedules({String? profileId}) {
    return Stream.value(const <ReminderSchedule>[]);
  }
}

class _FakeDoseLog implements DoseLogRepository {
  @override
  Future<void> addEvent(DoseLogEvent event) async {}

  @override
  Stream<List<DoseLogEvent>> watchEvents() {
    return Stream.value(const <DoseLogEvent>[]);
  }
}

class _FakeBleGateway implements BleGateway {
  @override
  Future<void> close() async {}

  @override
  Future<void> connect({required String deviceId, String? deviceName}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Stream<BleAvailabilitySnapshot> watchAvailability() {
    return Stream.value(const BleAvailabilitySnapshot.available());
  }

  @override
  Stream<BleConnectionSnapshot> watchConnection() {
    return Stream.value(const BleConnectionSnapshot.disconnected());
  }
}

class _FakeConnectivityGateway implements ConnectivityGateway {
  @override
  Future<ConnectivityState> currentConnectivity() async {
    return ConnectivityState.wifi;
  }

  @override
  Stream<ConnectivityState> watchConnectivity() {
    return Stream.value(ConnectivityState.wifi);
  }
}

class _FakePermissionGateway implements AppPermissionGateway {
  const _FakePermissionGateway();

  @override
  Future<AppPermissionState> check(AppPermission permission) async {
    return AppPermissionState.granted;
  }

  @override
  Future<AppPermissionState> request(AppPermission permission) async {
    return AppPermissionState.granted;
  }
}

class _NoopReminderScheduler implements ReminderScheduler {
  const _NoopReminderScheduler();

  @override
  Future<void> cancelDoseReminder(String doseId) async {}

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> scheduleDoseReminder({
    required String doseId,
    required DateTime scheduledFor,
    required String label,
    required bool repeatsDaily,
  }) async {}
}
