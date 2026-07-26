import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/demo/demo_data_repository.dart';
import 'package:dosey_app/core/demo/demo_mode_host.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/controller/local_controller_command_repository.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/time/app_clock.dart';
import 'package:dosey_app/features/controller/controller_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_scope_dependencies.dart';

void main() {
  testWidgets('shows an empty lifecycle status before any controller command', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await tester.pumpWidget(_TestControllerApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('Controller command status'), findsOneWidget);
    expect(find.text('No controller command yet.'), findsOneWidget);
    expect(
      find.text('Movement stays separate from dose taken confirmation.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Hardware diagnostics'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Hardware diagnostics'), findsOneWidget);
    expect(find.textContaining('Read-only snapshot'), findsOneWidget);
  });

  testWidgets('shows verified health and reconnect details separately', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);
    final controller = _SnapshotControllerGateway(
      ControllerSnapshot(
        connectionState: ControllerConnectionState.disconnected,
        canRequestDispense: false,
        statusLabel: 'Controller offline. Reconnect scheduled.',
        healthState: ControllerHealthState.reconnecting,
        lastSuccessfulHeartbeatAt: DateTime.utc(2026, 7, 24, 12, 34),
        reconnectAttempt: 2,
        nextReconnectAt: DateTime.utc(2026, 7, 24, 12, 35),
      ),
    );
    addTearDown(controller.close);

    await tester.pumpWidget(
      _TestControllerApp(database: database, controller: controller),
    );
    await tester.pumpAndSettle();

    expect(find.text('Health: Reconnecting'), findsOneWidget);
    expect(find.text('Transport disconnected'), findsOneWidget);
    expect(find.text('Last heartbeat: 2026-07-24 12:34 UTC'), findsOneWidget);
    expect(find.text('Reconnect attempt 2'), findsOneWidget);
    expect(find.text('Next retry: 2026-07-24 12:35 UTC'), findsOneWidget);
  });

  testWidgets('bench movement waits for verified controller health', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);
    final controller = _SnapshotControllerGateway(
      const ControllerSnapshot.connected(),
    );
    addTearDown(controller.close);

    await tester.pumpWidget(
      _TestControllerApp(database: database, controller: controller),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Bench commands'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'STATUS'))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'HEARTBEAT'),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'SERVO_TEST'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'DISPENSE_TEST'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Read-only commands'), findsOneWidget);
    expect(find.text('Supervised state changes and outputs'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'DEBUG_ON'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'LED_TEST'),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.text(
        'Locked until Android robot mode is active and controller health is verified.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows timed out controller work as needs review', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);
    final repository = LocalControllerCommandRepository(database);
    final createdAt = DateTime.utc(2026, 7, 10, 12);
    final acceptedAt = createdAt.add(const Duration(seconds: 5));
    final timedOutAt = createdAt.add(const Duration(minutes: 2));

    final session = await repository.createSession(
      commandType: ControllerCommandType.dispenseTest,
      doseId: 'manual-test',
      now: createdAt,
    );
    await repository.updateSessionState(
      session.id,
      ControllerCommandSessionState.accepted,
      acceptedAt: acceptedAt,
      updatedAt: acceptedAt,
    );
    await repository.updateSessionState(
      session.id,
      ControllerCommandSessionState.timedOut,
      acceptedAt: acceptedAt,
      updatedAt: timedOutAt,
    );

    await tester.pumpWidget(_TestControllerApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('Needs review'), findsOneWidget);
    expect(
      find.text('The last controller command timed out after acceptance.'),
      findsOneWidget,
    );
    expect(
      find.text('Check the dispenser before trying again.'),
      findsOneWidget,
    );
  });

  testWidgets('manual dispense requires action PIN when enabled', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);
    await LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    ).setActionPin('1234');
    final repository = LocalControllerCommandRepository(database);

    await tester.pumpWidget(_TestControllerApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect controller'));
    await tester.pumpAndSettle();

    final dispenseButton = find.text('Run dispense test');
    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pump();
    await tester.tap(dispenseButton);
    await tester.pumpAndSettle();

    expect(find.text('Enter Action PIN'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await repository.getLatestRelevantSession(), isNull);

    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pump();
    await tester.tap(dispenseButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('action-pin-field')), '1234');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final session = await repository.getLatestRelevantSession();
    expect(session, isNotNull);
    expect(session!.commandType, ControllerCommandType.dispenseTest);
  });

  testWidgets('bench LED test requires action PIN when enabled', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);
    await LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    ).setActionPin('1234');
    final repository = LocalControllerCommandRepository(database);

    await tester.pumpWidget(_TestControllerApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect controller'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, 'LED_TEST'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'LED_TEST'));
    await tester.pumpAndSettle();

    expect(find.text('Enter Action PIN'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('action-pin-field')), '1234');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final session = await repository.getLatestRelevantSession();
    expect(session, isNotNull);
    expect(session!.commandType, ControllerCommandType.ledTest);
  });

  testWidgets('bench debug toggle requires action PIN when enabled', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);
    await LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    ).setActionPin('1234');
    final repository = LocalControllerCommandRepository(database);

    await tester.pumpWidget(_TestControllerApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect controller'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, 'DEBUG_ON'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'DEBUG_ON'));
    await tester.pumpAndSettle();

    expect(find.text('Enter Action PIN'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('action-pin-field')), '1234');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final session = await repository.getLatestRelevantSession();
    expect(session, isNotNull);
    expect(session!.commandType, ControllerCommandType.debugOn);
  });

  testWidgets('enters and exits isolated guided trial from Controller', (
    WidgetTester tester,
  ) async {
    final production = DoseyDatabase.inMemory();
    final demo = DoseyDatabase.inMemory(isDemo: true);
    final productionClock = ControllableAppClock(DateTime.utc(2039));
    addTearDown(() async {
      await productionClock.close();
      await production.close();
      await demo.close();
    });

    await tester.pumpWidget(
      _TestControllerHost(
        production: production,
        demo: demo,
        productionClock: productionClock,
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Start guided trial'), findsOneWidget);
    await tester.tap(find.text('Start guided trial'));
    await tester.pumpAndSettle();

    expect(find.text('GUIDED TRIAL - FAKE DATA'), findsOneWidget);
    expect(find.text('Guided Trial Run'), findsOneWidget);
    expect(find.text('Exit trial'), findsOneWidget);
    expect(find.text('Bench commands'), findsNothing);
    expect(find.text('Manual dispense test'), findsNothing);

    await tester.tap(find.text('Exit trial'));
    await tester.pumpAndSettle();

    expect(find.text('GUIDED TRIAL - FAKE DATA'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Start guided trial'), findsOneWidget);
  });

  testWidgets('guided trial advances without exposing developer controls', (
    WidgetTester tester,
  ) async {
    final production = DoseyDatabase.inMemory();
    final demo = DoseyDatabase.inMemory(isDemo: true);
    final productionClock = ControllableAppClock(DateTime.utc(2039));
    addTearDown(() async {
      await productionClock.close();
      await production.close();
      await demo.close();
    });

    await tester.pumpWidget(
      _TestControllerHost(
        production: production,
        demo: demo,
        productionClock: productionClock,
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start guided trial'));
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 16'), findsOneWidget);
    await tester.tap(find.text('Next step'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 16'), findsOneWidget);
    expect(find.text('Demo scenario runner'), findsNothing);
    expect(find.text('Auto-play'), findsNothing);
    expect(find.text('Start presentation'), findsNothing);
    expect(find.text('Bench commands'), findsNothing);
  });

  testWidgets('iOS demo does not offer Robot Face presentation', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final database = DoseyDatabase.inMemory(isDemo: true);
      addTearDown(database.close);
      await DemoDataRepository(
        database,
        seedTime: DateTime.utc(2040, 1, 2, 8),
        deviceRole: AppDeviceRole.iosPersonal,
      ).resetAndSeed();

      await tester.pumpWidget(_TestControllerApp(database: database));
      await tester.pumpAndSettle();

      expect(find.text('Guided Trial Run'), findsOneWidget);
      expect(find.text('Start presentation'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Future<void> _setDeviceRole(DoseyDatabase database, AppDeviceRole role) async {
  final settings = LocalAppSettingsRepository(
    database,
    defaultRole: AppDeviceRole.androidPersonal,
  );
  await settings.setDeviceRole(role);
}

class _TestControllerApp extends StatelessWidget {
  const _TestControllerApp({required this.database, this.controller});

  final DoseyDatabase database;
  final StagedControllerGateway? controller;

  @override
  Widget build(BuildContext context) {
    return DoseyAppScope(
      database: database,
      controllerGateway: controller,
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
        home: const Scaffold(body: ControllerScreen()),
      ),
    );
  }
}

class _SnapshotControllerGateway
    implements StagedControllerGateway, ControllerBenchGateway {
  _SnapshotControllerGateway(this.snapshot);

  final ControllerSnapshot snapshot;

  @override
  Future<void> cancelActiveCommand() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> requestDispense({required String doseId}) async {}

  @override
  Future<void> requestStagedDispense({
    required String doseId,
    ControllerMovementCommand movement = ControllerMovementCommand.dispenseNext,
    required ControllerDispenseStageCallback onStage,
  }) async {}

  @override
  Future<String> runBenchCommand(ControllerBenchCommand command) async => 'OK';

  @override
  Stream<ControllerSnapshot> watchController() => Stream.value(snapshot);
}

class _TestControllerHost extends StatelessWidget {
  const _TestControllerHost({
    required this.production,
    required this.demo,
    required this.productionClock,
  });

  final DoseyDatabase production;
  final DoseyDatabase demo;
  final ControllableAppClock productionClock;

  @override
  Widget build(BuildContext context) {
    return DemoModeHost(
      productionDatabase: production,
      productionClock: productionClock,
      demoDatabaseFactory: () => demo,
      devicePlatform: AppDevicePlatform.android,
      builder: (context, session) => DoseyAppScope(
        key: ValueKey(session.isDemo),
        database: session.database,
        appClock: session.clock,
        bleGateway: FakeBleGateway(),
        connectivityGateway: FakeConnectivityGateway(),
        permissionGateway: const _FakePermissionGateway(),
        reminderScheduler: const _NoopReminderScheduler(),
        missedDoseReconciliationService: session.isDemo
            ? null
            : FakeMissedDoseReconciliationService(),
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2F6F5E),
            ),
            useMaterial3: true,
          ),
          home: const Scaffold(body: ControllerScreen()),
        ),
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
