import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/demo/demo_data_repository.dart';
import 'package:dosey_app/core/demo/demo_mode_host.dart';
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
    await tester.tap(find.text('Connect simulator'));
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

  testWidgets('enters and exits isolated demo mode from Controller', (
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
    expect(find.text('Enter demo mode'), findsOneWidget);
    await tester.tap(find.text('Enter demo mode'));
    await tester.pumpAndSettle();

    expect(find.text('FAKE DATA'), findsOneWidget);
    expect(find.text('Demo scenario runner'), findsOneWidget);
    expect(find.text('Exit demo mode'), findsOneWidget);

    await tester.ensureVisible(find.text('Exit demo mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit demo mode'));
    await tester.pumpAndSettle();

    expect(find.text('FAKE DATA'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Enter demo mode'), findsOneWidget);
  });

  testWidgets('steps a scenario and records bench command history', (
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
    await tester.tap(find.text('Enter demo mode'));
    await tester.pumpAndSettle();

    expect(find.text('Next: Dose approaching'), findsOneWidget);
    await tester.tap(find.text('Next step'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 8 steps complete'), findsOneWidget);
    expect(find.text('Next: Dose ready'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('STATUS'));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(ListView), const Offset(0, -1000), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Command history'), findsOneWidget);
    expect(find.text('STATUS'), findsWidgets);
    await tester.tap(find.widgetWithText(ExpansionTile, 'STATUS'));
    await tester.pumpAndSettle();
    expect(find.text('ACK'), findsOneWidget);
    expect(find.text('Simulator connected'), findsOneWidget);
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

      expect(find.text('Demo scenario runner'), findsOneWidget);
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
  const _TestControllerApp({required this.database});

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
        home: const Scaffold(body: ControllerScreen()),
      ),
    );
  }
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
