import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/auth/app_auth_service.dart';
import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:dosey_app/core/connectivity/connectivity_gateway.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/missed_dose_reconciliation_service.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
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
    expect(dependencies.permissions, same(permissionGateway));
    expect(dependencies.robotFaceSettings, isNotNull);
    expect(dependencies.robotFaceController, isNotNull);

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
  Future<void> deleteSchedule(String id) async {}

  @override
  Future<void> upsertSchedule(ReminderSchedule schedule) async {}

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
