import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/robot_face/robot_face_screen.dart';
import 'package:dosey_app/features/settings/settings_screen.dart';
import 'package:dosey_app/features/shell/dosey_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_scope_dependencies.dart';

void main() {
  testWidgets('Robot Mode opens Robot Face first', (WidgetTester tester) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await _pumpShell(tester, _TestShellApp(database: database));

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Robot Face'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Robot Face'),
      ),
      findsOneWidget,
    );
    expect(find.byType(RobotFaceScreen, skipOffstage: false), findsOneWidget);
    expect(
      tester
          .widget<RobotFaceScreen>(
            find.byType(RobotFaceScreen, skipOffstage: false),
          )
          .isActive,
      isTrue,
    );
  });

  testWidgets('Personal Mode does not show the Robot Face tab', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidPersonal);

    await _pumpShell(tester, _TestShellApp(database: database));

    expect(find.text('Robot Face'), findsNothing);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Today')),
      findsOneWidget,
    );
    expect(find.byType(RobotFaceScreen), findsNothing);
  });

  testWidgets('Robot Face stays mounted and becomes inactive offscreen', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await _pumpShell(tester, _TestShellApp(database: database));

    await tester.tap(
      find
          .descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Robot Face'),
          )
          .hitTestable(),
    );
    await _pumpShellFrame(tester);

    expect(
      tester
          .widget<RobotFaceScreen>(
            find.byType(RobotFaceScreen, skipOffstage: false),
          )
          .isActive,
      isTrue,
    );
    expect(find.text('Robot Face'), findsNWidgets(2));

    await tester.tap(find.text('Controller'));
    await _pumpShellFrame(tester);

    expect(find.byType(RobotFaceScreen, skipOffstage: false), findsOneWidget);
    expect(
      tester
          .widget<RobotFaceScreen>(
            find.byType(RobotFaceScreen, skipOffstage: false),
          )
          .isActive,
      isFalse,
    );
    expect(find.text('Controller'), findsWidgets);
  });

  testWidgets('selected index stays safe when role changes', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await _pumpShell(tester, _TestShellApp(database: database));

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final shellContext = tester.element(find.byType(DoseyShell));
    await DoseyAppScope.of(
      shellContext,
    ).settings.setDeviceRole(AppDeviceRole.androidPersonal);
    await _pumpShellFrame(tester);

    expect(find.byType(DoseyShell), findsOneWidget);
    expect(find.text('Robot Face'), findsNothing);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Settings')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings gear menu lists settings sections and opens safety', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await _pumpShell(tester, _TestShellApp(database: database));

    await _openSettingsMenu(tester);

    expect(find.text('Account'), findsWidgets);
    expect(find.text('Device mode'), findsWidgets);
    expect(find.text('Household & robot profile'), findsOneWidget);
    expect(find.text('Admin history'), findsOneWidget);
    expect(find.text('Robot Face'), findsWidgets);
    expect(find.text('Reminder notifications'), findsWidgets);
    expect(find.text('Prototype safety'), findsWidgets);
    expect(find.text('Help & About'), findsWidgets);
    expect(find.text('Start over setup'), findsWidgets);
    expect(find.text('All settings'), findsOneWidget);

    await tester.tap(find.text('Prototype safety').hitTestable());
    await _pumpShellFrame(tester);

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Settings')),
      findsOneWidget,
    );
    await _scrollSettingsUntilVisible(
      tester,
      find.text('I understand prototype safety rules'),
    );
    expect(find.text('Prototype safety'), findsOneWidget);
    expect(
      find.text('I understand prototype safety rules').hitTestable(),
      findsOneWidget,
    );

    await _scrollSettingsUntilVisible(
      tester,
      find.text('Account'),
      delta: -200,
    );
    expect(find.text('Account').hitTestable(), findsWidgets);

    await _openSettingsMenu(tester);
    await tester.tap(find.text('Prototype safety').hitTestable());
    await _pumpShellFrame(tester);

    await _scrollSettingsUntilVisible(
      tester,
      find.text('I understand prototype safety rules'),
    );
    expect(
      find.text('I understand prototype safety rules').hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('settings gear menu opens Help and About', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await _pumpShell(tester, _TestShellApp(database: database));

    await _openSettingsMenu(tester);

    expect(find.text('Help & About'), findsOneWidget);

    await tester.tap(find.text('Help & About').hitTestable());
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Settings')),
      findsOneWidget,
    );
    expect(
      tester.widget<SettingsScreen>(find.byType(SettingsScreen)).sectionTarget,
      SettingsSection.helpAbout,
    );
    await _scrollSettingsUntilVisible(
      tester,
      find.text('Caregiver sharing and cloud sync are not active yet.'),
    );
    expect(
      find.text('Caregiver sharing and cloud sync are not active yet.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'This prototype is not a medical-grade device. Test only with fake pills, candy, beads, dry beans, or vitamins.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'settings gear menu opens Household & robot profile and Admin history',
    (WidgetTester tester) async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _setDeviceRole(database, AppDeviceRole.androidRobot);

      await _pumpShell(tester, _TestShellApp(database: database));

      await _openSettingsMenu(tester);
      await tester.tap(find.text('Household & robot profile').hitTestable());
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<SettingsScreen>(find.byType(SettingsScreen))
            .sectionTarget,
        SettingsSection.householdAccount,
      );
      await _scrollSettingsUntilVisible(
        tester,
        find.text('Edit household & robot profile'),
      );
      expect(
        find.text('Edit household & robot profile').hitTestable(),
        findsOneWidget,
      );

      await _openSettingsMenu(tester);
      await tester.tap(find.text('Admin history').hitTestable());
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<SettingsScreen>(find.byType(SettingsScreen))
            .sectionTarget,
        SettingsSection.adminHistory,
      );
      await _scrollSettingsUntilVisible(
        tester,
        find.text('No local admin changes recorded yet.'),
      );
      expect(
        find.text('No local admin changes recorded yet.').hitTestable(),
        findsOneWidget,
      );
    },
  );
}

Future<void> _setDeviceRole(DoseyDatabase database, AppDeviceRole role) async {
  final settings = LocalAppSettingsRepository(
    database,
    defaultRole: AppDeviceRole.androidPersonal,
  );
  await settings.setDeviceRole(role);
}

Future<void> _openSettingsMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Open settings menu'));
  await _pumpShellFrame(tester);
}

Future<void> _pumpShell(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await _pumpShellFrame(tester);
}

Future<void> _pumpShellFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _scrollSettingsUntilVisible(
  WidgetTester tester,
  Finder finder, {
  double delta = 200,
}) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find.byType(Scrollable).first,
  );
  await _pumpShellFrame(tester);
}

class _TestShellApp extends StatelessWidget {
  const _TestShellApp({required this.database});

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
      child: const MaterialApp(home: DoseyShell()),
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
