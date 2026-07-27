import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/notifications/reminder_notification_tap_controller.dart';
import 'package:dosey_app/core/display/screen_awake_gateway.dart';
import 'package:dosey_app/core/display/system_ui_gateway.dart';
import 'package:dosey_app/core/controller/simulated_controller_gateway.dart';
import 'package:dosey_app/core/demo/demo_data_repository.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/schedules/local_schedule_profile_repository.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/time/app_clock.dart';
import 'package:dosey_app/features/robot_face/robot_face_screen.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings_repository.dart';
import 'package:dosey_app/features/shell/dosey_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_scope_dependencies.dart';
import '../../support/bottom_navigation_test_helper.dart';

void main() {
  for (final role in AppDeviceRole.values) {
    testWidgets('${role.name} exposes exactly four bottom destinations', (
      tester,
    ) async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _setDeviceRole(database, role);

      await _pumpShell(tester, _TestShellApp(database: database));

      if (role.canHostRobot) {
        await tester.longPress(find.byKey(RobotFaceScreen.displayFrameKey));
        await _pumpShellFrame(tester);
      }

      final navigationBar = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(
        navigationBar.destinations.cast<NavigationDestination>().map(
          (destination) => destination.label,
        ),
        ['Dashboard', 'Schedule', 'Carousel', 'Settings'],
      );
    });
  }

  testWidgets(
    'bottom navigation adapts across supported sizes and text scales',
    (tester) async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _setDeviceRole(database, AppDeviceRole.androidPersonal);

      for (final width in [320.0, 360.0]) {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        for (final scale in [1.0, 1.3, 1.4]) {
          await _pumpShell(
            tester,
            _TestShellApp(
              database: database,
              textScaler: TextScaler.linear(scale),
            ),
          );

          final navigationBar = tester.widget<NavigationBar>(
            find.byType(NavigationBar),
          );
          expect(
            navigationBar.labelBehavior,
            scale > 1.3
                ? NavigationDestinationLabelBehavior.alwaysHide
                : NavigationDestinationLabelBehavior.alwaysShow,
          );
          for (final label in [
            'Dashboard',
            'Schedule',
            'Carousel',
            'Settings',
          ]) {
            expect(find.byTooltip(label), findsWidgets);
          }
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets('Robot Mode opens Robot Face first', (WidgetTester tester) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await _pumpShell(tester, _TestShellApp(database: database));

    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Robot Face'),
      ),
      findsNothing,
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

  testWidgets('Robot Mode launches directly to Dashboard in portrait', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await _pumpShell(tester, _TestShellApp(database: database));

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Dashboard'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<RobotFaceScreen>(
            find.byType(RobotFaceScreen, skipOffstage: false),
          )
          .isActive,
      isFalse,
    );

    await tester.tap(find.text('Robot Face').hitTestable());
    await _pumpShellFrame(tester);
    expect(
      find.text('Rotate to landscape to open Robot Face.'),
      findsOneWidget,
    );
    expect(_appBarTitle('Dashboard'), findsOneWidget);
  });

  testWidgets('Robot Mode resume stays on Dashboard in portrait', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);
    await _pumpShell(tester, _TestShellApp(database: database));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpShellFrame(tester);

    expect(_appBarTitle('Dashboard'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('Face requests full screen and Dashboard restores app UI', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final systemUi = _FakeSystemUiGateway();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await _pumpShell(
      tester,
      _TestShellApp(database: database, systemUiGateway: systemUi),
    );

    expect(systemUi.states.last, isTrue);
    await tester.longPress(find.byKey(RobotFaceScreen.displayFrameKey));
    await _pumpShellFrame(tester);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(systemUi.states.last, isFalse);
  });

  testWidgets('portrait to landscape reopens Face only from Dashboard', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);
    await _pumpShell(tester, _TestShellApp(database: database));

    tester.view.physicalSize = const Size(900, 600);
    await _pumpShellFrame(tester);
    _expectRobotFaceVisible();

    await tester.longPress(find.byKey(RobotFaceScreen.displayFrameKey));
    await _pumpShellFrame(tester);
    expect(_appBarTitle('Dashboard'), findsOneWidget);
    await _pumpShellFrame(tester);
    expect(_appBarTitle('Dashboard'), findsOneWidget);

    await _openBottomDestination(tester, 'Schedule');
    tester.view.physicalSize = const Size(600, 900);
    await _pumpShellFrame(tester);
    tester.view.physicalSize = const Size(900, 600);
    await _pumpShellFrame(tester);
    expect(_appBarTitle('Schedule'), findsOneWidget);
  });

  testWidgets('cold-start notification wins over default Face routing', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final notificationTaps = ReminderNotificationTapController();
    addTearDown(database.close);
    addTearDown(notificationTaps.dispose);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);
    notificationTaps.handleTap('shortage:shortage-1|slot:2');

    await _pumpShell(
      tester,
      _TestShellApp(
        database: database,
        notificationTapController: notificationTaps,
      ),
    );

    expect(_appBarTitle('Carousel'), findsOneWidget);
    expect(notificationTaps.takePendingTap(), isNull);
  });

  testWidgets('nested route restores chrome and returning Face re-enters', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final systemUi = _FakeSystemUiGateway();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);
    await _pumpShell(
      tester,
      _TestShellApp(database: database, systemUiGateway: systemUi),
    );
    final shellContext = tester.element(find.byType(DoseyShell));

    Navigator.of(shellContext).push<void>(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Nested'))),
    );
    await _pumpShellFrame(tester);
    expect(systemUi.states.last, isFalse);

    await tester.binding.handlePopRoute();
    await _pumpShellFrame(tester);
    expect(systemUi.states.last, isTrue);
  });

  testWidgets('external action return preserves its initiating destination', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await _setDeviceRole(database, AppDeviceRole.androidRobot);
    await _pumpShell(tester, _TestShellApp(database: database));
    await _openBottomDestination(tester, 'Settings');
    final dependencies = DoseyAppScope.of(
      tester.element(find.byType(DoseyShell)),
    );
    dependencies.externalActionResumeGuard.begin('settings');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpShellFrame(tester);

    expect(_appBarTitle('Settings'), findsOneWidget);
  });

  testWidgets('demo launch opens Controller before Robot Face', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await _pumpShell(
      tester,
      _TestShellApp(database: database, startOnController: true),
    );

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Carousel')),
      findsOneWidget,
    );
  });

  testWidgets('demo scenario clock drives Robot Face and Today', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory(isDemo: true);
    final clock = ControllableAppClock(DateTime.utc(2040, 1, 2, 8));
    addTearDown(database.close);
    addTearDown(clock.close);
    await DemoDataRepository(
      database,
      seedTime: clock.now(),
      deviceRole: AppDeviceRole.androidRobot,
    ).resetAndSeed();

    await _pumpShell(
      tester,
      _TestShellApp(
        database: database,
        appClock: clock,
        useRealMissedDoseReconciliation: true,
        startOnController: true,
      ),
    );

    expect(
      find.text('Fake medication and simulated controller'),
      findsOneWidget,
    );
    await tester.tap(find.text('Next step'));
    await _pumpShellFrame(tester);
    await tester.tap(find.text('Next step'));
    await _pumpShellFrame(tester);
    await tester.binding.handlePopRoute();
    await _pumpShellFrame(tester);
    expect(find.text('SOON'), findsOneWidget);

    await _openControllerHub(tester);
    await _pumpShellFrame(tester);
    await tester.tap(find.text('Next step'));
    await _pumpShellFrame(tester);
    await tester.binding.handlePopRoute();
    await _pumpShellFrame(tester);
    expect(find.text('READY'), findsOneWidget);

    await _openBottomDestination(tester, 'Dashboard');
    await tester.tap(find.text("Today's doses").hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Current dose'), findsOneWidget);
    expect(find.textContaining('FAKE Demo Tablets'), findsWidgets);
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
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Dashboard'),
      ),
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

    expect(
      tester
          .widget<RobotFaceScreen>(
            find.byType(RobotFaceScreen, skipOffstage: false),
          )
          .isActive,
      isTrue,
    );
    _expectRobotFaceVisible();

    await _openControllerHub(tester);

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

  testWidgets('Robot Mode returns to Robot Face after configured inactivity', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);
    await RobotFaceSettingsRepository(database).saveSettings(
      const RobotFaceSettings(returnToFaceAfterInactivityMinutes: 1),
    );

    await _pumpShell(tester, _TestShellApp(database: database));
    await _openControllerHub(tester);

    await tester.pump(const Duration(minutes: 1));
    await _pumpShellFrame(tester);

    _expectRobotFaceVisible();
  });

  testWidgets('guided trial stays on Controller after inactivity', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory(isDemo: true);
    final clock = ControllableAppClock(DateTime.utc(2040, 1, 2, 8));
    addTearDown(database.close);
    addTearDown(clock.close);
    await DemoDataRepository(
      database,
      seedTime: clock.now(),
      deviceRole: AppDeviceRole.androidRobot,
    ).resetAndSeed();
    await RobotFaceSettingsRepository(database).saveSettings(
      const RobotFaceSettings(returnToFaceAfterInactivityMinutes: 1),
    );

    await _pumpShell(
      tester,
      _TestShellApp(
        database: database,
        appClock: clock,
        startOnController: true,
      ),
    );
    await tester.pump(const Duration(minutes: 2));
    await _pumpShellFrame(tester);

    expect(_appBarTitle('Carousel'), findsOneWidget);
  });

  testWidgets('Robot Mode interaction restarts the inactivity timeout', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);
    await RobotFaceSettingsRepository(database).saveSettings(
      const RobotFaceSettings(returnToFaceAfterInactivityMinutes: 1),
    );

    await _pumpShell(tester, _TestShellApp(database: database));
    await _openControllerHub(tester);
    await tester.pump(const Duration(seconds: 30));

    await _openControllerHub(tester);
    await _pumpShellFrame(tester);
    await tester.pump(const Duration(seconds: 31));
    await _pumpShellFrame(tester);
    expect(_appBarTitle('Carousel'), findsOneWidget);

    await tester.pump(const Duration(seconds: 29));
    await _pumpShellFrame(tester);
    _expectRobotFaceVisible();
  });

  testWidgets('Personal Mode does not auto-return after inactivity', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidPersonal);
    await RobotFaceSettingsRepository(database).saveSettings(
      const RobotFaceSettings(returnToFaceAfterInactivityMinutes: 1),
    );

    await _pumpShell(tester, _TestShellApp(database: database));
    await _openControllerHub(tester);

    await tester.pump(const Duration(minutes: 2));
    await _pumpShellFrame(tester);

    expect(_appBarTitle('Carousel'), findsOneWidget);
  });

  testWidgets('Robot Mode does not dismiss a dialog when inactivity expires', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);
    await RobotFaceSettingsRepository(database).saveSettings(
      const RobotFaceSettings(returnToFaceAfterInactivityMinutes: 1),
    );

    await _pumpShell(tester, _TestShellApp(database: database));
    await _openControllerHub(tester);
    final shellContext = tester.element(find.byType(DoseyShell));
    showDialog<void>(
      context: shellContext,
      builder: (context) => AlertDialog(
        title: const Text('Mounted action'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    await _pumpShellFrame(tester);

    await tester.pump(const Duration(minutes: 1));
    await _pumpShellFrame(tester);
    expect(find.text('Mounted action'), findsOneWidget);
    expect(_appBarTitle('Carousel'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await _pumpShellFrame(tester);
    await tester.pump(const Duration(seconds: 1));
    await _pumpShellFrame(tester);
    _expectRobotFaceVisible();
  });

  testWidgets('Robot Mode Back returns another tab to Robot Face', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await _pumpShell(tester, _TestShellApp(database: database));
    await _openControllerHub(tester);

    await tester.binding.handlePopRoute();
    await _pumpShellFrame(tester);

    expect(find.byType(DoseyShell), findsOneWidget);
    _expectRobotFaceVisible();
  });

  testWidgets('Robot Mode Back is consumed on Robot Face', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await _pumpShell(tester, _TestShellApp(database: database));
    await tester.binding.handlePopRoute();
    await _pumpShellFrame(tester);

    expect(find.byType(DoseyShell), findsOneWidget);
    _expectRobotFaceVisible();
  });

  testWidgets('Personal Mode allows normal route popping', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidPersonal);

    await _pumpShell(tester, _TestShellApp(database: database));

    expect(
      find.byWidgetPredicate(
        (widget) => widget is PopScope<Object?> && widget.canPop,
      ),
      findsOneWidget,
    );
  });

  testWidgets('Robot Face awake window expires and restarts on resume', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final screenAwake = _FakeScreenAwakeGateway();
    addTearDown(database.close);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await _pumpShell(
      tester,
      _TestShellApp(database: database, screenAwakeGateway: screenAwake),
    );
    expect(screenAwake.states.last, isTrue);

    await tester.pump(const Duration(seconds: 60));
    await _pumpShellFrame(tester);
    expect(screenAwake.states.last, isFalse);

    await _openControllerHub(tester);
    expect(screenAwake.states.last, isFalse);

    await tester.binding.handlePopRoute();
    await _pumpShellFrame(tester);
    expect(screenAwake.states.last, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _pumpShellFrame(tester);
    expect(screenAwake.states.last, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpShellFrame(tester);
    expect(screenAwake.states.last, isTrue);

    await DoseyAppScope.of(
      tester.element(find.byType(DoseyShell)),
    ).settings.setDeviceRole(AppDeviceRole.androidPersonal);
    await _pumpShellFrame(tester);
    expect(screenAwake.states.last, isFalse);
  });

  testWidgets('PIR wake routes Robot Mode to face for configured duration', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final screenAwake = _FakeScreenAwakeGateway();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);
    await RobotFaceSettingsRepository(
      database,
    ).saveSettings(const RobotFaceSettings(pirWakeDurationSeconds: 30));

    await _pumpShell(
      tester,
      _TestShellApp(database: database, screenAwakeGateway: screenAwake),
    );
    await _openControllerHub(tester);
    final controller =
        DoseyAppScope.of(tester.element(find.byType(DoseyShell))).controller
            as SimulatedControllerGateway;

    controller.emitWakeFace();
    await _pumpShellFrame(tester);

    _expectRobotFaceVisible();
    expect(screenAwake.wakeCalls, 1);
    expect(screenAwake.states.last, isTrue);

    await tester.pump(const Duration(seconds: 30));
    await _pumpShellFrame(tester);
    expect(screenAwake.states.last, isFalse);
  });

  testWidgets('PIR wake is ignored while Robot Mode is paused', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final screenAwake = _FakeScreenAwakeGateway();
    addTearDown(database.close);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await _pumpShell(
      tester,
      _TestShellApp(database: database, screenAwakeGateway: screenAwake),
    );
    await _openControllerHub(tester);
    final controller =
        DoseyAppScope.of(tester.element(find.byType(DoseyShell))).controller
            as SimulatedControllerGateway;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _pumpShellFrame(tester);
    controller.emitWakeFace();
    await _pumpShellFrame(tester);

    expect(_appBarTitle('Carousel'), findsOneWidget);
    expect(screenAwake.wakeCalls, 0);
    expect(screenAwake.states.last, isFalse);
  });

  testWidgets('touch on Robot Face restarts the awake window', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final screenAwake = _FakeScreenAwakeGateway();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);
    await RobotFaceSettingsRepository(
      database,
    ).saveSettings(const RobotFaceSettings(pirWakeDurationSeconds: 30));

    await _pumpShell(
      tester,
      _TestShellApp(database: database, screenAwakeGateway: screenAwake),
    );
    await tester.pump(const Duration(seconds: 20));
    await tester.tap(find.byType(RobotFaceScreen));
    await _pumpShellFrame(tester);

    await tester.pump(const Duration(seconds: 11));
    await _pumpShellFrame(tester);
    expect(screenAwake.states.last, isTrue);

    await tester.pump(const Duration(seconds: 19));
    await _pumpShellFrame(tester);
    expect(screenAwake.states.last, isFalse);
  });

  testWidgets('scheduled-dose awake window outlives PIR window', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final screenAwake = _FakeScreenAwakeGateway();
    final now = DateTime.utc(2040, 1, 2, 10);
    final clock = ControllableAppClock(now);
    addTearDown(database.close);
    addTearDown(clock.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);
    await RobotFaceSettingsRepository(
      database,
    ).saveSettings(const RobotFaceSettings(pirWakeDurationSeconds: 30));
    await LocalScheduleProfileRepository(database).upsertProfile(
      ScheduleProfile(
        id: ScheduleProfile.defaultProfileId,
        name: 'Home',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await LocalReminderRepository(database).upsertSchedule(
      ReminderSchedule(
        id: 'due-dose',
        label: 'Morning dose',
        hour: now.hour,
        minute: now.minute,
        isEnabled: true,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await _pumpShell(
      tester,
      _TestShellApp(
        database: database,
        appClock: clock,
        screenAwakeGateway: screenAwake,
      ),
    );
    await tester.pump(const Duration(seconds: 30));
    await _pumpShellFrame(tester);

    expect(screenAwake.states.last, isTrue);
  });

  testWidgets('Personal Mode never requests the screen stay awake', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final screenAwake = _FakeScreenAwakeGateway();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidPersonal);

    await _pumpShell(
      tester,
      _TestShellApp(database: database, screenAwakeGateway: screenAwake),
    );
    await _openControllerHub(tester);

    expect(screenAwake.states, isNot(contains(true)));
  });

  testWidgets('disposing Robot Face releases the screen awake request', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final screenAwake = _FakeScreenAwakeGateway();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await _pumpShell(
      tester,
      _TestShellApp(database: database, screenAwakeGateway: screenAwake),
    );
    expect(screenAwake.states.last, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(screenAwake.states.last, isFalse);
  });

  testWidgets('screen awake failure does not crash Robot Mode', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final screenAwake = _FakeScreenAwakeGateway(throwOnSet: true);
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await _pumpShell(
      tester,
      _TestShellApp(database: database, screenAwakeGateway: screenAwake),
    );

    _expectRobotFaceVisible();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Robot Mode returns to Robot Face and reconciles on resume', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final reconciliation = FakeMissedDoseReconciliationService();
    addTearDown(database.close);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await _pumpShell(
      tester,
      _TestShellApp(
        database: database,
        missedDoseReconciliationService: reconciliation,
      ),
    );
    await _openControllerHub(tester);
    final baselineCalls = reconciliation.reconcileCalls;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpShellFrame(tester);

    _expectRobotFaceVisible();
    expect(reconciliation.reconcileCalls, baselineCalls + 1);
  });

  testWidgets('guided trial stays on Controller and reconciles on resume', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory(isDemo: true);
    final clock = ControllableAppClock(DateTime.utc(2040, 1, 2, 8));
    final reconciliation = FakeMissedDoseReconciliationService();
    addTearDown(database.close);
    addTearDown(clock.close);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await DemoDataRepository(
      database,
      seedTime: clock.now(),
      deviceRole: AppDeviceRole.androidRobot,
    ).resetAndSeed();

    await _pumpShell(
      tester,
      _TestShellApp(
        database: database,
        appClock: clock,
        missedDoseReconciliationService: reconciliation,
        startOnController: true,
      ),
    );
    final baselineCalls = reconciliation.reconcileCalls;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpShellFrame(tester);

    expect(_appBarTitle('Carousel'), findsOneWidget);
    expect(reconciliation.reconcileCalls, baselineCalls + 1);
  });

  testWidgets('Personal Mode keeps active tab and reconciles on resume', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final reconciliation = FakeMissedDoseReconciliationService();
    addTearDown(database.close);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await _setDeviceRole(database, AppDeviceRole.androidPersonal);

    await _pumpShell(
      tester,
      _TestShellApp(
        database: database,
        missedDoseReconciliationService: reconciliation,
      ),
    );
    await _openControllerHub(tester);
    final baselineCalls = reconciliation.reconcileCalls;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpShellFrame(tester);

    expect(_appBarTitle('Carousel'), findsOneWidget);
    expect(reconciliation.reconcileCalls, baselineCalls + 1);
  });

  testWidgets('dose notification routes by device role', (
    WidgetTester tester,
  ) async {
    for (final role in [
      AppDeviceRole.androidRobot,
      AppDeviceRole.androidPersonal,
    ]) {
      final database = DoseyDatabase.inMemory();
      final notificationTaps = ReminderNotificationTapController();
      await _setDeviceRole(database, role);

      await _pumpShell(
        tester,
        _TestShellApp(
          database: database,
          notificationTapController: notificationTaps,
        ),
      );
      await _openControllerHub(tester);

      notificationTaps.handleTap('dose-17');
      await _pumpShellFrame(tester);

      if (role.canHostRobot) {
        _expectRobotFaceVisible();
      } else {
        expect(_appBarTitle('Dashboard'), findsOneWidget);
      }

      notificationTaps.dispose();
      await database.close();
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('shortage notification opens Carousel in either role', (
    WidgetTester tester,
  ) async {
    for (final role in [
      AppDeviceRole.androidRobot,
      AppDeviceRole.androidPersonal,
    ]) {
      final database = DoseyDatabase.inMemory();
      final notificationTaps = ReminderNotificationTapController();
      await _setDeviceRole(database, role);

      await _pumpShell(
        tester,
        _TestShellApp(
          database: database,
          notificationTapController: notificationTaps,
        ),
      );
      notificationTaps.handleTap('shortage:shortage-1|slot:2');
      await _pumpShellFrame(tester);

      expect(_appBarTitle('Carousel'), findsOneWidget);

      notificationTaps.dispose();
      await database.close();
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('background shortage tap is not overwritten on resume', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final notificationTaps = ReminderNotificationTapController();
    addTearDown(database.close);
    addTearDown(notificationTaps.dispose);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await _setDeviceRole(database, AppDeviceRole.androidRobot);
    await _pumpShell(
      tester,
      _TestShellApp(
        database: database,
        notificationTapController: notificationTaps,
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    notificationTaps.handleTap('shortage:shortage-1|slot:2');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpShellFrame(tester);

    expect(_appBarTitle('Carousel'), findsOneWidget);
  });

  testWidgets('selected index stays safe when role changes', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await _pumpShell(tester, _TestShellApp(database: database));

    await _openBottomDestination(tester, 'Settings');

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

  testWidgets('Settings destination opens Robot Mode settings', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await _pumpShell(tester, _TestShellApp(database: database));

    await _openBottomDestination(tester, 'Settings');

    expect(find.text('Account'), findsNothing);
    expect(_appBarTitle('Settings'), findsOneWidget);
    expect(find.text('Profile, account & device'), findsOneWidget);
  });

  testWidgets('Personal Mode Settings retains Account', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidPersonal);

    await _pumpShell(tester, _TestShellApp(database: database));
    await _openBottomDestination(tester, 'Settings');

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Robot Face options'), findsNothing);
  });

  testWidgets('Settings deep link opens Help and About', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await _pumpShell(tester, _TestShellApp(database: database));

    await _openBottomDestination(tester, 'Settings');
    await _scrollSettingsUntilVisible(
      tester,
      find.text('Help, guided trial & setup'),
    );
    await tester.tap(find.text('Help, guided trial & setup'));
    await _pumpShellFrame(tester);
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

  testWidgets('Settings accordions open Household profile and History data', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await _pumpShell(tester, _TestShellApp(database: database));

    await _openBottomDestination(tester, 'Settings');
    await _scrollSettingsUntilVisible(
      tester,
      find.text('Household & robot profile'),
    );
    await tester.tap(find.text('Household & robot profile'));
    await _pumpShellFrame(tester);
    await _scrollSettingsUntilVisible(tester, find.text('Profile & device'));
    await tester.tap(find.text('Profile & device'));
    await tester.pumpAndSettle();
    expect(
      find.text('Edit household & robot profile').hitTestable(),
      findsOneWidget,
    );

    await _scrollSettingsUntilVisible(tester, find.text('History & data'));
    await tester.tap(find.text('History & data'));
    await _pumpShellFrame(tester);
    await _scrollSettingsUntilVisible(
      tester,
      find.text('No local admin changes recorded yet.'),
    );
    expect(
      find.text('No local admin changes recorded yet.').hitTestable(),
      findsOneWidget,
    );
  });
}

Future<void> _setDeviceRole(DoseyDatabase database, AppDeviceRole role) async {
  final settings = LocalAppSettingsRepository(
    database,
    defaultRole: AppDeviceRole.androidPersonal,
  );
  await settings.setDeviceRole(role);
}

Finder _appBarTitle(String title) {
  return find.descendant(of: find.byType(AppBar), matching: find.text(title));
}

void _expectRobotFaceVisible() {
  expect(
    find.byWidgetPredicate(
      (widget) => widget is RobotFaceScreen && widget.isActive,
      skipOffstage: false,
    ),
    findsOneWidget,
  );
  expect(find.byType(AppBar), findsNothing);
  expect(find.byType(NavigationBar), findsNothing);
}

Future<void> _openBottomDestination(WidgetTester tester, String label) async {
  if (find.byType(NavigationBar).evaluate().isEmpty &&
      find.byKey(RobotFaceScreen.displayFrameKey).evaluate().isNotEmpty) {
    await tester.longPress(find.byKey(RobotFaceScreen.displayFrameKey));
    await _pumpShellFrame(tester);
  }
  await openBottomDestination(
    tester,
    label,
    pumpFrame: () => _pumpShellFrame(tester),
  );
}

Future<void> _openControllerHub(WidgetTester tester) async {
  await _openBottomDestination(tester, 'Carousel');
  await tester.tap(find.text('Controller').hitTestable());
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
  const _TestShellApp({
    required this.database,
    this.notificationTapController,
    this.missedDoseReconciliationService,
    this.screenAwakeGateway,
    this.systemUiGateway,
    this.startOnController = false,
    this.appClock,
    this.useRealMissedDoseReconciliation = false,
    this.textScaler,
  });

  final DoseyDatabase database;
  final ReminderNotificationTapController? notificationTapController;
  final FakeMissedDoseReconciliationService? missedDoseReconciliationService;
  final ScreenAwakeGateway? screenAwakeGateway;
  final SystemUiGateway? systemUiGateway;
  final bool startOnController;
  final AppClock? appClock;
  final bool useRealMissedDoseReconciliation;
  final TextScaler? textScaler;

  @override
  Widget build(BuildContext context) {
    return DoseyAppScope(
      database: database,
      appClock: appClock,
      bleGateway: FakeBleGateway(),
      connectivityGateway: FakeConnectivityGateway(),
      permissionGateway: const _FakePermissionGateway(),
      reminderScheduler: const _NoopReminderScheduler(),
      notificationTapController: notificationTapController,
      missedDoseReconciliationService: useRealMissedDoseReconciliation
          ? null
          : missedDoseReconciliationService ??
                FakeMissedDoseReconciliationService(),
      screenAwakeGateway: screenAwakeGateway,
      systemUiGateway: systemUiGateway,
      child: MaterialApp(
        navigatorObservers: [doseyRouteObserver],
        builder: textScaler == null
            ? null
            : (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child!,
              ),
        home: DoseyShell(startOnController: startOnController),
      ),
    );
  }
}

class _FakeSystemUiGateway implements SystemUiGateway {
  final List<bool> states = <bool>[];

  @override
  Future<void> enterRobotFace() async => states.add(true);

  @override
  Future<void> restoreAppUi() async => states.add(false);
}

class _FakeScreenAwakeGateway implements ScreenAwakeGateway {
  _FakeScreenAwakeGateway({this.throwOnSet = false});

  final bool throwOnSet;
  final List<bool> states = <bool>[];
  int wakeCalls = 0;

  @override
  Future<void> wakeScreen() async {
    wakeCalls += 1;
  }

  @override
  Future<void> setKeepScreenAwake(bool enabled) async {
    states.add(enabled);
    if (throwOnSet) {
      throw StateError('Screen awake unavailable');
    }
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
