import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/build/app_build_profile.dart';
import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/controller/controller_health_supervisor.dart';
import 'package:dosey_app/core/controller/local_controller_health_event_repository.dart';
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
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/time/app_clock.dart';
import 'package:dosey_app/features/robot_face/robot_face_screen.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings_repository.dart';
import 'package:dosey_app/features/carousel/carousel_screen.dart';
import 'package:dosey_app/features/controller/controller_screen.dart';
import 'package:dosey_app/features/prescriptions/prescriptions_screen.dart';
import 'package:dosey_app/features/reminders/reminders_screen.dart';
import 'package:dosey_app/features/shell/dosey_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_scope_dependencies.dart';
import '../../support/bottom_navigation_test_helper.dart';

void main() {
  for (final role in AppDeviceRole.values) {
    testWidgets('${role.name} exposes the three primary destinations', (
      tester,
    ) async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _setDeviceRole(database, role);

      await _pumpShell(
        tester,
        _TestShellApp(
          database: database,
          buildProfile: role.canHostRobot
              ? AppBuildProfile.robot
              : AppBuildProfile.personal,
        ),
      );

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
        ['Today', 'Medications', 'Settings'],
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
              buildProfile: AppBuildProfile.personal,
              textScaler: TextScaler.linear(scale),
            ),
          );

          final navigationBar = tester.widget<NavigationBar>(
            find.byType(NavigationBar),
          );
          expect(
            navigationBar.labelBehavior,
            NavigationDestinationLabelBehavior.alwaysShow,
          );
          for (final label in ['Today', 'Medications', 'Settings']) {
            expect(find.byTooltip(label), findsWidgets);
          }
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets('Personal Mode keeps medication tasks behind clear actions', (
    tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidPersonal);
    await _pumpShell(
      tester,
      _TestShellApp(database: database, buildProfile: AppBuildProfile.personal),
    );

    await _openBottomDestination(tester, 'Medications');
    expect(find.text('Your medications'), findsOneWidget);
    expect(find.text('Schedules'), findsOneWidget);
    expect(find.text('Prescriptions'), findsOneWidget);
    expect(find.text('Manage carousel'), findsOneWidget);

    await tester.ensureVisible(find.text('Schedules'));
    await tester.tap(find.text('Schedules'));
    await _pumpShellFrame(tester);
    expect(find.byType(RemindersScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Prescriptions'));
    await tester.tap(find.text('Prescriptions'));
    await _pumpShellFrame(tester);
    expect(find.byType(PrescriptionsScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Manage carousel'));
    await tester.tap(find.text('Manage carousel'));
    await _pumpShellFrame(tester);
    expect(_appBarTitle('Carousel'), findsOneWidget);
    expect(find.byType(CarouselScreen), findsOneWidget);
    _expectSelectedNavigationDestination(tester, 'Medications');
    expect(find.text('Controller'), findsNothing);
  });

  testWidgets('Today carousel review opens the carousel workflow', (
    tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final now = DateTime.utc(2040, 1, 2, 9);
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidPersonal);
    await LocalScheduleProfileRepository(database).upsertProfile(
      ScheduleProfile(
        id: ScheduleProfile.defaultProfileId,
        name: 'Home',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await LocalPrescriptionRepository(database).upsertPrescription(
      Prescription(
        id: 'medicine-1',
        name: 'Morning medicine',
        pillType: PillType.tablet,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await LocalReminderRepository(database).upsertSchedule(
      ReminderSchedule(
        id: 'schedule-1',
        prescriptionId: 'medicine-1',
        profileId: ScheduleProfile.defaultProfileId,
        label: 'Morning medicine',
        hour: 10,
        minute: 0,
        isEnabled: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final slots = LocalCarouselSlotRepository(database);
    await slots.assignSlot(
      CarouselSlot(
        id: 'slot-1',
        slotNumber: 1,
        prescriptionId: 'medicine-1',
        scheduleId: 'schedule-1',
        profileId: ScheduleProfile.defaultProfileId,
        status: CarouselSlotStatus.assigned,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await slots.markNeedsReview('slot-1');

    await _pumpShell(
      tester,
      _TestShellApp(database: database, buildProfile: AppBuildProfile.personal),
    );

    expect(find.text('Review carousel'), findsOneWidget);
    await tester.ensureVisible(find.text('Review carousel'));
    await tester.tap(find.text('Review carousel'));
    await _pumpShellFrame(tester);
    expect(_appBarTitle('Carousel'), findsOneWidget);
    expect(find.byType(CarouselScreen), findsOneWidget);
    _expectSelectedNavigationDestination(tester, 'Medications');
  });

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

  testWidgets('Robot Mode opens Today in portrait', (
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
      find.descendant(of: find.byType(AppBar), matching: find.text('Today')),
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

    expect(_appBarTitle('Today'), findsOneWidget);
  });

  testWidgets('Robot Mode resume stays on Today in portrait', (
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

    expect(_appBarTitle('Today'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('Face requests full screen and Today restores app UI', (
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

  testWidgets('portrait to landscape reopens Face only from Today', (
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
    expect(_appBarTitle('Today'), findsOneWidget);
    await _pumpShellFrame(tester);
    expect(_appBarTitle('Today'), findsOneWidget);

    await _openBottomDestination(tester, 'Medications');
    tester.view.physicalSize = const Size(600, 900);
    await _pumpShellFrame(tester);
    tester.view.physicalSize = const Size(900, 600);
    await _pumpShellFrame(tester);
    expect(_appBarTitle('Medications'), findsOneWidget);
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
    _expectSelectedNavigationDestination(tester, 'Medications');
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

  testWidgets(
    'production Robot launch does not construct Controller before Maintenance authorization',
    (WidgetTester tester) async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _setDeviceRole(database, AppDeviceRole.androidRobot);

      await _pumpShell(
        tester,
        _TestShellApp(database: database, startOnController: true),
      );

      expect(find.byType(ControllerScreen, skipOffstage: false), findsNothing);
      _expectRobotFaceVisible();
    },
  );

  testWidgets(
    'Robot device attention requires one PIN-authorized Maintenance entry',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _setDeviceRole(database, AppDeviceRole.androidRobot);
      await _seedDeviceAttention(database);
      await LocalAppSettingsRepository(
        database,
        defaultRole: AppDeviceRole.androidRobot,
      ).setActionPin('1234');
      final app = _TestShellApp(database: database);

      await _pumpShell(tester, app);
      await tester.tap(find.text('Review device'));
      await _pumpShellFrame(tester);

      _expectSelectedNavigationDestination(tester, 'Settings');
      expect(find.text('Enter Action PIN'), findsOneWidget);
      expect(find.byType(ControllerScreen, skipOffstage: false), findsNothing);
      expect(find.text('Hardware bench'), findsNothing);
      expect(find.text('For setup and repairs'), findsNothing);

      await tester.enterText(find.byKey(const Key('action-pin-field')), '1234');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('For setup and repairs'), findsOneWidget);
      expect(
        find.byType(ControllerScreen, skipOffstage: false),
        findsOneWidget,
      );
      final auditRows = await database.select(database.adminAuditEvents).get();
      expect(auditRows, hasLength(1));
      expect(
        auditRows.single.eventType,
        AdminAuditEventType.maintenanceEntered.name,
      );
      expect(
        auditRows.single.targetType,
        AdminAuditTargetType.maintenance.name,
      );
      expect(
        auditRows.single.sourceDeviceRole,
        AppDeviceRole.androidRobot.storageValue,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      final dependencies = DoseyAppScope.of(
        tester.element(find.byType(DoseyShell)),
      );
      dependencies.externalActionResumeGuard.begin('settings');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _pumpShellFrame(tester);

      expect(find.text('Enter Action PIN'), findsNothing);
      expect(find.text('For setup and repairs'), findsNothing);
      expect(
        await database.select(database.adminAuditEvents).get(),
        hasLength(1),
      );
    },
  );

  testWidgets('Personal device attention opens ordinary Settings only', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidPersonal);
    await _seedDeviceAttention(database);

    await _pumpShell(
      tester,
      _TestShellApp(database: database, buildProfile: AppBuildProfile.personal),
    );
    await tester.tap(find.text('Review device'));
    await _pumpShellFrame(tester);

    _expectSelectedNavigationDestination(tester, 'Settings');
    expect(find.text('Enter Action PIN'), findsNothing);
    expect(find.text('For setup and repairs'), findsNothing);
    expect(find.text('Hardware bench'), findsNothing);
    expect(find.byType(ControllerScreen), findsNothing);
    expect(find.byType(ControllerScreen, skipOffstage: false), findsNothing);
    expect(
      (await database.select(database.adminAuditEvents).get()).where(
        (event) =>
            event.eventType == AdminAuditEventType.maintenanceEntered.name,
      ),
      isEmpty,
    );
  });

  testWidgets(
    'demo launch opens the hidden Guided trial route before Robot Face',
    (WidgetTester tester) async {
      final database = DoseyDatabase.inMemory(isDemo: true);
      addTearDown(database.close);
      await _setDeviceRole(database, AppDeviceRole.androidRobot);

      await _pumpShell(
        tester,
        _TestShellApp(database: database, startOnController: true),
      );

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Guided trial'),
        ),
        findsOneWidget,
      );
      expect(
        find.byType(ControllerScreen, skipOffstage: false),
        findsOneWidget,
      );
      _expectSelectedNavigationDestination(tester, 'Settings');

      await _openBottomDestination(tester, 'Settings');

      expect(_appBarTitle('Settings'), findsOneWidget);
      _expectSelectedNavigationDestination(tester, 'Settings');
    },
  );

  testWidgets(
    'Personal demo startOnController falls back to Carousel without Guided trial',
    (WidgetTester tester) async {
      final database = DoseyDatabase.inMemory(isDemo: true);
      addTearDown(database.close);
      await _setDeviceRole(database, AppDeviceRole.androidPersonal);

      await _pumpShell(
        tester,
        _TestShellApp(
          database: database,
          buildProfile: AppBuildProfile.personal,
          startOnController: true,
        ),
      );

      expect(_appBarTitle('Carousel'), findsOneWidget);
      expect(find.byType(ControllerScreen), findsNothing);
      expect(find.byType(ControllerScreen, skipOffstage: false), findsNothing);
      expect(find.text('Guided trial'), findsNothing);
      _expectSelectedNavigationDestination(tester, 'Medications');
    },
  );

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

    await _openBottomDestination(tester, 'Today');
    expect(find.text('Current dose'), findsOneWidget);
    expect(find.textContaining('FAKE Demo Tablets'), findsWidgets);
  });

  testWidgets('Personal Mode does not show the Robot Face tab', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidPersonal);

    await _pumpShell(
      tester,
      _TestShellApp(database: database, buildProfile: AppBuildProfile.personal),
    );

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

    expect(
      tester
          .widget<RobotFaceScreen>(
            find.byType(RobotFaceScreen, skipOffstage: false),
          )
          .isActive,
      isTrue,
    );
    _expectRobotFaceVisible();

    await _openCarouselFromShortage(tester);

    expect(find.byType(RobotFaceScreen, skipOffstage: false), findsOneWidget);
    expect(
      tester
          .widget<RobotFaceScreen>(
            find.byType(RobotFaceScreen, skipOffstage: false),
          )
          .isActive,
      isFalse,
    );
    expect(_appBarTitle('Carousel'), findsOneWidget);
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
    await _openCarouselFromShortage(tester);

    await tester.pump(const Duration(minutes: 1));
    await _pumpShellFrame(tester);

    _expectRobotFaceVisible();
  });

  testWidgets('guided trial stays on its hidden route after inactivity', (
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

    expect(_appBarTitle('Guided trial'), findsOneWidget);
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
    await _openCarouselFromShortage(tester);
    await tester.pump(const Duration(seconds: 30));

    await _openCarouselFromShortage(tester);
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

    await _pumpShell(
      tester,
      _TestShellApp(database: database, buildProfile: AppBuildProfile.personal),
    );
    await _openCarouselFromShortage(tester);

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
    await _openCarouselFromShortage(tester);
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
    await _openCarouselFromShortage(tester);

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

    await _pumpShell(
      tester,
      _TestShellApp(database: database, buildProfile: AppBuildProfile.personal),
    );

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

    await _openCarouselFromShortage(tester);
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
    expect(screenAwake.states.last, isTrue);
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
    await _openCarouselFromShortage(tester);
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
    await _openCarouselFromShortage(tester);
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
      _TestShellApp(
        database: database,
        buildProfile: AppBuildProfile.personal,
        screenAwakeGateway: screenAwake,
      ),
    );
    await _openCarouselFromShortage(tester);

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
    await _openCarouselFromShortage(tester);
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

    expect(_appBarTitle('Guided trial'), findsOneWidget);
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
        buildProfile: AppBuildProfile.personal,
        missedDoseReconciliationService: reconciliation,
      ),
    );
    await _openCarouselFromShortage(tester);
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
          buildProfile: role.canHostRobot
              ? AppBuildProfile.robot
              : AppBuildProfile.personal,
          notificationTapController: notificationTaps,
        ),
      );
      await _openCarouselFromShortage(tester);

      notificationTaps.handleTap('dose-17');
      await _pumpShellFrame(tester);

      if (role.canHostRobot) {
        _expectRobotFaceVisible();
      } else {
        expect(_appBarTitle('Today'), findsOneWidget);
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
          buildProfile: role.canHostRobot
              ? AppBuildProfile.robot
              : AppBuildProfile.personal,
          notificationTapController: notificationTaps,
        ),
      );
      notificationTaps.handleTap('shortage:shortage-1|slot:2');
      await _pumpShellFrame(tester);

      expect(_appBarTitle('Carousel'), findsOneWidget);
      _expectSelectedNavigationDestination(tester, 'Medications');

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

  testWidgets('persisted role changes do not change fixed Robot navigation', (
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
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is NavigationDestination && widget.label == 'Robot Face',
      ),
      findsNothing,
    );
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
    expect(find.text('Device & connection'), findsOneWidget);
  });

  testWidgets('Personal Mode Settings retains Account', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidPersonal);

    await _pumpShell(
      tester,
      _TestShellApp(database: database, buildProfile: AppBuildProfile.personal),
    );
    await _openBottomDestination(tester, 'Settings');

    expect(find.text('Account & household'), findsOneWidget);
    expect(find.text('Robot Face'), findsNothing);
  });

  testWidgets('Settings deep link opens Help and About', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await _pumpShell(tester, _TestShellApp(database: database));

    await _openBottomDestination(tester, 'Settings');
    await _scrollSettingsUntilVisible(tester, find.text('Help & safety'));
    await tester.tap(find.text('Help & safety'));
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

  testWidgets('Settings opens Household profile without technical records', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await _pumpShell(tester, _TestShellApp(database: database));

    await _openBottomDestination(tester, 'Settings');
    await _scrollSettingsUntilVisible(tester, find.text('Device & connection'));
    await tester.tap(find.text('Device & connection'));
    await _pumpShellFrame(tester);
    await _scrollSettingsUntilVisible(tester, find.text('Profile & device'));
    await tester.tap(find.text('Profile & device'));
    await tester.pumpAndSettle();
    expect(
      find.text('Edit household & robot profile').hitTestable(),
      findsOneWidget,
    );

    expect(find.text('Admin history'), findsNothing);
    expect(find.text('Backup and database'), findsNothing);
  });
}

Future<void> _setDeviceRole(DoseyDatabase database, AppDeviceRole role) async {
  final settings = LocalAppSettingsRepository(
    database,
    defaultRole: AppDeviceRole.androidPersonal,
  );
  await settings.setDeviceRole(role);
}

Future<void> _seedDeviceAttention(DoseyDatabase database) {
  return LocalControllerHealthEventRepository(
    database,
    idGenerator: (_, _) => 'device-attention',
  ).recordControllerHealthEvent(
    ControllerHealthEventType.offline,
    occurredAt: DateTime.utc(2040, 1, 2, 9),
    details: 'test device attention',
  );
}

Finder _appBarTitle(String title) {
  return find.descendant(of: find.byType(AppBar), matching: find.text(title));
}

void _expectSelectedNavigationDestination(WidgetTester tester, String label) {
  final navigationBar = tester.widget<NavigationBar>(
    find.byType(NavigationBar),
  );
  final selectedDestination = navigationBar.destinations
      .cast<NavigationDestination>()
      .elementAt(navigationBar.selectedIndex);
  expect(selectedDestination.label, label);
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

Future<void> _openCarouselFromShortage(WidgetTester tester) async {
  final shellContext = tester.element(find.byType(DoseyShell));
  DoseyAppScope.of(
    shellContext,
  ).notificationTaps.handleTap('shortage:test-shortage|slot:1');
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
    this.buildProfile = AppBuildProfile.robot,
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
  final AppBuildProfile buildProfile;

  @override
  Widget build(BuildContext context) {
    return DoseyAppScope(
      database: database,
      buildProfile: buildProfile,
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
