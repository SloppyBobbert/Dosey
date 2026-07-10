import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/controller/local_controller_command_repository.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/controller/controller_screen.dart';
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
