import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/notifications/reminder_notification_tap_controller.dart';
import 'package:dosey_app/core/display/screen_awake_gateway.dart';
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
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Controller'),
      ),
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

    expect(find.text('Next: Dose approaching'), findsOneWidget);
    await tester.tap(find.text('Next step'));
    await _pumpShellFrame(tester);
    await tester.tap(
      find
          .descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Robot Face'),
          )
          .hitTestable(),
    );
    await _pumpShellFrame(tester);
    expect(find.text('SOON'), findsOneWidget);

    await tester.tap(
      find
          .descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Controller'),
          )
          .hitTestable(),
    );
    await _pumpShellFrame(tester);
    await tester.tap(find.text('Next step'));
    await _pumpShellFrame(tester);
    await tester.tap(
      find
          .descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Robot Face'),
          )
          .hitTestable(),
    );
    await _pumpShellFrame(tester);
    expect(find.text('READY'), findsOneWidget);

    await tester.tap(
      find
          .descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Today'),
          )
          .hitTestable(),
    );
    await _pumpShellFrame(tester);
    expect(find.text('Current dose'), findsOneWidget);
    expect(find.textContaining('FAKE Demo Tablets'), findsWidgets);
  });

  testWidgets(
    'demo presentation runs from Robot Face and returns to Controller',
    (WidgetTester tester) async {
      final database = DoseyDatabase.inMemory(isDemo: true);
      final clock = ControllableAppClock(DateTime.utc(2040, 1, 2, 8));
      final screenAwake = _FakeScreenAwakeGateway();
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
          screenAwakeGateway: screenAwake,
        ),
      );

      await tester.tap(find.text('Start presentation'));
      await _pumpShellFrame(tester);

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(screenAwake.states.last, isTrue);
      expect(find.text('Next demo step'), findsOneWidget);
      expect(find.text('Play demo'), findsOneWidget);
      expect(find.text('Restart demo'), findsOneWidget);
      expect(find.text('Return to Controller'), findsOneWidget);
      for (final label in <String>[
        'Next demo step',
        'Play demo',
        'Restart demo',
        'Return to Controller',
      ]) {
        expect(tester.getSize(find.text(label).first).height, lessThan(48));
        expect(
          tester
              .getSize(
                find
                    .ancestor(
                      of: find.text(label).first,
                      matching: find.byWidgetPredicate(
                        (widget) => widget is ButtonStyleButton,
                      ),
                    )
                    .first,
              )
              .height,
          greaterThanOrEqualTo(48),
        );
      }

      await tester.tap(find.text('Play demo'));
      await _pumpShellFrame(tester);
      expect(find.text('Pause demo'), findsOneWidget);
      await tester.tap(find.text('Pause demo'));
      await _pumpShellFrame(tester);
      expect(find.text('Play demo'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.text('Restart demo'));
      await _pumpShellFrame(tester);

      await tester.tap(find.text('Next demo step'));
      await _pumpShellFrame(tester);
      expect(find.text('SOON'), findsOneWidget);

      await tester.tap(find.text('Restart demo'));
      await _pumpShellFrame(tester);
      expect(find.text('SOON'), findsNothing);

      await tester.tap(find.text('Return to Controller'));
      await _pumpShellFrame(tester);
      expect(_appBarTitle('Controller'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Start presentation'), findsOneWidget);
      expect(screenAwake.states.last, isFalse);
    },
  );

  testWidgets('demo presentation reports control failures', (
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
    await tester.tap(find.text('Start presentation'));
    await _pumpShellFrame(tester);

    final scenarios = DoseyAppScope.of(
      tester.element(find.text('Restart demo')),
    ).demoScenarios!;
    await scenarios.close();
    await database.close();
    await tester.tap(find.text('Restart demo'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Demo action failed:'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
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
    await tester.tap(
      find
          .descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Controller'),
          )
          .hitTestable(),
    );
    await _pumpShellFrame(tester);

    await tester.pump(const Duration(minutes: 1));
    await _pumpShellFrame(tester);

    expect(_appBarTitle('Robot Face'), findsOneWidget);
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
    await tester.tap(
      find
          .descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Controller'),
          )
          .hitTestable(),
    );
    await _pumpShellFrame(tester);
    await tester.pump(const Duration(seconds: 30));

    await tester.tap(
      find
          .descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Controller'),
          )
          .hitTestable(),
    );
    await _pumpShellFrame(tester);
    await tester.pump(const Duration(seconds: 31));
    await _pumpShellFrame(tester);
    expect(_appBarTitle('Controller'), findsOneWidget);

    await tester.pump(const Duration(seconds: 29));
    await _pumpShellFrame(tester);
    expect(_appBarTitle('Robot Face'), findsOneWidget);
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
    await tester.tap(find.text('Controller').hitTestable());
    await _pumpShellFrame(tester);

    await tester.pump(const Duration(minutes: 2));
    await _pumpShellFrame(tester);

    expect(_appBarTitle('Controller'), findsOneWidget);
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
    await tester.tap(find.text('Controller').hitTestable());
    await _pumpShellFrame(tester);
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
    expect(_appBarTitle('Controller'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await _pumpShellFrame(tester);
    await tester.pump(const Duration(seconds: 1));
    await _pumpShellFrame(tester);
    expect(_appBarTitle('Robot Face'), findsOneWidget);
  });

  testWidgets('Robot Mode Back returns another tab to Robot Face', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await _pumpShell(tester, _TestShellApp(database: database));
    await tester.tap(find.text('Controller').hitTestable());
    await _pumpShellFrame(tester);

    await tester.binding.handlePopRoute();
    await _pumpShellFrame(tester);

    expect(find.byType(DoseyShell), findsOneWidget);
    expect(_appBarTitle('Robot Face'), findsOneWidget);
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
    expect(_appBarTitle('Robot Face'), findsOneWidget);
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

    await tester.tap(find.text('Controller').hitTestable());
    await _pumpShellFrame(tester);
    expect(screenAwake.states.last, isFalse);

    await tester.tap(find.text('Robot Face').hitTestable());
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
    await tester.tap(find.text('Controller').hitTestable());
    await _pumpShellFrame(tester);
    final controller =
        DoseyAppScope.of(tester.element(find.byType(DoseyShell))).controller
            as SimulatedControllerGateway;

    controller.emitWakeFace();
    await _pumpShellFrame(tester);

    expect(_appBarTitle('Robot Face'), findsOneWidget);
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
    await tester.tap(find.text('Controller').hitTestable());
    await _pumpShellFrame(tester);
    final controller =
        DoseyAppScope.of(tester.element(find.byType(DoseyShell))).controller
            as SimulatedControllerGateway;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _pumpShellFrame(tester);
    controller.emitWakeFace();
    await _pumpShellFrame(tester);

    expect(_appBarTitle('Controller'), findsOneWidget);
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
    await tester.tap(find.text('Controller').hitTestable());
    await _pumpShellFrame(tester);

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

    expect(_appBarTitle('Robot Face'), findsOneWidget);
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
    await tester.tap(find.text('Controller').hitTestable());
    await _pumpShellFrame(tester);
    final baselineCalls = reconciliation.reconcileCalls;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpShellFrame(tester);

    expect(_appBarTitle('Robot Face'), findsOneWidget);
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
    await tester.tap(find.text('Controller').hitTestable());
    await _pumpShellFrame(tester);
    final baselineCalls = reconciliation.reconcileCalls;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpShellFrame(tester);

    expect(_appBarTitle('Controller'), findsOneWidget);
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
      await tester.tap(find.text('Controller').hitTestable());
      await _pumpShellFrame(tester);

      notificationTaps.handleTap('dose-17');
      await _pumpShellFrame(tester);

      expect(
        _appBarTitle(
          role == AppDeviceRole.androidRobot ? 'Robot Face' : 'Today',
        ),
        findsOneWidget,
      );

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

    expect(find.text('Account'), findsNothing);
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

  testWidgets('Personal Mode settings menu retains Account', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidPersonal);

    await _pumpShell(tester, _TestShellApp(database: database));
    await _openSettingsMenu(tester);

    expect(find.text('Account'), findsOneWidget);
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

Finder _appBarTitle(String title) {
  return find.descendant(of: find.byType(AppBar), matching: find.text(title));
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
  const _TestShellApp({
    required this.database,
    this.notificationTapController,
    this.missedDoseReconciliationService,
    this.screenAwakeGateway,
    this.startOnController = false,
    this.appClock,
    this.useRealMissedDoseReconciliation = false,
  });

  final DoseyDatabase database;
  final ReminderNotificationTapController? notificationTapController;
  final FakeMissedDoseReconciliationService? missedDoseReconciliationService;
  final ScreenAwakeGateway? screenAwakeGateway;
  final bool startOnController;
  final AppClock? appClock;
  final bool useRealMissedDoseReconciliation;

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
      child: MaterialApp(
        home: DoseyShell(startOnController: startOnController),
      ),
    );
  }
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
