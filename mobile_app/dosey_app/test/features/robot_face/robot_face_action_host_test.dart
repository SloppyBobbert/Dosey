import 'dart:async';

import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/connectivity/connectivity_gateway.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/reminders/missed_dose_reconciliation_service.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/robot_face/robot_face_screen.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const readyState = RobotFaceState(
    mode: RobotFaceMode.doseReady,
    nextEventLabel: 'Now · Morning meds',
    isFlipped: false,
    isLandscapeOnly: true,
    rampProgress: 1,
    isInAwakeWindow: true,
    actionDoseId: 'dose-1',
    availableActions: {RobotFaceActionKind.confirmTaken},
  );

  testWidgets(
    'keeps the action panel State mounted while actions hide and show',
    (tester) async {
      final states = StreamController<RobotFaceState>.broadcast();
      final semantics = tester.ensureSemantics();
      addTearDown(states.close);

      try {
        await tester.pumpWidget(_ActionHostTestApp(stateStream: states.stream));
        states.add(readyState);
        await tester.pump();

        final panelFinder = find.byKey(
          RobotFaceScreen.actionPanelKey,
          skipOffstage: false,
        );
        final hostFinder = find.byKey(RobotFaceScreen.actionHostKey);
        final initialState = tester.state(panelFinder);
        expect(hostFinder, findsOneWidget);
        expect(tester.getSize(hostFinder).height, greaterThan(0));
        expect(
          find.byKey(RobotFaceScreen.confirmTakenButtonKey),
          findsOneWidget,
        );

        states.add(readyState.copyWith(availableActions: const {}));
        await tester.pump();

        expect(panelFinder, findsOneWidget);
        expect(tester.state(panelFinder), same(initialState));
        expect(tester.getSize(hostFinder), Size.zero);
        expect(
          find
              .byKey(RobotFaceScreen.confirmTakenButtonKey, skipOffstage: false)
              .hitTestable(),
          findsNothing,
        );
        expect(find.bySemanticsLabel('I can see it and took it'), findsNothing);

        states.add(readyState);
        await tester.pump();

        expect(tester.state(panelFinder), same(initialState));
        expect(
          find.byKey(RobotFaceScreen.confirmTakenButtonKey),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('keeps confirm disabled after it completes while hidden', (
    tester,
  ) async {
    final states = StreamController<RobotFaceState>.broadcast();
    final logger = _DelayedVisibleAndTakenLogger();
    addTearDown(states.close);

    await tester.pumpWidget(
      _ActionHostTestApp(
        stateStream: states.stream,
        visibleAndTakenLogger: logger.call,
      ),
    );
    states.add(readyState);
    await tester.pump();

    await tester.tap(find.byKey(RobotFaceScreen.confirmTakenButtonKey));
    await tester.pump();
    states.add(readyState.copyWith(availableActions: const {}));
    await tester.pump();

    logger.complete();
    await tester.pump();
    states.add(readyState);
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(
            find.byKey(RobotFaceScreen.confirmTakenButtonKey),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('keeps an in-flight confirm submission locked across hiding', (
    tester,
  ) async {
    final states = StreamController<RobotFaceState>.broadcast();
    final logger = _DelayedVisibleAndTakenLogger();
    addTearDown(states.close);

    await tester.pumpWidget(
      _ActionHostTestApp(
        stateStream: states.stream,
        visibleAndTakenLogger: logger.call,
      ),
    );
    states.add(readyState);
    await tester.pump();

    await tester.tap(find.byKey(RobotFaceScreen.confirmTakenButtonKey));
    await tester.pump();
    expect(logger.calls, 1);

    states.add(readyState.copyWith(availableActions: const {}));
    await tester.pump();
    states.add(readyState);
    await tester.pump();

    final confirm = find.byKey(RobotFaceScreen.confirmTakenButtonKey);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.tap(confirm);
    await tester.pump();
    expect(logger.calls, 1);

    logger.complete();
    await tester.pump();
  });

  testWidgets(
    'continues a PIN-authorized confirm after actions hide and show',
    (tester) async {
      final database = DoseyDatabase.inMemory();
      final states = StreamController<RobotFaceState>.broadcast();
      final logger = _DelayedVisibleAndTakenLogger();
      addTearDown(database.close);
      addTearDown(states.close);
      await LocalAppSettingsRepository(
        database,
        defaultRole: AppDeviceRole.androidPersonal,
      ).setActionPin('1234');

      await tester.pumpWidget(
        _ActionHostTestApp(
          database: database,
          stateStream: states.stream,
          visibleAndTakenLogger: logger.call,
        ),
      );
      states.add(readyState);
      await tester.pump();

      await tester.tap(find.byKey(RobotFaceScreen.confirmTakenButtonKey));
      await tester.pump();
      expect(find.text('Enter Action PIN'), findsOneWidget);

      states.add(readyState.copyWith(availableActions: const {}));
      await tester.pump();
      states.add(readyState);
      await tester.pump();

      await tester.enterText(find.byKey(const Key('action-pin-field')), '1234');
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(logger.calls, 1);
      logger.complete();
      await tester.pump();
      expect(logger.calls, 1);
    },
  );

  testWidgets('does not continue a PIN-authorized confirm for a new dose', (
    tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final states = StreamController<RobotFaceState>.broadcast();
    final logger = _DelayedVisibleAndTakenLogger();
    addTearDown(database.close);
    addTearDown(states.close);
    await LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    ).setActionPin('1234');

    await tester.pumpWidget(
      _ActionHostTestApp(
        database: database,
        stateStream: states.stream,
        visibleAndTakenLogger: logger.call,
      ),
    );
    states.add(readyState);
    await tester.pump();

    await tester.tap(find.byKey(RobotFaceScreen.confirmTakenButtonKey));
    await tester.pump();
    states.add(readyState.copyWith(actionDoseId: 'dose-2'));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('action-pin-field')), '1234');
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(logger.calls, 0);
  });

  testWidgets(
    'does not continue a PIN-authorized confirm after it becomes unavailable',
    (tester) async {
      final database = DoseyDatabase.inMemory();
      final states = StreamController<RobotFaceState>.broadcast();
      final logger = _DelayedVisibleAndTakenLogger();
      addTearDown(database.close);
      addTearDown(states.close);
      await LocalAppSettingsRepository(
        database,
        defaultRole: AppDeviceRole.androidPersonal,
      ).setActionPin('1234');

      await tester.pumpWidget(
        _ActionHostTestApp(
          database: database,
          stateStream: states.stream,
          visibleAndTakenLogger: logger.call,
        ),
      );
      states.add(readyState);
      await tester.pump();

      await tester.tap(find.byKey(RobotFaceScreen.confirmTakenButtonKey));
      await tester.pump();
      states.add(readyState.copyWith(availableActions: const {}));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('action-pin-field')), '1234');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(logger.calls, 0);
    },
  );

  testWidgets(
    'keeps the panel State but resets completed actions for a new dose',
    (tester) async {
      final states = StreamController<RobotFaceState>.broadcast();
      final logger = _ImmediateVisibleAndTakenLogger();
      addTearDown(states.close);

      await tester.pumpWidget(
        _ActionHostTestApp(
          stateStream: states.stream,
          visibleAndTakenLogger: logger.call,
        ),
      );
      states.add(readyState);
      await tester.pump();
      final panelFinder = find.byKey(
        RobotFaceScreen.actionPanelKey,
        skipOffstage: false,
      );
      final initialState = tester.state(panelFinder);

      await tester.tap(find.byKey(RobotFaceScreen.confirmTakenButtonKey));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(RobotFaceScreen.confirmTakenButtonKey),
            )
            .onPressed,
        isNull,
      );

      states.add(readyState.copyWith(actionDoseId: 'dose-2'));
      await tester.pump();

      expect(tester.state(panelFinder), same(initialState));
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(RobotFaceScreen.confirmTakenButtonKey),
            )
            .onPressed,
        isNotNull,
      );
    },
  );
}

class _ActionHostTestApp extends StatefulWidget {
  const _ActionHostTestApp({
    required this.stateStream,
    this.database,
    this.visibleAndTakenLogger,
  });

  final Stream<RobotFaceState> stateStream;
  final DoseyDatabase? database;
  final RobotFaceVisibleAndTakenLogger? visibleAndTakenLogger;

  @override
  State<_ActionHostTestApp> createState() => _ActionHostTestAppState();
}

class _ActionHostTestAppState extends State<_ActionHostTestApp> {
  late final DoseyDatabase _database =
      widget.database ?? DoseyDatabase.inMemory();

  @override
  void dispose() {
    if (widget.database == null) unawaited(_database.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DoseyAppScope(
      database: _database,
      bleGateway: _FakeBleGateway(),
      connectivityGateway: _FakeConnectivityGateway(),
      permissionGateway: _FakePermissionGateway(),
      reminderScheduler: _FakeReminderScheduler(),
      missedDoseReconciliationService: _FakeMissedDoseReconciliationService(),
      child: MaterialApp(
        home: RobotFaceScreen(
          stateStream: widget.stateStream,
          visibleAndTakenLogger: widget.visibleAndTakenLogger,
        ),
      ),
    );
  }
}

class _DelayedVisibleAndTakenLogger {
  final Completer<bool> _completion = Completer<bool>();
  int calls = 0;

  Future<bool> call(
    BuildContext context, {
    required String doseId,
    required DateTime occurredAt,
    required String successMessage,
  }) {
    calls += 1;
    return _completion.future;
  }

  void complete() => _completion.complete(true);
}

class _ImmediateVisibleAndTakenLogger {
  Future<bool> call(
    BuildContext context, {
    required String doseId,
    required DateTime occurredAt,
    required String successMessage,
  }) async => true;
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
  Future<ConnectivityState> currentConnectivity() async =>
      ConnectivityState.wifi;

  @override
  Stream<ConnectivityState> watchConnectivity() {
    return Stream.value(ConnectivityState.wifi);
  }
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
