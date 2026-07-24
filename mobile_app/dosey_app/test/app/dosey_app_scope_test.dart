import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/auth/app_auth_service.dart';
import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:dosey_app/core/connectivity/connectivity_gateway.dart';
import 'package:dosey_app/core/demo/demo_data_repository.dart';
import 'package:dosey_app/core/demo/demo_external_services.dart';
import 'package:dosey_app/core/display/screen_awake_gateway.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/missed_dose_reconciliation_service.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/time/app_clock.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('maybeOf returns null when the app scope is absent', (
    WidgetTester tester,
  ) async {
    late final DoseyAppDependencies? dependencies;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            dependencies = DoseyAppScope.maybeOf(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(dependencies, isNull);
  });

  testWidgets('app scope wires the combined auth service', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final bleGateway = _FakeBleGateway();
    final connectivityGateway = _FakeConnectivityGateway();
    final reminderScheduler = _FakeReminderScheduler();
    final permissionGateway = _FakePermissionGateway();
    final missedDoseReconciliation = _FakeMissedDoseReconciliationService();
    late final Object auth;
    late final DoseyAppDependencies dependencies;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DoseyAppScope(
          database: database,
          bleGateway: bleGateway,
          connectivityGateway: connectivityGateway,
          reminderScheduler: reminderScheduler,
          permissionGateway: permissionGateway,
          missedDoseReconciliationService: missedDoseReconciliation,
          child: Builder(
            builder: (context) {
              dependencies = DoseyAppScope.of(context);
              auth = dependencies.auth;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(auth, isA<AppAuthService>());
    expect(dependencies.ble, same(bleGateway));
    expect(dependencies.connectivity, same(connectivityGateway));
    expect(dependencies.reminderScheduler, same(reminderScheduler));
    expect(dependencies.voicePlayer, isNotNull);
    expect(dependencies.permissions, same(permissionGateway));
    expect(dependencies.robotFaceSettings, isNotNull);
    expect(dependencies.robotFaceController, isNotNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('app scope wires robot face controller to live shortage alerts', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final bleGateway = _FakeBleGateway();
    final connectivityGateway = _FakeConnectivityGateway();
    final reminderScheduler = _FakeReminderScheduler();
    final permissionGateway = _FakePermissionGateway();
    final missedDoseReconciliation = _FakeMissedDoseReconciliationService();
    late DoseyAppDependencies dependencies;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DoseyAppScope(
          database: database,
          bleGateway: bleGateway,
          connectivityGateway: connectivityGateway,
          reminderScheduler: reminderScheduler,
          permissionGateway: permissionGateway,
          missedDoseReconciliationService: missedDoseReconciliation,
          child: Builder(
            builder: (context) {
              dependencies = DoseyAppScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    await database
        .into(database.medicationShortageAlerts)
        .insert(
          MedicationShortageAlertsCompanion.insert(
            id: 'shortage-1',
            profileId: 'schedule-1',
            loadSessionId: const Value('session-1'),
            slotNumber: 2,
            bundleKey: 'bundle-1',
            scheduledAt: DateTime.utc(2026, 7, 23, 8),
            prescriptionIdsJson: '["rx-1"]',
            prescriptionNamesJson: '["Vitamin D"]',
            status: 'active',
            localDeliveryState: 'sent',
            createdAt: DateTime.utc(2026, 7, 23, 8),
            updatedAt: DateTime.utc(2026, 7, 23, 8),
          ),
        );
    await tester.pump();

    final state = await dependencies.robotFaceController.watchState().first;

    expect(state.hasPinnedShortageAlert, isTrue);
    expect(state.activeShortageLabel, 'Urgent shortage · slot 2');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('demo scope wires scenarios and disables external services', (
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
    final screenAwake = _FakeScreenAwakeGateway();
    late DoseyAppDependencies dependencies;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DoseyAppScope(
          database: database,
          appClock: clock,
          screenAwakeGateway: screenAwake,
          child: Builder(
            builder: (context) {
              dependencies = DoseyAppScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(dependencies.isDemo, isTrue);
    expect(dependencies.demoScenarios, isNotNull);
    expect(dependencies.reminderScheduler, isA<DemoReminderScheduler>());
    expect(dependencies.ble, isA<DemoBleGateway>());
    expect(dependencies.connectivity, isA<DemoConnectivityGateway>());
    expect(dependencies.permissions, isA<DemoPermissionGateway>());
    expect(dependencies.screenAwake, same(screenAwake));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('demo scope creates a controllable clock when none is injected', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory(isDemo: true);
    addTearDown(database.close);
    late DoseyAppDependencies dependencies;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DoseyAppScope(
          database: database,
          child: Builder(
            builder: (context) {
              dependencies = DoseyAppScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(dependencies.appClock, isA<ControllableAppClock>());

    await tester.pumpWidget(const SizedBox());
  });
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
  Future<int> deleteSchedule(String id, {AdminAuditEvent? auditEvent}) async =>
      1;

  @override
  Future<void> upsertSchedule(
    ReminderSchedule schedule, {
    AdminAuditEvent? auditEvent,
  }) async {}

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

class _FakeReminderScheduler implements ReminderScheduler {
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

class _FakePermissionGateway implements AppPermissionGateway {
  @override
  Future<AppPermissionState> check(AppPermission permission) async {
    return AppPermissionState.granted;
  }

  @override
  Future<AppPermissionState> request(AppPermission permission) async {
    return AppPermissionState.granted;
  }
}

class _FakeScreenAwakeGateway implements ScreenAwakeGateway {
  @override
  Future<void> setKeepScreenAwake(bool enabled) async {}
}
