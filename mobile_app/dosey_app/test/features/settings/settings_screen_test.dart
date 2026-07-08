import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
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

  testWidgets('toggling robot face controls persists and updates state', (
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

    final switches = tester.widgetList<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switches.first.value, isTrue);
    expect(switches.last.value, isFalse);
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
      permissionGateway: const _FakePermissionGateway(),
      reminderScheduler: const _NoopReminderScheduler(),
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
