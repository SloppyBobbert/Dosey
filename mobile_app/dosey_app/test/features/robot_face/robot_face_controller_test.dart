import 'dart:async';

import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/carousel/local_guided_carousel_load_repository.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/controller/controller_lifecycle_service.dart';
import 'package:dosey_app/core/connectivity/connectivity_gateway.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/core/schedules/local_schedule_profile_repository.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/robot_face/robot_face_controller.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings_repository.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'idle state includes the next event label when nothing urgent is active',
    () async {
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 9),
        scheduleHour: 10,
        scheduleMinute: 0,
      );
      addTearDown(fixture.close);

      await fixture.settle();

      final state = await fixture.controller.watchState().first;

      expect(state.mode, RobotFaceMode.idle);
      expect(state.nextEventLabel, '10:00 · Morning meds');
      expect(state.rampProgress, 0);
      expect(state.isInAwakeWindow, isFalse);
    },
  );

  test('internet loss adds a non-blocking Robot Face advisory', () async {
    final fixture = await _RobotFaceControllerFixture.create(
      now: DateTime(2026, 7, 8, 9),
      scheduleHour: 10,
      connectivity: Stream<ConnectivityState>.value(ConnectivityState.offline),
    );
    addTearDown(fixture.close);

    await fixture.settle();
    final state = await fixture.controller.watchState().first;

    expect(state.mode, RobotFaceMode.idle);
    expect(state.networkAdvisory, RobotFaceNetworkAdvisory.internetOffline);
    expect(state.availableActions, isEmpty);
  });

  test(
    'internet advisory does not replace a blocking controller error',
    () async {
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 9),
        scheduleHour: 10,
        connectivity: Stream<ConnectivityState>.value(
          ConnectivityState.offline,
        ),
        controllerSnapshot: const ControllerSnapshot(
          connectionState: ControllerConnectionState.disconnected,
          healthState: ControllerHealthState.error,
          statusLabel: 'Bluetooth is unavailable',
          canRequestDispense: false,
        ),
      );
      addTearDown(fixture.close);

      await fixture.settle();
      final state = await fixture.controller.watchState().first;

      expect(state.mode, RobotFaceMode.error);
      expect(state.statusLabel, 'Bluetooth is unavailable');
      expect(state.networkAdvisory, RobotFaceNetworkAdvisory.internetOffline);
    },
  );

  test(
    'robot face state exposes a pinned active shortage foundation',
    () async {
      final shortageAlerts = Stream<List<MedicationShortageAlertRow>>.value([
        MedicationShortageAlertRow(
          id: 'shortage-1',
          profileId: 'profile-1',
          loadSessionId: 'session-1',
          slotNumber: 2,
          bundleKey: 'bundle-1',
          scheduledAt: DateTime.utc(2026, 7, 8, 10),
          prescriptionIdsJson: '["rx-1"]',
          prescriptionNamesJson: '["Vitamin D"]',
          status: 'active',
          recognizedAt: null,
          resolvedAt: null,
          resolution: null,
          intendedAudience: 'household',
          localDeliveryState: 'sent',
          localNotificationSentAt: DateTime.utc(2026, 7, 8, 9),
          remoteDeliveryState: 'not_configured',
          createdAt: DateTime.utc(2026, 7, 8, 9),
          updatedAt: DateTime.utc(2026, 7, 8, 9),
        ),
      ]);
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 9),
        scheduleHour: 10,
        scheduleMinute: 0,
        shortageAlerts: shortageAlerts,
      );
      addTearDown(fixture.close);

      await fixture.settle();

      final state = await fixture.controller.watchState().first;
      final scheduledLabel = _localTimeLabel(DateTime.utc(2026, 7, 8, 10));
      expect(state.hasPinnedShortageAlert, isTrue);
      expect(state.activeShortageLabel, 'Urgent shortage · slot 2');
      expect(state.activeShortageMedicationLabel, 'Vitamin D');
      expect(state.activeShortageScheduledLabel, scheduledLabel);
      expect(state.activeShortageSlotNumber, 2);
    },
  );

  test('robot face keeps unresolved past-due shortages pinned', () async {
    final shortageAlerts = Stream<List<MedicationShortageAlertRow>>.value([
      MedicationShortageAlertRow(
        id: 'shortage-past-due',
        profileId: 'profile-1',
        loadSessionId: 'session-1',
        slotNumber: 3,
        bundleKey: 'bundle-2',
        scheduledAt: DateTime.utc(2026, 7, 8, 11),
        prescriptionIdsJson: '["rx-1"]',
        prescriptionNamesJson: '["Vitamin D"]',
        status: 'past_due',
        recognizedAt: DateTime.utc(2026, 7, 8, 11, 5),
        resolvedAt: null,
        resolution: null,
        intendedAudience: 'household',
        localDeliveryState: 'sent',
        localNotificationSentAt: DateTime.utc(2026, 7, 8, 11),
        remoteDeliveryState: 'not_configured',
        createdAt: DateTime.utc(2026, 7, 8, 10, 55),
        updatedAt: DateTime.utc(2026, 7, 8, 11, 5),
      ),
    ]);
    final fixture = await _RobotFaceControllerFixture.create(
      now: DateTime(2026, 7, 8, 12),
      scheduleHour: 13,
      scheduleMinute: 0,
      shortageAlerts: shortageAlerts,
    );
    addTearDown(fixture.close);

    await fixture.settle();

    final state = await fixture.controller.watchState().first;
    final scheduledLabel = _localTimeLabel(DateTime.utc(2026, 7, 8, 11));
    expect(state.hasPinnedShortageAlert, isTrue);
    expect(state.activeShortageLabel, 'Urgent shortage · slot 3');
    expect(state.activeShortageMedicationLabel, 'Vitamin D');
    expect(state.activeShortageScheduledLabel, scheduledLabel);
    expect(state.activeShortageSlotNumber, 3);
  });

  test(
    'robot face prioritizes unresolved past-due shortage over active shortage',
    () async {
      final shortageAlerts = Stream<List<MedicationShortageAlertRow>>.value([
        MedicationShortageAlertRow(
          id: 'shortage-active',
          profileId: 'profile-1',
          loadSessionId: 'session-1',
          slotNumber: 2,
          bundleKey: 'bundle-active',
          scheduledAt: DateTime.utc(2026, 7, 8, 10),
          prescriptionIdsJson: '["rx-1"]',
          prescriptionNamesJson: '["Active Med"]',
          status: 'active',
          recognizedAt: null,
          resolvedAt: null,
          resolution: null,
          intendedAudience: 'household',
          localDeliveryState: 'sent',
          localNotificationSentAt: DateTime.utc(2026, 7, 8, 9),
          remoteDeliveryState: 'not_configured',
          createdAt: DateTime.utc(2026, 7, 8, 9),
          updatedAt: DateTime.utc(2026, 7, 8, 9),
        ),
        MedicationShortageAlertRow(
          id: 'shortage-past-due',
          profileId: 'profile-1',
          loadSessionId: 'session-2',
          slotNumber: 4,
          bundleKey: 'bundle-past',
          scheduledAt: DateTime.utc(2026, 7, 8, 11),
          prescriptionIdsJson: '["rx-2"]',
          prescriptionNamesJson: '["Past Due Med"]',
          status: 'past_due',
          recognizedAt: DateTime.utc(2026, 7, 8, 11, 5),
          resolvedAt: null,
          resolution: null,
          intendedAudience: 'household',
          localDeliveryState: 'sent',
          localNotificationSentAt: DateTime.utc(2026, 7, 8, 11),
          remoteDeliveryState: 'not_configured',
          createdAt: DateTime.utc(2026, 7, 8, 10, 55),
          updatedAt: DateTime.utc(2026, 7, 8, 11, 5),
        ),
      ]);
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 12),
        scheduleHour: 13,
        scheduleMinute: 0,
        shortageAlerts: shortageAlerts,
      );
      addTearDown(fixture.close);

      await fixture.settle();

      final state = await fixture.controller.watchState().first;
      expect(state.activeShortageLabel, 'Urgent shortage · slot 4');
      expect(state.activeShortageMedicationLabel, 'Past Due Med');
    },
  );

  test(
    'ramp progress rises inside the configured wake-before window',
    () async {
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 9, 55),
        scheduleHour: 10,
        scheduleMinute: 0,
        robotFaceSettings: const RobotFaceSettings(wakeBeforeDoseMinutes: 10),
      );
      addTearDown(fixture.close);

      await fixture.settle();

      final state = await fixture.controller.watchState().first;

      expect(state.mode, RobotFaceMode.doseApproaching);
      expect(state.rampProgress, closeTo(0.5, 0.001));
      expect(state.isInAwakeWindow, isTrue);
      expect(state.voiceOccurrenceKey, 'schedule-1:2026-07-08');
    },
  );

  test('dose-approaching voice occurrence key stays stable per day', () async {
    final now = DateTime(2026, 7, 8, 8, 55);
    final fixture = await _RobotFaceControllerFixture.create(
      now: now,
      scheduleHour: 9,
      scheduleMinute: 0,
      robotFaceSettings: const RobotFaceSettings(wakeBeforeDoseMinutes: 10),
    );
    addTearDown(fixture.close);

    await fixture.settle();

    final initialState = await fixture.controller.watchState().first;
    expect(initialState.mode, RobotFaceMode.doseApproaching);
    expect(initialState.voiceOccurrenceKey, 'schedule-1:2026-07-08');

    fixture.now = DateTime(2026, 7, 9, 8, 55);
    fixture.controller.recordInteraction();
    final nextDayState = await fixture.controller.watchState().firstWhere(
      (state) => state.voiceOccurrenceKey == 'schedule-1:2026-07-09',
    );
    expect(nextDayState.mode, RobotFaceMode.doseApproaching);
    expect(nextDayState.nextEventLabel, '09:00 · Morning meds');
  });

  test(
    'wake before off keeps the face idle until the scheduled time',
    () async {
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 9, 45),
        scheduleHour: 10,
        scheduleMinute: 0,
        robotFaceSettings: const RobotFaceSettings(wakeBeforeDoseMinutes: 0),
      );
      addTearDown(fixture.close);

      await fixture.settle();

      final state = await fixture.controller.watchState().first;

      expect(state.mode, RobotFaceMode.idle);
      expect(state.rampProgress, 0);
      expect(state.isInAwakeWindow, isFalse);
    },
  );

  test(
    'transitions to sleepy after the inactivity timeout when dimming is enabled',
    () async {
      final clock = StreamController<DateTime>.broadcast();
      var now = DateTime(2026, 7, 8, 9);
      final fixture = await _RobotFaceControllerFixture.create(
        now: now,
        scheduleHour: 14,
        scheduleMinute: 0,
        clock: clock.stream,
      );
      addTearDown(() async {
        await clock.close();
        await fixture.close();
      });

      await fixture.settle();

      final initialState = await fixture.controller.watchState().first;
      expect(initialState.mode, RobotFaceMode.idle);

      now = now.add(const Duration(minutes: 31));
      fixture.now = now;
      clock.add(now);

      final sleepyState = await fixture.controller.watchState().firstWhere(
        (state) => state.mode == RobotFaceMode.sleepy,
      );

      expect(sleepyState.nextEventLabel, '14:00 · Morning meds');
    },
  );

  test('recordInteraction wakes a sleepy idle face back to idle', () async {
    final clock = StreamController<DateTime>.broadcast();
    var now = DateTime(2026, 7, 8, 9);
    final fixture = await _RobotFaceControllerFixture.create(
      now: now,
      scheduleHour: 14,
      scheduleMinute: 0,
      clock: clock.stream,
    );
    addTearDown(() async {
      await clock.close();
      await fixture.close();
    });

    await fixture.settle();

    now = now.add(const Duration(minutes: 31));
    fixture.now = now;
    clock.add(now);

    await fixture.controller.watchState().firstWhere(
      (state) => state.mode == RobotFaceMode.sleepy,
    );

    fixture.controller.recordInteraction();

    final awakeState = await fixture.controller.watchState().firstWhere(
      (state) => state.mode == RobotFaceMode.idle,
    );

    expect(awakeState.isInAwakeWindow, isFalse);
    expect(awakeState.actionDoseId, isNull);
  });

  test(
    'recordInteraction refreshes the inactivity timer before the sleepy timeout',
    () async {
      final clock = StreamController<DateTime>.broadcast();
      var now = DateTime(2026, 7, 8, 9);
      final fixture = await _RobotFaceControllerFixture.create(
        now: now,
        scheduleHour: 14,
        scheduleMinute: 0,
        clock: clock.stream,
      );
      addTearDown(() async {
        await clock.close();
        await fixture.close();
      });

      await fixture.settle();

      now = now.add(const Duration(minutes: 20));
      fixture.now = now;
      fixture.controller.recordInteraction();

      now = now.add(const Duration(minutes: 20));
      fixture.now = now;
      clock.add(now);
      await fixture.settle();

      final state = await fixture.controller.watchState().first;

      expect(state.mode, RobotFaceMode.idle);
      expect(state.isInAwakeWindow, isFalse);

      now = now.add(const Duration(minutes: 11));
      fixture.now = now;
      clock.add(now);

      final sleepyState = await fixture.controller.watchState().firstWhere(
        (nextState) => nextState.mode == RobotFaceMode.sleepy,
      );

      expect(sleepyState.isInAwakeWindow, isFalse);
    },
  );

  test(
    'shows dose ready before dispense confirmation and does not mark taken from movement alone',
    () async {
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 9, 5),
        scheduleHour: 9,
        scheduleMinute: 0,
      );
      addTearDown(fixture.close);

      await fixture.settle();

      final readyState = await fixture.controller.watchState().first;
      expect(readyState.mode, RobotFaceMode.doseReady);
      expect(readyState.rampProgress, 1);
      expect(readyState.isInAwakeWindow, isTrue);
      expect(readyState.actionDoseId, fixture.currentDoseId);
      expect(
        readyState.availableActions,
        containsAll(<RobotFaceActionKind>{
          RobotFaceActionKind.confirmTaken,
          RobotFaceActionKind.skipDose,
          RobotFaceActionKind.askForHelp,
        }),
      );

      await fixture.doseLog.addEvent(
        DoseLogEvent.controllerDispenseSucceeded(
          doseId: fixture.currentDoseId,
          occurredAt: fixture.now.toUtc(),
        ),
      );

      final waitingState = await fixture.controller.watchState().firstWhere(
        (state) => state.mode == RobotFaceMode.waitingForConfirmation,
      );

      expect(waitingState.mode, isNot(RobotFaceMode.happyConfirmed));
      expect(waitingState.statusLabel, contains('Awaiting'));
      expect(waitingState.actionDoseId, fixture.currentDoseId);
      expect(
        waitingState.availableActions,
        containsAll(<RobotFaceActionKind>{
          RobotFaceActionKind.confirmTaken,
          RobotFaceActionKind.skipDose,
          RobotFaceActionKind.askForHelp,
        }),
      );
    },
  );

  test(
    'caregiver help stays actionable but suppresses repeat help action',
    () async {
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 9, 5),
        scheduleHour: 9,
        scheduleMinute: 0,
      );
      addTearDown(fixture.close);

      await fixture.settle();

      await fixture.doseLog.addEvent(
        DoseLogEvent.caregiverHelpRequested(
          doseId: fixture.currentDoseId,
          occurredAt: fixture.now.toUtc(),
        ),
      );

      final waitingState = await fixture.controller.watchState().firstWhere(
        (state) => state.mode == RobotFaceMode.waitingForConfirmation,
      );

      expect(waitingState.actionDoseId, fixture.currentDoseId);
      expect(
        waitingState.availableActions,
        containsAll(<RobotFaceActionKind>{
          RobotFaceActionKind.confirmTaken,
          RobotFaceActionKind.skipDose,
        }),
      );
      expect(
        waitingState.availableActions,
        isNot(contains(RobotFaceActionKind.askForHelp)),
      );
    },
  );

  test(
    'dispensed dose stays actionable across controller disconnect',
    () async {
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 9, 5),
        scheduleHour: 9,
        scheduleMinute: 0,
      );
      addTearDown(fixture.close);

      await fixture.settle();

      await fixture.doseLog.addEvent(
        DoseLogEvent.controllerDispenseSucceeded(
          doseId: fixture.currentDoseId,
          occurredAt: fixture.now.toUtc(),
        ),
      );

      final waitingState = await fixture.controller.watchState().firstWhere(
        (state) => state.mode == RobotFaceMode.waitingForConfirmation,
      );
      expect(waitingState.actionDoseId, fixture.currentDoseId);

      fixture.controllerGateway.emitSnapshot(
        const ControllerSnapshot.disconnected(),
      );

      final offlineState = await fixture.controller.watchState().firstWhere(
        (state) => state.mode == RobotFaceMode.offline,
      );

      expect(offlineState.actionDoseId, fixture.currentDoseId);
      expect(
        offlineState.availableActions,
        containsAll(<RobotFaceActionKind>{
          RobotFaceActionKind.confirmTaken,
          RobotFaceActionKind.skipDose,
          RobotFaceActionKind.askForHelp,
        }),
      );
    },
  );

  test('connected transport stays offline until health is verified', () async {
    final fixture = await _RobotFaceControllerFixture.create(
      now: DateTime(2026, 7, 8, 9),
      controllerSnapshot: const ControllerSnapshot(
        connectionState: ControllerConnectionState.connected,
        canRequestDispense: false,
        statusLabel: 'Verifying controller heartbeat',
        healthState: ControllerHealthState.verifying,
      ),
    );
    addTearDown(fixture.close);

    await fixture.settle();
    final state = await fixture.controller.watchState().first;

    expect(state.mode, RobotFaceMode.offline);
    expect(state.controllerCondition, RobotFaceControllerCondition.verifying);
    expect(state.statusLabel, 'Verifying controller heartbeat');
  });

  for (final testCase
      in <
        ({ControllerSnapshot snapshot, RobotFaceControllerCondition condition})
      >[
        (
          snapshot: const ControllerSnapshot.disconnected(),
          condition: RobotFaceControllerCondition.disconnected,
        ),
        (
          snapshot: const ControllerSnapshot(
            connectionState: ControllerConnectionState.scanning,
            canRequestDispense: false,
            statusLabel: 'Connecting to controller',
            healthState: ControllerHealthState.connecting,
          ),
          condition: RobotFaceControllerCondition.connecting,
        ),
        (
          snapshot: const ControllerSnapshot.connected(),
          condition: RobotFaceControllerCondition.verifying,
        ),
        (
          snapshot: const ControllerSnapshot.online(),
          condition: RobotFaceControllerCondition.online,
        ),
        (
          snapshot: const ControllerSnapshot(
            connectionState: ControllerConnectionState.disconnected,
            canRequestDispense: false,
            statusLabel: 'Controller heartbeat missed',
            healthState: ControllerHealthState.offline,
          ),
          condition: RobotFaceControllerCondition.offline,
        ),
        (
          snapshot: const ControllerSnapshot(
            connectionState: ControllerConnectionState.scanning,
            canRequestDispense: false,
            statusLabel: 'Reconnecting to controller',
            healthState: ControllerHealthState.reconnecting,
          ),
          condition: RobotFaceControllerCondition.reconnecting,
        ),
        (
          snapshot: const ControllerSnapshot(
            connectionState: ControllerConnectionState.error,
            canRequestDispense: false,
            statusLabel: 'Wireless hardware is unavailable',
            healthState: ControllerHealthState.error,
            errorKind: ControllerErrorKind.bluetoothUnavailable,
          ),
          condition: RobotFaceControllerCondition.bluetoothUnavailable,
        ),
        (
          snapshot: const ControllerSnapshot(
            connectionState: ControllerConnectionState.error,
            canRequestDispense: false,
            statusLabel: 'Bluetooth controller reported a jam',
            healthState: ControllerHealthState.error,
            errorKind: ControllerErrorKind.other,
          ),
          condition: RobotFaceControllerCondition.fault,
        ),
      ]) {
    test('maps ${testCase.condition.name} controller presentation', () async {
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 9),
        scheduleHour: 10,
        controllerSnapshot: testCase.snapshot,
      );
      addTearDown(fixture.close);

      await fixture.settle();

      final state = await fixture.controller.watchState().first;
      expect(state.controllerCondition, testCase.condition);
    });
  }

  test(
    'surfaces happy confirmed for the current due dose before advancing',
    () async {
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 9, 5),
        schedules: <ReminderSchedule>[
          _schedule(
            id: 'schedule-1',
            profileId: 'profile-1',
            hour: 9,
            minute: 0,
            now: DateTime(2026, 7, 8, 9, 5),
          ),
          _schedule(
            id: 'schedule-2',
            profileId: 'profile-1',
            hour: 13,
            minute: 0,
            now: DateTime(2026, 7, 8, 9, 5),
            label: 'Afternoon meds',
          ),
        ],
      );
      addTearDown(fixture.close);

      await fixture.settle();

      await fixture.doseLog.addEvent(
        DoseLogEvent.doseTakenConfirmed(
          doseId: fixture.currentDoseId,
          occurredAt: fixture.now.toUtc(),
        ),
      );

      final confirmedState = await fixture.controller.watchState().firstWhere(
        (state) => state.mode == RobotFaceMode.happyConfirmed,
      );

      expect(confirmedState.nextEventLabel, '09:00 · Morning meds');
      expect(confirmedState.statusLabel, 'Dose confirmed taken');
      expect(confirmedState.rampProgress, 1);
      expect(confirmedState.isInAwakeWindow, isTrue);
      expect(confirmedState.actionDoseId, isNull);
      expect(confirmedState.availableActions, isEmpty);
    },
  );

  test('non-actionable states do not carry an action dose id', () async {
    final fixture = await _RobotFaceControllerFixture.create(
      now: DateTime(2026, 7, 8, 9),
      scheduleHour: 10,
      scheduleMinute: 0,
    );
    addTearDown(fixture.close);

    await fixture.settle();

    final idleState = await fixture.controller.watchState().first;

    expect(idleState.mode, RobotFaceMode.idle);
    expect(idleState.actionDoseId, isNull);
    expect(idleState.availableActions, isEmpty);
  });

  test(
    'controller error with only a future schedule does not carry an action dose id',
    () async {
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 9),
        scheduleHour: 10,
        scheduleMinute: 0,
        controllerSnapshot: const ControllerSnapshot(
          connectionState: ControllerConnectionState.error,
          canRequestDispense: false,
          statusLabel: 'Controller error',
          healthState: ControllerHealthState.error,
        ),
      );
      addTearDown(fixture.close);

      await fixture.settle();

      final state = await fixture.controller.watchState().first;

      expect(state.mode, RobotFaceMode.error);
      expect(state.nextEventLabel, '10:00 · Morning meds');
      expect(state.actionDoseId, isNull);
      expect(state.availableActions, isEmpty);
    },
  );

  test(
    'due-dose awake window prevents sleepy mode after the inactivity timeout',
    () async {
      final clock = StreamController<DateTime>.broadcast();
      var now = DateTime(2026, 7, 8, 9, 20);
      final fixture = await _RobotFaceControllerFixture.create(
        now: now,
        scheduleHour: 10,
        scheduleMinute: 0,
        clock: clock.stream,
        robotFaceSettings: const RobotFaceSettings(wakeBeforeDoseMinutes: 15),
      );
      addTearDown(() async {
        await clock.close();
        await fixture.close();
      });

      await fixture.settle();

      expect(
        (await fixture.controller.watchState().first).mode,
        RobotFaceMode.idle,
      );

      now = DateTime(2026, 7, 8, 9, 51);
      fixture.now = now;
      clock.add(now);

      final awakeState = await fixture.controller.watchState().firstWhere(
        (state) => state.isInAwakeWindow,
      );

      expect(awakeState.mode, RobotFaceMode.doseApproaching);
      expect(awakeState.rampProgress, greaterThan(0));
    },
  );

  test(
    'active missed-dose alert stays missed after inactivity timeout and interaction does not change its only action',
    () async {
      final clock = StreamController<DateTime>.broadcast();
      var now = DateTime(2026, 7, 8, 9, 5);
      final fixture = await _RobotFaceControllerFixture.create(
        now: now,
        scheduleHour: 9,
        scheduleMinute: 0,
        clock: clock.stream,
      );
      addTearDown(() async {
        await clock.close();
        await fixture.close();
      });

      await fixture.settle();
      await fixture.doseLog.addEvent(
        DoseLogEvent.doseMissed(
          doseId: fixture.currentDoseId,
          occurredAt: fixture.now.toUtc(),
        ),
      );

      final missedState = await fixture.controller.watchState().firstWhere(
        (state) => state.mode == RobotFaceMode.missed,
      );
      expect(missedState.isInAwakeWindow, isTrue);
      expect(missedState.availableActions, <RobotFaceActionKind>{
        RobotFaceActionKind.recognizeMissedDose,
      });

      now = now.add(const Duration(minutes: 31));
      fixture.now = now;
      clock.add(now);
      await fixture.settle();

      final timedOutState = await fixture.controller.watchState().first;
      expect(timedOutState.mode, RobotFaceMode.missed);
      expect(timedOutState.isInAwakeWindow, isFalse);
      expect(timedOutState.availableActions, <RobotFaceActionKind>{
        RobotFaceActionKind.recognizeMissedDose,
      });

      fixture.controller.recordInteraction();

      final afterInteractionState = await fixture.controller.watchState().first;
      expect(afterInteractionState.mode, RobotFaceMode.missed);
      expect(afterInteractionState.availableActions, <RobotFaceActionKind>{
        RobotFaceActionKind.recognizeMissedDose,
      });
    },
  );

  test(
    'recordInteraction does not add dose log events or revive missed alert actions on its own',
    () async {
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 9, 5),
        scheduleHour: 9,
        scheduleMinute: 0,
      );
      addTearDown(fixture.close);

      await fixture.settle();
      await fixture.doseLog.addEvent(
        DoseLogEvent.doseMissed(
          doseId: fixture.currentDoseId,
          occurredAt: fixture.now.toUtc(),
        ),
      );
      await fixture.doseLog.addEvent(
        DoseLogEvent.doseMissedRecognized(
          doseId: fixture.currentDoseId,
          occurredAt: fixture.now.add(const Duration(minutes: 1)).toUtc(),
        ),
      );

      final recognizedState = await fixture.controller.watchState().firstWhere(
        (state) => state.mode == RobotFaceMode.idle,
      );
      final eventCountBeforeInteraction = fixture.doseLog.events.length;

      fixture.controller.recordInteraction();

      final afterInteractionState = await fixture.controller.watchState().first;
      expect(fixture.doseLog.events, hasLength(eventCountBeforeInteraction));
      expect(afterInteractionState.mode, RobotFaceMode.idle);
      expect(afterInteractionState.availableActions, isEmpty);
      expect(afterInteractionState.actionDoseId, isNull);
      expect(recognizedState.availableActions, isEmpty);
    },
  );

  test(
    'does not show another profile schedule before the active profile resolves',
    () async {
      final now = DateTime(2026, 7, 8, 9, 5);
      final fixture = await _RobotFaceControllerFixture.create(
        now: now,
        emitDefaultActiveProfile: false,
        schedules: <ReminderSchedule>[
          _schedule(
            id: 'schedule-1',
            profileId: 'profile-1',
            hour: 9,
            minute: 0,
            now: now,
          ),
          _schedule(
            id: 'schedule-2',
            profileId: 'profile-2',
            hour: 8,
            minute: 30,
            now: now,
            label: 'Wrong profile meds',
          ),
        ],
      );
      addTearDown(fixture.close);

      await fixture.settle();

      final state = await fixture.controller.watchState().first;

      expect(state.mode, RobotFaceMode.idle);
      expect(state.nextEventLabel, 'No reminders scheduled');
      expect(state.statusLabel, 'No active reminder');
    },
  );

  test(
    'dispense request uses the first unresolved due schedule shown on the face',
    () async {
      final now = DateTime(2026, 7, 8, 9, 5);
      final fixture = await _RobotFaceControllerFixture.create(
        now: now,
        schedules: <ReminderSchedule>[
          _schedule(
            id: 'schedule-1',
            profileId: 'profile-1',
            hour: 8,
            minute: 0,
            now: now,
            label: 'Early meds',
          ),
          _schedule(
            id: 'schedule-2',
            profileId: 'profile-1',
            hour: 9,
            minute: 0,
            now: now,
            label: 'Current meds',
          ),
        ],
      );
      addTearDown(fixture.close);

      await fixture.settle();

      final initialState = await fixture.controller.watchState().first;
      expect(initialState.nextEventLabel, '08:00 · Early meds');

      final dispenseFuture = fixture.controller.requestDispenseForCurrentDose();

      final dispensingState = await fixture.controller.watchState().firstWhere(
        (state) => state.mode == RobotFaceMode.dispensing,
      );

      expect(dispensingState.nextEventLabel, '08:00 · Early meds');
      expect(fixture.controllerGateway.requestedDoseIds, <String>[
        'schedule-1:2026-07-08',
      ]);

      fixture.controllerGateway.completeDispense();
      await dispenseFuture;
    },
  );

  test(
    'dispense request rejects future reminders that are not due yet',
    () async {
      final now = DateTime(2026, 7, 8, 9);
      final fixture = await _RobotFaceControllerFixture.create(
        now: now,
        scheduleHour: 10,
        scheduleMinute: 0,
      );
      addTearDown(fixture.close);

      await fixture.settle();

      expect(
        fixture.controller.requestDispenseForCurrentDose(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'No active dose is ready to dispense.',
          ),
        ),
      );
      expect(fixture.controllerGateway.requestedDoseIds, isEmpty);
    },
  );

  test(
    'resolved earlier due dose advances display and dispense to the next due dose',
    () async {
      final now = DateTime(2026, 7, 8, 9, 5);
      final fixture = await _RobotFaceControllerFixture.create(
        now: now,
        schedules: <ReminderSchedule>[
          _schedule(
            id: 'schedule-1',
            profileId: 'profile-1',
            hour: 8,
            minute: 0,
            now: now,
            label: 'Early meds',
          ),
          _schedule(
            id: 'schedule-2',
            profileId: 'profile-1',
            hour: 9,
            minute: 0,
            now: now,
            label: 'Current meds',
          ),
        ],
      );
      addTearDown(fixture.close);

      await fixture.settle();

      await fixture.doseLog.addEvent(
        DoseLogEvent.doseTakenConfirmed(
          doseId: 'schedule-1:2026-07-08',
          occurredAt: now.toUtc(),
        ),
      );

      final readyState = await fixture.controller.watchState().firstWhere(
        (state) => state.nextEventLabel == '09:00 · Current meds',
      );

      expect(readyState.mode, RobotFaceMode.doseReady);

      final dispenseFuture = fixture.controller.requestDispenseForCurrentDose();
      final dispensingState = await fixture.controller.watchState().firstWhere(
        (state) => state.mode == RobotFaceMode.dispensing,
      );

      expect(dispensingState.nextEventLabel, '09:00 · Current meds');
      expect(fixture.controllerGateway.requestedDoseIds, <String>[
        'schedule-2:2026-07-08',
      ]);

      fixture.controllerGateway.completeDispense();
      await dispenseFuture;
    },
  );

  test(
    'second robot face dispense request is rejected before another lifecycle call starts',
    () async {
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 9, 5),
        scheduleHour: 9,
        scheduleMinute: 0,
      );
      addTearDown(fixture.close);

      await fixture.settle();

      final firstRequest = fixture.controller.requestDispenseForCurrentDose();
      await fixture.controllerGateway.requestStarted.future;

      await expectLater(
        fixture.controller.requestDispenseForCurrentDose(),
        throwsA(
          isA<DuplicateDispenseRequestException>().having(
            (error) => error.message,
            'message',
            'A dispense request is already in progress for this dose.',
          ),
        ),
      );
      expect(fixture.controllerGateway.requestedDoseIds, <String>[
        fixture.currentDoseId,
      ]);

      fixture.controllerGateway.completeDispense();
      await firstRequest;
    },
  );

  test(
    'robot face dispense does not depend on legacy slot id for guided routing',
    () async {
      final carouselSlots = _FakeCarouselSlotRepository(
        slots: [
          CarouselSlot(
            id: 'slot-1',
            slotNumber: 1,
            prescriptionId: 'prescription-1',
            scheduleId: 'schedule-1',
            profileId: 'profile-1',
            status: CarouselSlotStatus.loaded,
            createdAt: DateTime.utc(2026, 7, 8, 9),
            updatedAt: DateTime.utc(2026, 7, 8, 9),
          ),
        ],
      );
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 9, 5),
        scheduleHour: 9,
        scheduleMinute: 0,
        carouselSlots: carouselSlots,
      );
      addTearDown(fixture.close);

      await fixture.settle();
      final request = fixture.controller.requestDispenseForCurrentDose();
      await fixture.controllerGateway.requestStarted.future;

      expect(fixture.controllerLifecycle.lastSlotId, isNull);

      fixture.controllerGateway.completeDispense();
      await request;
    },
  );

  test(
    'dispense request rejects a completed current due dose when the next dose is still in the future',
    () async {
      final now = DateTime(2026, 7, 8, 9, 5);
      final fixture = await _RobotFaceControllerFixture.create(
        now: now,
        schedules: <ReminderSchedule>[
          _schedule(
            id: 'schedule-1',
            profileId: 'profile-1',
            hour: 9,
            minute: 0,
            now: now,
            label: 'Current meds',
          ),
          _schedule(
            id: 'schedule-2',
            profileId: 'profile-1',
            hour: 13,
            minute: 0,
            now: now,
            label: 'Later meds',
          ),
        ],
      );
      addTearDown(fixture.close);

      await fixture.settle();

      await fixture.doseLog.addEvent(
        DoseLogEvent.doseTakenConfirmed(
          doseId: 'schedule-1:2026-07-08',
          occurredAt: now.toUtc(),
        ),
      );

      final confirmedState = await fixture.controller.watchState().firstWhere(
        (state) => state.mode == RobotFaceMode.happyConfirmed,
      );

      expect(confirmedState.nextEventLabel, '09:00 · Current meds');

      expect(
        fixture.controller.requestDispenseForCurrentDose(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'No active dose is ready to dispense.',
          ),
        ),
      );
      expect(fixture.controllerGateway.requestedDoseIds, isEmpty);
    },
  );

  test('shows missed state for a terminal missed dose event', () async {
    final fixture = await _RobotFaceControllerFixture.create(
      now: DateTime(2026, 7, 8, 9, 5),
      scheduleHour: 9,
      scheduleMinute: 0,
    );
    addTearDown(fixture.close);

    await fixture.settle();

    await fixture.doseLog.addEvent(
      DoseLogEvent.doseMissed(
        doseId: fixture.currentDoseId,
        occurredAt: fixture.now.toUtc(),
      ),
    );

    final missedState = await fixture.controller.watchState().firstWhere(
      (state) => state.mode == RobotFaceMode.missed,
    );

    expect(missedState.nextEventLabel, '09:00 · Morning meds');
    expect(missedState.statusLabel, 'Dose missed');
  });

  test(
    'latest doseMissed shows missed alert with recognition action available',
    () async {
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 9, 5),
        scheduleHour: 9,
        scheduleMinute: 0,
      );
      addTearDown(fixture.close);

      await fixture.settle();

      await fixture.doseLog.addEvent(
        DoseLogEvent.doseMissed(
          doseId: fixture.currentDoseId,
          occurredAt: fixture.now.toUtc(),
        ),
      );

      final missedState = await fixture.controller.watchState().firstWhere(
        (state) => state.mode == RobotFaceMode.missed,
      );

      expect(missedState.actionDoseId, fixture.currentDoseId);
      expect(missedState.availableActions, <RobotFaceActionKind>{
        RobotFaceActionKind.recognizeMissedDose,
      });
      expect(missedState.statusLabel, 'Dose missed');
    },
  );

  for (final testCase
      in <
        ({ControllerSnapshot snapshot, RobotFaceControllerCondition condition})
      >[
        (
          snapshot: const ControllerSnapshot(
            connectionState: ControllerConnectionState.disconnected,
            canRequestDispense: false,
            statusLabel: 'Controller heartbeat missed',
            healthState: ControllerHealthState.offline,
          ),
          condition: RobotFaceControllerCondition.offline,
        ),
        (
          snapshot: const ControllerSnapshot(
            connectionState: ControllerConnectionState.error,
            canRequestDispense: false,
            statusLabel: 'Controller fault',
            healthState: ControllerHealthState.error,
            errorKind: ControllerErrorKind.other,
          ),
          condition: RobotFaceControllerCondition.fault,
        ),
      ]) {
    test(
      'active missed alert outranks ${testCase.condition.name} controller mode',
      () async {
        final fixture = await _RobotFaceControllerFixture.create(
          now: DateTime(2026, 7, 8, 9, 5),
          scheduleHour: 9,
          controllerSnapshot: testCase.snapshot,
        );
        addTearDown(fixture.close);

        await fixture.settle();
        await fixture.doseLog.addEvent(
          DoseLogEvent.doseMissed(
            doseId: fixture.currentDoseId,
            occurredAt: fixture.now.toUtc(),
          ),
        );
        await fixture.settle();

        final state = await fixture.controller.watchState().first;

        expect(state.mode, RobotFaceMode.missed);
        expect(state.controllerCondition, testCase.condition);
        expect(state.statusLabel, testCase.snapshot.statusLabel);
        expect(state.actionDoseId, fixture.currentDoseId);
        expect(state.availableActions, const <RobotFaceActionKind>{
          RobotFaceActionKind.recognizeMissedDose,
        });
      },
    );
  }

  test(
    'an unrecognized missed dose stays visible even after a later dose becomes due',
    () async {
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 13, 5),
        schedules: <ReminderSchedule>[
          _schedule(
            id: 'schedule-1',
            profileId: 'profile-1',
            hour: 9,
            minute: 0,
            now: DateTime(2026, 7, 8, 13, 5),
          ),
          _schedule(
            id: 'schedule-2',
            profileId: 'profile-1',
            hour: 13,
            minute: 0,
            now: DateTime(2026, 7, 8, 13, 5),
            label: 'Afternoon meds',
          ),
        ],
      );
      addTearDown(fixture.close);

      await fixture.settle();

      await fixture.doseLog.addEvent(
        DoseLogEvent.doseMissed(
          doseId: fixture.currentDoseId,
          occurredAt: DateTime(2026, 7, 8, 9, 5).toUtc(),
        ),
      );

      final missedState = await fixture.controller.watchState().firstWhere(
        (state) => state.mode == RobotFaceMode.missed,
      );

      expect(missedState.actionDoseId, fixture.currentDoseId);
      expect(missedState.nextEventLabel, '09:00 · Morning meds');
      expect(missedState.availableActions, <RobotFaceActionKind>{
        RobotFaceActionKind.recognizeMissedDose,
      });
    },
  );

  test('yesterday missed dose stays visible until recognition', () async {
    final fixture = await _RobotFaceControllerFixture.create(
      now: DateTime(2026, 7, 9, 8, 5),
      scheduleHour: 9,
      scheduleMinute: 0,
    );
    addTearDown(fixture.close);

    await fixture.settle();

    await fixture.doseLog.addEvent(
      DoseLogEvent.doseMissed(
        doseId: fixture.currentDoseId,
        occurredAt: DateTime(2026, 7, 8, 9, 5).toUtc(),
      ),
    );

    final missedState = await fixture.controller.watchState().firstWhere(
      (state) => state.mode == RobotFaceMode.missed,
    );

    expect(missedState.actionDoseId, fixture.currentDoseId);
    expect(missedState.nextEventLabel, '09:00 · Morning meds');
    expect(missedState.availableActions, <RobotFaceActionKind>{
      RobotFaceActionKind.recognizeMissedDose,
    });
  });

  test(
    'doseMissed followed by doseMissedRecognized clears the missed alert and recognition action',
    () async {
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 9, 5),
        schedules: <ReminderSchedule>[
          _schedule(
            id: 'schedule-1',
            profileId: 'profile-1',
            hour: 9,
            minute: 0,
            now: DateTime(2026, 7, 8, 9, 5),
          ),
          _schedule(
            id: 'schedule-2',
            profileId: 'profile-1',
            hour: 13,
            minute: 0,
            now: DateTime(2026, 7, 8, 9, 5),
            label: 'Afternoon meds',
          ),
        ],
      );
      addTearDown(fixture.close);

      await fixture.settle();

      await fixture.doseLog.addEvent(
        DoseLogEvent.doseMissed(
          doseId: fixture.currentDoseId,
          occurredAt: DateTime(2026, 7, 8, 9, 5).toUtc(),
        ),
      );
      await fixture.doseLog.addEvent(
        DoseLogEvent.doseMissedRecognized(
          doseId: fixture.currentDoseId,
          occurredAt: DateTime(2026, 7, 8, 9, 6).toUtc(),
        ),
      );

      final clearedState = await fixture.controller.watchState().firstWhere(
        (state) => state.nextEventLabel == '13:00 · Afternoon meds',
      );

      expect(clearedState.mode, RobotFaceMode.idle);
      expect(clearedState.actionDoseId, isNull);
      expect(clearedState.availableActions, isEmpty);
    },
  );

  test(
    'missed recognition does not revive confirm skip or help actions for that dose',
    () async {
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 9, 5),
        scheduleHour: 9,
        scheduleMinute: 0,
      );
      addTearDown(fixture.close);

      await fixture.settle();

      await fixture.doseLog.addEvent(
        DoseLogEvent.doseMissed(
          doseId: fixture.currentDoseId,
          occurredAt: DateTime(2026, 7, 8, 9, 5).toUtc(),
        ),
      );
      await fixture.doseLog.addEvent(
        DoseLogEvent.doseMissedRecognized(
          doseId: fixture.currentDoseId,
          occurredAt: DateTime(2026, 7, 8, 9, 6).toUtc(),
        ),
      );

      final recognizedState = await fixture.controller.watchState().firstWhere(
        (state) => state.mode == RobotFaceMode.idle,
      );

      expect(
        recognizedState.availableActions,
        isNot(
          containsAll(<RobotFaceActionKind>{
            RobotFaceActionKind.confirmTaken,
            RobotFaceActionKind.skipDose,
            RobotFaceActionKind.askForHelp,
          }),
        ),
      );
      expect(recognizedState.availableActions, isEmpty);
    },
  );

  test(
    'missed recognition keeps missed-dose status language and does not show taken copy',
    () async {
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 9, 5),
        scheduleHour: 9,
        scheduleMinute: 0,
      );
      addTearDown(fixture.close);

      await fixture.settle();

      await fixture.doseLog.addEvent(
        DoseLogEvent.doseMissed(
          doseId: fixture.currentDoseId,
          occurredAt: DateTime(2026, 7, 8, 9, 5).toUtc(),
        ),
      );
      await fixture.doseLog.addEvent(
        DoseLogEvent.doseMissedRecognized(
          doseId: fixture.currentDoseId,
          occurredAt: DateTime(2026, 7, 8, 9, 6).toUtc(),
        ),
      );

      final recognizedState = await fixture.controller.watchState().firstWhere(
        (state) => state.mode == RobotFaceMode.idle,
      );

      expect(recognizedState.statusLabel, isNot(contains('taken')));
      expect(recognizedState.statusLabel, contains('Missed'));
    },
  );

  test('robot face mode tone matches the MVP presentation mapping', () {
    expect(RobotFaceMode.idle.tone, RobotFaceTone.calm);
    expect(RobotFaceMode.sleepy.tone, RobotFaceTone.calm);
    expect(RobotFaceMode.doseReady.tone, RobotFaceTone.ready);
    expect(RobotFaceMode.dispensing.tone, RobotFaceTone.attention);
    expect(RobotFaceMode.waitingForConfirmation.tone, RobotFaceTone.ready);
    expect(RobotFaceMode.doseApproaching.tone, RobotFaceTone.attention);
    expect(RobotFaceMode.happyConfirmed.tone, RobotFaceTone.calm);
    expect(RobotFaceMode.missed.tone, RobotFaceTone.warning);
    expect(RobotFaceMode.error.tone, RobotFaceTone.warning);
    expect(RobotFaceMode.offline.tone, RobotFaceTone.offline);
  });

  test(
    'robot face mode contextual actions are only shown for live human-action states',
    () {
      expect(RobotFaceMode.idle.needsContextualAction, isFalse);
      expect(RobotFaceMode.sleepy.needsContextualAction, isFalse);
      expect(RobotFaceMode.doseApproaching.needsContextualAction, isFalse);
      expect(RobotFaceMode.doseReady.needsContextualAction, isTrue);
      expect(RobotFaceMode.dispensing.needsContextualAction, isFalse);
      expect(
        RobotFaceMode.waitingForConfirmation.needsContextualAction,
        isTrue,
      );
      expect(RobotFaceMode.happyConfirmed.needsContextualAction, isFalse);
      expect(RobotFaceMode.missed.needsContextualAction, isFalse);
      expect(RobotFaceMode.error.needsContextualAction, isFalse);
      expect(RobotFaceMode.offline.needsContextualAction, isFalse);
    },
  );

  test('robot face state equality and hashCode include actionDoseId', () {
    const baseState = RobotFaceState(
      mode: RobotFaceMode.doseReady,
      nextEventLabel: '09:00 · Morning meds',
      isFlipped: false,
      isLandscapeOnly: true,
      rampProgress: 1,
      isInAwakeWindow: true,
      statusLabel: 'Dose ready',
      actionDoseId: 'dose-1',
      voiceOccurrenceKey: 'schedule-1:2026-07-08',
    );

    const sameState = RobotFaceState(
      mode: RobotFaceMode.doseReady,
      nextEventLabel: '09:00 · Morning meds',
      isFlipped: false,
      isLandscapeOnly: true,
      rampProgress: 1,
      isInAwakeWindow: true,
      statusLabel: 'Dose ready',
      actionDoseId: 'dose-1',
      voiceOccurrenceKey: 'schedule-1:2026-07-08',
    );

    final differentActionDoseState = baseState.copyWith(actionDoseId: 'dose-2');
    final clearedActionDoseState = baseState.copyWith(actionDoseId: null);
    final differentVoiceOccurrenceState = baseState.copyWith(
      voiceOccurrenceKey: 'schedule-1:2026-07-09',
    );

    expect(baseState, sameState);
    expect(baseState.hashCode, sameState.hashCode);
    expect(differentActionDoseState, isNot(baseState));
    expect(differentActionDoseState.hashCode, isNot(baseState.hashCode));
    expect(differentVoiceOccurrenceState, isNot(baseState));
    expect(clearedActionDoseState.actionDoseId, isNull);
  });
}

ReminderSchedule _schedule({
  required String id,
  required String profileId,
  required int hour,
  required int minute,
  required DateTime now,
  String label = 'Morning meds',
}) {
  return ReminderSchedule(
    id: id,
    label: label,
    profileId: profileId,
    hour: hour,
    minute: minute,
    isEnabled: true,
    createdAt: now.toUtc(),
    updatedAt: now.toUtc(),
  );
}

class _RobotFaceControllerFixture {
  _RobotFaceControllerFixture({
    required this.database,
    required this.doseLog,
    required this.controller,
    required this.controllerGateway,
    required this.controllerLifecycle,
    required this.currentDoseId,
    required this.nowGetter,
    required this._setNow,
  });

  final DoseyDatabase database;
  final _FakeDoseLogRepository doseLog;
  final RobotFaceController controller;
  final _FakeControllerGateway controllerGateway;
  final _FakeControllerLifecycleService controllerLifecycle;
  final String currentDoseId;
  final DateTime Function() nowGetter;
  final void Function(DateTime value) _setNow;

  DateTime get now => nowGetter();

  static Future<_RobotFaceControllerFixture> create({
    required DateTime now,
    int scheduleHour = 10,
    int scheduleMinute = 0,
    List<ReminderSchedule>? schedules,
    RobotFaceSettings robotFaceSettings = const RobotFaceSettings(),
    ScheduleProfile? activeProfile,
    bool emitDefaultActiveProfile = true,
    Stream<DateTime>? clock,
    Stream<ConnectivityState>? connectivity,
    Stream<List<MedicationShortageAlertRow>>? shortageAlerts,
    CarouselSlotRepository? carouselSlots,
    ControllerSnapshot controllerSnapshot = const ControllerSnapshot.online(),
  }) async {
    final database = DoseyDatabase.inMemory();
    final settings = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidRobot,
    );
    final robotFaceSettingsRepository = RobotFaceSettingsRepository(database);
    final profiles = _FakeScheduleProfileRepository();
    final reminders = _FakeReminderRepository();
    final doseLog = _FakeDoseLogRepository();
    final slotRepository = carouselSlots ?? _FakeCarouselSlotRepository();
    final controllerGateway = _FakeControllerGateway(controllerSnapshot);
    final controllerLifecycle = _FakeControllerLifecycleService(
      controllerGateway: controllerGateway,
    );
    var currentNow = now;

    await settings.setDeviceRole(AppDeviceRole.androidRobot);
    await robotFaceSettingsRepository.saveSettings(robotFaceSettings);
    if (activeProfile != null || emitDefaultActiveProfile) {
      profiles.emit(
        activeProfile ??
            ScheduleProfile(
              id: 'profile-1',
              name: 'Default',
              isActive: true,
              createdAt: now.toUtc(),
              updatedAt: now.toUtc(),
            ),
      );
    }
    reminders.emit(
      schedules ??
          <ReminderSchedule>[
            _schedule(
              id: 'schedule-1',
              profileId: 'profile-1',
              hour: scheduleHour,
              minute: scheduleMinute,
              now: now,
            ),
          ],
    );

    final robotFaceController = RobotFaceController(
      settings: settings,
      robotFaceSettings: robotFaceSettingsRepository,
      controller: controllerGateway,
      controllerLifecycle: controllerLifecycle,
      scheduleProfiles: profiles,
      reminders: reminders,
      doseLog: doseLog,
      carouselSlots: slotRepository,
      shortageAlerts: shortageAlerts,
      connectivity: connectivity,
      clock: clock,
      now: () => currentNow,
    );

    return _RobotFaceControllerFixture(
      database: database,
      doseLog: doseLog,
      controller: robotFaceController,
      controllerGateway: controllerGateway,
      controllerLifecycle: controllerLifecycle,
      currentDoseId: 'schedule-1:2026-07-08',
      nowGetter: () => currentNow,
      setNow: (value) {
        currentNow = value;
      },
    );
  }

  set now(DateTime value) => _setNow(value);

  Future<void> settle() => pumpEventQueue();

  Future<void> close() async {
    await controller.close();
    await controllerGateway.close();
    await database.close();
  }
}

class _FakeControllerGateway implements ControllerGateway {
  _FakeControllerGateway(this._snapshot);

  final _controller = StreamController<ControllerSnapshot>.broadcast();
  ControllerSnapshot _snapshot;
  final List<String> requestedDoseIds = <String>[];
  final requestStarted = Completer<void>();
  Completer<void>? _dispenseCompleter;

  @override
  Future<void> cancelActiveCommand() async {}

  @override
  Future<void> close() async {
    await _controller.close();
  }

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> requestDispense({required String doseId}) async {
    requestedDoseIds.add(doseId);
    if (!requestStarted.isCompleted) {
      requestStarted.complete();
    }
    final completer = Completer<void>();
    _dispenseCompleter = completer;
    await completer.future;
  }

  void completeDispense() {
    _dispenseCompleter?.complete();
    _dispenseCompleter = null;
  }

  void emitSnapshot(ControllerSnapshot snapshot) {
    _snapshot = snapshot;
    _controller.add(snapshot);
  }

  @override
  Stream<ControllerSnapshot> watchController() async* {
    yield _snapshot;
    yield* _controller.stream;
  }
}

class _FakeControllerLifecycleService implements ControllerLifecycleService {
  _FakeControllerLifecycleService({required this.controllerGateway});

  final _FakeControllerGateway controllerGateway;
  String? lastSlotId;

  @override
  DoseyDatabase? get database => null;

  @override
  LocalGuidedCarouselLoadRepository? get guidedCarouselLoads => null;

  @override
  Future<void> requestDoseDispense({
    required String doseId,
    String? slotId,
    String? scheduleId,
  }) {
    lastSlotId = slotId;
    return controllerGateway.requestDispense(doseId: doseId);
  }

  @override
  Future<void> requestManualDispenseTest() async {}

  @override
  Future<void> requestManualServoTest() async {}
}

class _FakeCarouselSlotRepository implements CarouselSlotRepository {
  _FakeCarouselSlotRepository({this.slots = const <CarouselSlot>[]});

  final List<CarouselSlot> slots;

  @override
  Future<void> assignSlot(
    CarouselSlot slot, {
    AdminAuditEvent? auditEvent,
  }) async {}

  @override
  Future<void> clearProfile(String profileId) async {}

  @override
  Future<void> clearSlot(String id) async {}

  @override
  Future<void> markDispensed(String id) async {}

  @override
  Future<void> markLoaded(String id, {AdminAuditEvent? auditEvent}) async {}

  @override
  Future<void> markNeedsReview(
    String id, {
    AdminAuditEvent? auditEvent,
  }) async {}

  @override
  Stream<List<CarouselSlot>> watchSlots({String? profileId}) async* {
    yield profileId == null
        ? slots
        : slots.where((slot) => slot.profileId == profileId).toList();
  }
}

class _FakeDoseLogRepository implements DoseLogRepository {
  final _controller = StreamController<List<DoseLogEvent>>.broadcast();
  final List<DoseLogEvent> _events = <DoseLogEvent>[];

  List<DoseLogEvent> get events => List<DoseLogEvent>.unmodifiable(_events);

  @override
  Future<void> addEvent(DoseLogEvent event) async {
    _events.insert(0, event);
    _controller.add(List<DoseLogEvent>.unmodifiable(_events));
  }

  @override
  Stream<List<DoseLogEvent>> watchEvents() async* {
    yield List<DoseLogEvent>.unmodifiable(_events);
    yield* _controller.stream;
  }
}

class _FakeReminderRepository implements ReminderRepository {
  final _controller = StreamController<List<ReminderSchedule>>.broadcast();
  List<ReminderSchedule> _schedules = const <ReminderSchedule>[];

  void emit(List<ReminderSchedule> schedules) {
    _schedules = List<ReminderSchedule>.unmodifiable(schedules);
  }

  @override
  Future<int> deleteSchedule(String id, {AdminAuditEvent? auditEvent}) async =>
      1;

  @override
  Future<void> upsertSchedule(
    ReminderSchedule schedule, {
    AdminAuditEvent? auditEvent,
  }) async {}

  @override
  Stream<List<ReminderSchedule>> watchSchedules({String? profileId}) async* {
    yield _filtered(profileId);
    yield* _controller.stream.map((_) => _filtered(profileId));
  }

  List<ReminderSchedule> _filtered(String? profileId) {
    if (profileId == null) {
      return _schedules;
    }
    return _schedules
        .where((schedule) => schedule.profileId == profileId)
        .toList();
  }
}

class _FakeScheduleProfileRepository implements ScheduleProfileRepository {
  final _controller = StreamController<ScheduleProfile?>.broadcast();
  ScheduleProfile? _profile;

  void emit(ScheduleProfile? profile) {
    _profile = profile;
  }

  @override
  Future<void> setActiveProfile(
    String id, {
    AdminAuditEvent? auditEvent,
  }) async {}

  @override
  Future<void> upsertProfile(
    ScheduleProfile profile, {
    AdminAuditEvent? auditEvent,
  }) async {}

  @override
  Stream<ScheduleProfile?> watchActiveProfile() async* {
    yield _profile;
    yield* _controller.stream;
  }

  @override
  Stream<List<ScheduleProfile>> watchProfiles() async* {
    yield _profile == null
        ? const <ScheduleProfile>[]
        : <ScheduleProfile>[_profile!];
  }
}

String _localTimeLabel(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
