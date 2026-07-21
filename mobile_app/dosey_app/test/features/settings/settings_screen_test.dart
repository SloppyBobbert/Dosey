import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings_repository.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings.dart';
import 'package:dosey_app/features/settings/settings_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_scope_dependencies.dart';

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
    expect(find.text('For upside-down mounts.'), findsOneWidget);
    expect(find.text('Dim after inactivity'), findsOneWidget);
    expect(
      find.text(
        'After quiet time, show a darker resting face. Dose alerts still stay bright.',
      ),
      findsOneWidget,
    );
    expect(find.text('Wake before dose'), findsOneWidget);
    expect(find.text('Stay awake after dose'), findsOneWidget);
    expect(
      find.text('Brighten the face before a scheduled dose.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Keep the face awake while someone confirms, skips, or asks for help.',
      ),
      findsOneWidget,
    );
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
      children[deviceModeIndex + 2].runtimeType.toString(),
      '_ActionPinCard',
    );
    expect(
      children[deviceModeIndex + 3].runtimeType.toString(),
      '_RobotFaceSettingsSection',
    );

    final spacer = children[deviceModeIndex + 4] as SizedBox;
    expect(spacer.height, 12);
    expect(
      children[deviceModeIndex + 5].runtimeType.toString(),
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
    await tester.tap(find.text('Robot voice'));
    await tester.pumpAndSettle();
    expect(
      await repository.getSettings(),
      const RobotFaceSettings(
        isFlipped: true,
        dimAfterInactivity: false,
        voiceEnabled: false,
      ),
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
        voiceEnabled: false,
        wakeBeforeDoseMinutes: 15,
        stayAwakeAfterDoseMinutes: 30,
      ),
    );

    final switches = tester.widgetList<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switches.elementAt(0).value, isTrue);
    expect(switches.elementAt(1).value, isFalse);
    expect(switches.elementAt(2).value, isFalse);
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

  testWidgets('action PIN section enables PIN after matching entry', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(_TestSettingsApp(database: database));
    await tester.pumpAndSettle();
    final scope = tester.element(find.byType(MaterialApp));
    final settings = DoseyAppScope.of(scope).settings;

    await _scrollToActionPin(tester);
    expect(find.text('Action PIN'), findsOneWidget);
    expect(find.text('PIN is off'), findsOneWidget);

    await tester.tap(find.text('Enable PIN'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('new-action-pin-field')),
      '1234',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-action-pin-field')),
      '1234',
    );
    await tester.tap(find.text('Save PIN'));
    await tester.pumpAndSettle();

    expect(await settings.verifyActionPin('1234'), isTrue);
    expect(find.text('PIN is on'), findsOneWidget);
  });

  testWidgets('action PIN section rejects mismatched new PIN values', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(_TestSettingsApp(database: database));
    await tester.pumpAndSettle();
    final scope = tester.element(find.byType(MaterialApp));
    final settings = DoseyAppScope.of(scope).settings;

    await _scrollToActionPin(tester);
    await tester.tap(find.text('Enable PIN'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('new-action-pin-field')),
      '1234',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-action-pin-field')),
      '4321',
    );
    await tester.tap(find.text('Save PIN'));
    await tester.pump();

    expect(await settings.verifyActionPin('1234'), isFalse);
    expect(find.text('PIN entries do not match.'), findsOneWidget);

    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    await tester.pump();
  });

  testWidgets('action PIN section filters non-digit new PIN values', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(_TestSettingsApp(database: database));
    await tester.pumpAndSettle();
    final scope = tester.element(find.byType(MaterialApp));
    final settings = DoseyAppScope.of(scope).settings;

    await _scrollToActionPin(tester);
    await tester.tap(find.text('Enable PIN'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('new-action-pin-field')),
      '12a4',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-action-pin-field')),
      '12a4',
    );
    final newPinField = tester.widget<TextField>(
      find.byKey(const Key('new-action-pin-field')),
    );
    expect(newPinField.controller?.text, '124');
    await tester.tap(find.text('Save PIN'));
    await tester.pump();

    expect(await settings.verifyActionPin('12a4'), isFalse);
    expect(find.text('Use at least 4 digits.'), findsOneWidget);

    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    await tester.pump();
  });

  testWidgets('action PIN section requires current PIN before disabling', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );
    await repository.setActionPin('1234');

    await tester.pumpWidget(_TestSettingsApp(database: database));
    await tester.pumpAndSettle();
    final scope = tester.element(find.byType(MaterialApp));
    final settings = DoseyAppScope.of(scope).settings;

    await _scrollToActionPin(tester);
    expect(find.text('PIN is on'), findsOneWidget);

    await tester.tap(find.text('Disable PIN'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('action-pin-field')), '4321');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(await settings.verifyActionPin('1234'), isTrue);
    expect(find.text('Wrong PIN.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('action-pin-field')), '1234');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(await settings.verifyActionPin('1234'), isFalse);
    expect(find.text('PIN is off'), findsOneWidget);
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

Future<void> _scrollToActionPin(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Action PIN'),
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
      bleGateway: FakeBleGateway(),
      connectivityGateway: FakeConnectivityGateway(),
      permissionGateway: const _FakePermissionGateway(),
      reminderScheduler: const _NoopReminderScheduler(),
      missedDoseReconciliationService: FakeMissedDoseReconciliationService(),
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
