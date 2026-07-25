import 'dart:async';

import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:dosey_app/core/connectivity/connectivity_gateway.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/controller/controller_lifecycle_service.dart';
import 'package:dosey_app/core/controller/local_controller_command_repository.dart';
import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/missed_dose_reconciliation_service.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/schedules/local_schedule_profile_repository.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/time/app_clock.dart';
import 'package:dosey_app/features/robot_face/robot_face_controller.dart';
import 'package:dosey_app/features/robot_face/robot_face_canvas.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings_repository.dart';
import 'package:dosey_app/features/robot_face/robot_face_screen.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';
import 'package:dosey_app/features/today/today_next_dose_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders large eyes and next event card', (
    WidgetTester tester,
  ) async {
    final states = StreamController<RobotFaceState>.broadcast();
    addTearDown(states.close);

    await tester.pumpWidget(
      _RobotFaceTestApp(
        stateStream: states.stream,
        initialState: const RobotFaceState(
          mode: RobotFaceMode.idle,
          nextEventLabel: '8:00 PM · Evening meds',
          isFlipped: false,
          isLandscapeOnly: true,
          rampProgress: 0,
          isInAwakeWindow: false,
          statusLabel: 'Controller connected',
        ),
      ),
    );

    await tester.pump();

    expect(find.byKey(RobotFaceScreen.canvasKey), findsOneWidget);
    expect(find.byKey(RobotFaceScreen.bottomCardKey), findsOneWidget);
    expect(find.text('8:00 PM · Evening meds'), findsOneWidget);
    expect(find.text('Controller connected'), findsOneWidget);

    final canvasSize = tester.getSize(find.byKey(RobotFaceScreen.canvasKey));
    final cardSize = tester.getSize(find.byKey(RobotFaceScreen.bottomCardKey));
    expect(canvasSize.height, greaterThan(cardSize.height * 2));
  });

  testWidgets('applies flipped transform when flipped', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const _RobotFaceTestApp(
        key: ValueKey<String>('soon-state'),
        initialState: RobotFaceState(
          mode: RobotFaceMode.idle,
          nextEventLabel: 'No reminders scheduled',
          isFlipped: true,
          isLandscapeOnly: true,
          rampProgress: 0,
          isInAwakeWindow: false,
        ),
      ),
    );

    await tester.pump();

    final transform = tester.widget<Transform>(
      find.byKey(RobotFaceScreen.flipTransformKey),
    );
    expect(transform.transform.storage[0], lessThan(0));
    expect(transform.transform.storage[5], lessThan(0));
  });

  testWidgets('shows a larger urgent prompt for dose ready state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const _RobotFaceTestApp(
        key: ValueKey<String>('ready-state'),
        initialState: RobotFaceState(
          mode: RobotFaceMode.doseReady,
          nextEventLabel: 'Now · Morning meds',
          isFlipped: false,
          isLandscapeOnly: true,
          rampProgress: 1,
          isInAwakeWindow: true,
          statusLabel: 'Ready to dispense',
        ),
      ),
    );

    await tester.pump();

    final urgentPrompt = tester.widget<Text>(
      find.byKey(RobotFaceScreen.urgentPromptKey),
    );
    expect(urgentPrompt.data, 'READY');
    expect(urgentPrompt.style?.fontSize, lessThanOrEqualTo(20));
    expect(find.text('Ready to dispense'), findsNothing);
    expect(find.text('Ready now'), findsOneWidget);
  });

  testWidgets('updates from later state stream events', (
    WidgetTester tester,
  ) async {
    final states = StreamController<RobotFaceState>.broadcast();
    addTearDown(states.close);

    await tester.pumpWidget(
      _RobotFaceTestApp(
        stateStream: states.stream,
        initialState: const RobotFaceState(
          mode: RobotFaceMode.idle,
          nextEventLabel: '8:00 PM · Evening meds',
          isFlipped: false,
          isLandscapeOnly: true,
          rampProgress: 0,
          isInAwakeWindow: false,
          statusLabel: 'Controller connected',
        ),
      ),
    );

    states.add(
      const RobotFaceState(
        mode: RobotFaceMode.offline,
        nextEventLabel: 'No reminders scheduled',
        isFlipped: false,
        isLandscapeOnly: true,
        rampProgress: 0,
        isInAwakeWindow: false,
        statusLabel: 'Robot Face unavailable',
      ),
    );

    await tester.pump();

    expect(find.text('No reminders scheduled'), findsOneWidget);
    expect(find.text('Reconnect needed'), findsOneWidget);
    expect(find.text('Controller connected'), findsNothing);
  });

  testWidgets('keeps urgent treatment compact and face first', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const _RobotFaceTestApp(
        initialState: RobotFaceState(
          mode: RobotFaceMode.doseApproaching,
          nextEventLabel: '8:00 PM · Evening meds',
          isFlipped: false,
          isLandscapeOnly: true,
          rampProgress: 0.55,
          isInAwakeWindow: true,
          statusLabel: 'Dispense soon',
        ),
      ),
    );

    await tester.pump();

    expect(find.byKey(RobotFaceScreen.urgentPromptKey), findsOneWidget);
    expect(find.text('SOON'), findsOneWidget);
    expect(find.text('Dispense soon'), findsNothing);
    expect(find.text('Coming up'), findsOneWidget);
    expect(find.text('Dose ready'), findsNothing);
    expect(find.text('Need help'), findsNothing);
  });

  testWidgets('pins shortage details inside the robot face status card', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const _RobotFaceTestApp(
        initialState: RobotFaceState(
          mode: RobotFaceMode.idle,
          nextEventLabel: '10:00 · Morning meds',
          isFlipped: false,
          isLandscapeOnly: true,
          rampProgress: 0,
          isInAwakeWindow: false,
          hasPinnedShortageAlert: true,
          activeShortageLabel: 'Urgent shortage · slot 2',
          activeShortageMedicationLabel: 'Vitamin D',
          activeShortageScheduledLabel: '10:00',
          activeShortageSlotNumber: 2,
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Urgent shortage'), findsOneWidget);
    expect(find.text('Vitamin D'), findsOneWidget);
    expect(find.text('Scheduled 10:00'), findsOneWidget);
    expect(find.text('Slot 2'), findsOneWidget);
    expect(
      find.text(
        'Local-only alert on this phone. Open Carousel to review loading before the next dispense.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Pinned until loading is handled on this phone.'),
      findsOneWidget,
    );
  });

  testWidgets('passes activity state through to the canvas', (
    WidgetTester tester,
  ) async {
    final canvasKey = GlobalKey();

    await tester.pumpWidget(
      _RobotFaceTestApp(
        key: canvasKey,
        isActive: false,
        initialState: RobotFaceState(
          mode: RobotFaceMode.idle,
          nextEventLabel: 'No reminders scheduled',
          isFlipped: false,
          isLandscapeOnly: true,
          rampProgress: 0,
          isInAwakeWindow: false,
        ),
      ),
    );

    await tester.pump();

    final canvas = tester.widget<RobotFaceCanvas>(find.byType(RobotFaceCanvas));
    expect(canvas.isActive, isFalse);
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(
      _RobotFaceTestApp(
        key: canvasKey,
        isActive: true,
        initialState: const RobotFaceState(
          mode: RobotFaceMode.idle,
          nextEventLabel: 'No reminders scheduled',
          isFlipped: false,
          isLandscapeOnly: true,
          rampProgress: 0,
          isInAwakeWindow: false,
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1300));

    final dynamic state = tester.state(find.byType(RobotFaceCanvas));
    final resumedPhase = state.debugPhase as double;

    expect(tester.hasRunningAnimations, isTrue);
    expect(resumedPhase, closeTo(0.25, 0.05));

    await tester.pump(const Duration(milliseconds: 4100));

    final loopedPhase = state.debugPhase as double;
    expect(loopedPhase, closeTo(0.04, 0.03));
  });

  testWidgets('ramps compact urgency between soon and ready states', (
    WidgetTester tester,
  ) async {
    final states = StreamController<RobotFaceState>.broadcast();
    addTearDown(states.close);

    await tester.pumpWidget(
      _RobotFaceTestApp(
        stateStream: states.stream,
        initialState: RobotFaceState(
          mode: RobotFaceMode.doseApproaching,
          nextEventLabel: '8:00 PM · Evening meds',
          isFlipped: false,
          isLandscapeOnly: true,
          rampProgress: 0.2,
          isInAwakeWindow: true,
          statusLabel: 'Dispense soon',
        ),
      ),
    );

    await tester.pump();

    final soonScale = tester.widget<AnimatedScale>(
      find.byKey(RobotFaceScreen.urgentPromptScaleKey),
    );
    final soonBadge = tester.widget<DecoratedBox>(
      find.byKey(RobotFaceScreen.statusBadgeKey),
    );
    final soonBorder =
        (soonBadge.decoration as BoxDecoration).border! as Border;

    states.add(
      const RobotFaceState(
        mode: RobotFaceMode.doseReady,
        nextEventLabel: 'Now · Morning meds',
        isFlipped: false,
        isLandscapeOnly: true,
        rampProgress: 1,
        isInAwakeWindow: true,
        statusLabel: 'Ready to dispense',
      ),
    );

    await tester.pump();

    final readyScale = tester.widget<AnimatedScale>(
      find.byKey(RobotFaceScreen.urgentPromptScaleKey),
    );
    final readyBadge = tester.widget<DecoratedBox>(
      find.byKey(RobotFaceScreen.statusBadgeKey),
    );
    final readyBorder =
        (readyBadge.decoration as BoxDecoration).border! as Border;

    expect(soonScale.scale, greaterThan(1));
    expect(readyScale.scale, greaterThan(soonScale.scale));
    expect(readyBorder.top.color.a, greaterThan(soonBorder.top.color.a));
  });

  testWidgets('uses green ready-tone badge accents for ready path states', (
    WidgetTester tester,
  ) async {
    final states = StreamController<RobotFaceState>.broadcast();
    addTearDown(states.close);

    await tester.pumpWidget(
      _RobotFaceTestApp(
        stateStream: states.stream,
        initialState: const RobotFaceState(
          mode: RobotFaceMode.doseReady,
          nextEventLabel: 'Now · Morning meds',
          isFlipped: false,
          isLandscapeOnly: true,
          rampProgress: 1,
          isInAwakeWindow: true,
          statusLabel: 'Ready to dispense',
        ),
      ),
    );

    await tester.pump();

    BoxDecoration readyDecoration() =>
        tester
                .widget<DecoratedBox>(
                  find.byKey(RobotFaceScreen.statusBadgeKey),
                )
                .decoration
            as BoxDecoration;

    final readyBorder = readyDecoration().border! as Border;
    expect(readyBorder.top.color.g, greaterThan(readyBorder.top.color.r));
    expect(readyBorder.top.color.b, greaterThan(readyBorder.top.color.r));

    states.add(
      const RobotFaceState(
        mode: RobotFaceMode.waitingForConfirmation,
        nextEventLabel: 'Taken? · Morning meds',
        isFlipped: false,
        isLandscapeOnly: true,
        rampProgress: 1,
        isInAwakeWindow: true,
        statusLabel: 'Waiting for confirmation',
      ),
    );

    await tester.pump();

    final waitingBorder = readyDecoration().border! as Border;
    expect(waitingBorder.top.color.g, greaterThan(waitingBorder.top.color.r));
    expect(waitingBorder.top.color.b, greaterThan(waitingBorder.top.color.r));
    expect(waitingBorder.top.color.a, lessThan(readyBorder.top.color.a));
  });

  testWidgets('uses ready-tone urgent prompt accents for dose ready state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const _RobotFaceTestApp(
        initialState: RobotFaceState(
          mode: RobotFaceMode.doseReady,
          nextEventLabel: 'Now · Morning meds',
          isFlipped: false,
          isLandscapeOnly: true,
          rampProgress: 1,
          isInAwakeWindow: true,
          statusLabel: 'Ready to dispense',
        ),
      ),
    );

    await tester.pump();

    final promptDecoration =
        tester
                .widgetList<DecoratedBox>(
                  find.ancestor(
                    of: find.byKey(RobotFaceScreen.urgentPromptKey),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .first
                .decoration
            as BoxDecoration;
    final promptBorder = promptDecoration.border! as Border;

    expect(promptBorder.top.color.g, greaterThan(promptBorder.top.color.r));
    expect(promptBorder.top.color.b, greaterThan(promptBorder.top.color.r));
  });

  testWidgets('shows alert support badge in awake idle window', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const _RobotFaceTestApp(
        initialState: RobotFaceState(
          mode: RobotFaceMode.idle,
          nextEventLabel: '8:00 PM · Evening meds',
          isFlipped: false,
          isLandscapeOnly: true,
          rampProgress: 0,
          isInAwakeWindow: true,
          statusLabel: 'Controller connected',
        ),
      ),
    );

    await tester.pump();

    final badge = tester.widget<DecoratedBox>(
      find.byKey(RobotFaceScreen.statusBadgeKey),
    );
    final border = (badge.decoration as BoxDecoration).border! as Border;

    expect(find.text('Controller connected'), findsOneWidget);
    expect(border.top.color.a, greaterThan(0.08));
  });

  testWidgets('gives awake idle frame brighter treatment than sleepy mode', (
    WidgetTester tester,
  ) async {
    final states = StreamController<RobotFaceState>.broadcast();
    addTearDown(states.close);

    await tester.pumpWidget(
      _RobotFaceTestApp(
        stateStream: states.stream,
        initialState: const RobotFaceState(
          mode: RobotFaceMode.sleepy,
          nextEventLabel: 'No reminders scheduled',
          isFlipped: false,
          isLandscapeOnly: true,
          rampProgress: 0,
          isInAwakeWindow: false,
          statusLabel: 'Sleep mode',
        ),
      ),
    );

    await tester.pump();

    BoxDecoration frameDecoration() =>
        tester
                .widget<AnimatedContainer>(
                  find.byKey(RobotFaceScreen.displayFrameKey),
                )
                .decoration!
            as BoxDecoration;

    final sleepyBorder = frameDecoration().border! as Border;

    states.add(
      const RobotFaceState(
        mode: RobotFaceMode.idle,
        nextEventLabel: '8:00 PM · Evening meds',
        isFlipped: false,
        isLandscapeOnly: true,
        rampProgress: 0,
        isInAwakeWindow: true,
        statusLabel: 'Controller connected',
      ),
    );

    await tester.pump();

    final awakeBorder = frameDecoration().border! as Border;

    expect(awakeBorder.top.color.g, greaterThan(sleepyBorder.top.color.g));
    expect(awakeBorder.top.color.b, greaterThan(sleepyBorder.top.color.b));
  });

  testWidgets('shows red missed-dose treatment and safe copy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const _RobotFaceTestApp(
        initialState: RobotFaceState(
          mode: RobotFaceMode.missed,
          nextEventLabel: '8:00 AM · Morning meds',
          isFlipped: false,
          isLandscapeOnly: true,
          rampProgress: 1,
          isInAwakeWindow: true,
          statusLabel: 'Missed dose alert',
          actionDoseId: 'dose-123',
          availableActions: {RobotFaceActionKind.recognizeMissedDose},
        ),
      ),
    );

    await tester.pump();

    expect(find.text('MISSED'), findsWidgets);
    expect(find.text('This dose was missed.'), findsOneWidget);
    expect(
      find.text(
        'Follow your prescription instructions or ask your caregiver, pharmacist, or doctor.',
      ),
      findsOneWidget,
    );

    final badge = tester.widget<DecoratedBox>(
      find.byKey(RobotFaceScreen.statusBadgeKey),
    );
    final border = (badge.decoration as BoxDecoration).border! as Border;
    final displayFrame = tester.widget<AnimatedContainer>(
      find.byKey(RobotFaceScreen.displayFrameKey),
    );
    final displayBorder =
        (displayFrame.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color.r, greaterThan(border.top.color.g));
    expect(displayBorder.top.color.r, greaterThan(displayBorder.top.color.b));
  });

  testWidgets(
    'shows missed-dose recognition button for actionable missed state',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const _RobotFaceTestApp(
          initialState: RobotFaceState(
            mode: RobotFaceMode.missed,
            nextEventLabel: '8:00 AM · Morning meds',
            isFlipped: false,
            isLandscapeOnly: true,
            rampProgress: 1,
            isInAwakeWindow: true,
            statusLabel: 'Missed dose alert',
            actionDoseId: 'dose-123',
            availableActions: {RobotFaceActionKind.recognizeMissedDose},
          ),
        ),
      );

      await tester.pump();

      expect(find.byKey(RobotFaceScreen.actionPanelKey), findsOneWidget);
      expect(
        find.byKey(RobotFaceScreen.recognizeMissedDoseButtonKey),
        findsOneWidget,
      );
      expect(find.byKey(RobotFaceScreen.confirmTakenButtonKey), findsNothing);
      expect(find.byKey(RobotFaceScreen.skipDoseButtonKey), findsNothing);
      expect(find.byKey(RobotFaceScreen.needHelpButtonKey), findsNothing);
    },
  );

  testWidgets(
    'hides missed-dose recognition button when the missed state is not actionable',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const _RobotFaceTestApp(
          initialState: RobotFaceState(
            mode: RobotFaceMode.missed,
            nextEventLabel: '8:00 AM · Morning meds',
            isFlipped: false,
            isLandscapeOnly: true,
            rampProgress: 1,
            isInAwakeWindow: true,
            statusLabel: 'Missed dose alert',
            actionDoseId: 'dose-123',
            availableActions: <RobotFaceActionKind>{},
          ),
        ),
      );

      await tester.pump();

      expect(
        find.byKey(RobotFaceScreen.recognizeMissedDoseButtonKey),
        findsNothing,
      );
    },
  );

  testWidgets('logs missed-dose recognition without marking the dose taken', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    const scheduleId = 'schedule-1';
    final doseId = TodayNextDoseHelper.doseIdForDate(
      scheduleId,
      DateTime(2026, 7, 8, 9, 5),
    );
    await DriftDoseLogRepository(database).addEvent(
      DoseLogEvent.doseMissed(
        doseId: doseId,
        occurredAt: DateTime(2026, 7, 8, 9, 5).toUtc(),
      ),
    );

    await tester.pumpWidget(
      DoseyAppScope(
        database: database,
        reminderScheduler: _FakeReminderScheduler(),
        permissionGateway: _FakePermissionGateway(),
        missedDoseReconciliationService: _FakeMissedDoseReconciliationService(),
        bleGateway: _FakeBleGateway(),
        connectivityGateway: _FakeConnectivityGateway(),
        child: MaterialApp(
          home: RobotFaceScreen(
            initialState: RobotFaceState(
              mode: RobotFaceMode.missed,
              nextEventLabel: '8:00 AM · Morning meds',
              isFlipped: false,
              isLandscapeOnly: true,
              rampProgress: 1,
              isInAwakeWindow: true,
              statusLabel: 'Missed dose alert',
              actionDoseId: doseId,
              availableActions: const {RobotFaceActionKind.recognizeMissedDose},
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.byKey(RobotFaceScreen.recognizeMissedDoseButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final events = await (database.select(
      database.doseLogEvents,
    )..where((row) => row.doseId.equals(doseId))).get();

    expect(events, hasLength(2));
    expect(
      events.map((event) => event.kind),
      containsAll(<String>[
        DoseLogEventKind.doseMissed.name,
        DoseLogEventKind.doseMissedRecognized.name,
      ]),
    );
    final recognizedEvent = events.firstWhere(
      (event) => event.kind == DoseLogEventKind.doseMissedRecognized.name,
    );
    expect(recognizedEvent.marksDoseTaken, isFalse);
    expect(find.text('Missed dose noted.'), findsOneWidget);
    expect(find.text('Dose already logged for today.'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'tapping the face with a missed alert only records interaction until the explicit button is tapped',
    (WidgetTester tester) async {
      final doseActionLogger = _FakeRobotFaceDoseActionLogger();
      const state = RobotFaceState(
        mode: RobotFaceMode.missed,
        nextEventLabel: '8:00 AM · Morning meds',
        isFlipped: false,
        isLandscapeOnly: true,
        rampProgress: 1,
        isInAwakeWindow: true,
        statusLabel: 'Missed dose alert',
        actionDoseId: 'dose-123',
        availableActions: {RobotFaceActionKind.recognizeMissedDose},
      );

      await tester.pumpWidget(
        _RobotFaceTestApp(
          doseActionLogger: doseActionLogger.call,
          initialState: state,
        ),
      );

      await tester.pump();
      await tester.tapAt(
        tester.getCenter(find.byKey(RobotFaceScreen.canvasKey)),
      );
      await tester.pump();

      expect(doseActionLogger.events, isEmpty);
      expect(find.text('Missed dose noted.'), findsNothing);

      await tester.tap(
        find.byKey(RobotFaceScreen.recognizeMissedDoseButtonKey),
      );
      await tester.pump();

      expect(doseActionLogger.events, hasLength(1));
      expect(
        doseActionLogger.events.single.kind,
        DoseLogEventKind.doseMissedRecognized,
      );
      expect(find.text('Missed dose noted.'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the Robot Face display records interaction through an injected controller',
    (WidgetTester tester) async {
      final harness = _RobotFaceInteractionControllerHarness();
      addTearDown(harness.dispose);

      await tester.pumpWidget(
        _RobotFaceTestApp(controller: harness.controller),
      );

      await tester.pump();
      harness.advance(const Duration(minutes: 31));
      await tester.pump();

      expect(find.text('Sleep mode'), findsOneWidget);

      await tester.tapAt(
        tester.getCenter(find.byKey(RobotFaceScreen.canvasKey)),
      );
      await tester.pump();

      expect(find.text('Sleep mode'), findsNothing);
      expect(find.text('No active reminder'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the Robot Face display records interaction through the app-owned controller',
    (WidgetTester tester) async {
      final harness = _RobotFaceInteractionControllerHarness();
      addTearDown(harness.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: RobotFaceScreen(controllerResolver: (_) => harness.controller),
        ),
      );

      await tester.pump();
      harness.advance(const Duration(minutes: 31));
      await tester.pump();

      expect(find.text('Sleep mode'), findsOneWidget);

      await tester.tapAt(
        tester.getCenter(find.byKey(RobotFaceScreen.canvasKey)),
      );
      await tester.pump();

      expect(find.text('Sleep mode'), findsNothing);
      expect(find.text('No active reminder'), findsOneWidget);
    },
  );

  testWidgets('hides action panel for idle state without actionable dose', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const _RobotFaceTestApp(
        initialState: RobotFaceState(
          mode: RobotFaceMode.idle,
          nextEventLabel: '8:00 PM · Evening meds',
          isFlipped: false,
          isLandscapeOnly: true,
          rampProgress: 0,
          isInAwakeWindow: false,
          statusLabel: 'Controller connected',
        ),
      ),
    );

    await tester.pump();

    expect(find.byKey(RobotFaceScreen.actionPanelKey), findsNothing);
  });

  testWidgets('shows contextual actions only for actionable dose states', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const _RobotFaceTestApp(
        initialState: RobotFaceState(
          mode: RobotFaceMode.doseReady,
          nextEventLabel: 'Now · Morning meds',
          isFlipped: false,
          isLandscapeOnly: true,
          rampProgress: 1,
          isInAwakeWindow: true,
          statusLabel: 'Ready to dispense',
          actionDoseId: 'dose-123',
          availableActions: {
            RobotFaceActionKind.confirmTaken,
            RobotFaceActionKind.skipDose,
            RobotFaceActionKind.askForHelp,
          },
        ),
      ),
    );

    await tester.pump();

    expect(find.byKey(RobotFaceScreen.actionPanelKey), findsOneWidget);
    expect(find.byKey(RobotFaceScreen.confirmTakenButtonKey), findsOneWidget);
    expect(find.byKey(RobotFaceScreen.skipDoseButtonKey), findsOneWidget);
    expect(find.byKey(RobotFaceScreen.needHelpButtonKey), findsOneWidget);
  });

  testWidgets(
    'keeps contextual actions visible for actionable offline follow-up states',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const _RobotFaceTestApp(
          initialState: RobotFaceState(
            mode: RobotFaceMode.offline,
            nextEventLabel: 'Taken? · Morning meds',
            isFlipped: false,
            isLandscapeOnly: true,
            rampProgress: 1,
            isInAwakeWindow: true,
            statusLabel: 'Controller disconnected',
            actionDoseId: 'dose-123',
            availableActions: {
              RobotFaceActionKind.confirmTaken,
              RobotFaceActionKind.skipDose,
              RobotFaceActionKind.askForHelp,
            },
          ),
        ),
      );

      await tester.pump();

      expect(find.byKey(RobotFaceScreen.actionPanelKey), findsOneWidget);
      expect(find.byKey(RobotFaceScreen.confirmTakenButtonKey), findsOneWidget);
      expect(find.byKey(RobotFaceScreen.skipDoseButtonKey), findsOneWidget);
      expect(find.byKey(RobotFaceScreen.needHelpButtonKey), findsOneWidget);
    },
  );

  testWidgets('logs confirm taken action and prevents repeat confirm', (
    WidgetTester tester,
  ) async {
    final doseActionLogger = _FakeRobotFaceDoseActionLogger(
      delayCompletion: true,
    );

    await tester.pumpWidget(
      _RobotFaceTestApp(
        doseActionLogger: doseActionLogger.call,
        initialState: const RobotFaceState(
          mode: RobotFaceMode.doseReady,
          nextEventLabel: 'Now · Morning meds',
          isFlipped: false,
          isLandscapeOnly: true,
          rampProgress: 1,
          isInAwakeWindow: true,
          statusLabel: 'Ready to dispense',
          actionDoseId: 'dose-123',
          availableActions: {
            RobotFaceActionKind.confirmTaken,
            RobotFaceActionKind.skipDose,
            RobotFaceActionKind.askForHelp,
          },
        ),
      ),
    );

    await tester.pump();

    final buttonFinder = find.byKey(RobotFaceScreen.confirmTakenButtonKey);
    expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNotNull);

    await tester.tap(buttonFinder);
    await tester.pump();

    expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNull);

    doseActionLogger.completePendingLog();
    await tester.pump();

    expect(doseActionLogger.events, hasLength(1));
    expect(
      doseActionLogger.events.single.kind,
      DoseLogEventKind.doseTakenConfirmed,
    );
    expect(doseActionLogger.events.single.doseId, 'dose-123');
    expect(doseActionLogger.events.single.marksDoseTaken, isTrue);

    expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNull);
    expect(find.text('Taken logged.'), findsOneWidget);
  });

  for (final testCase
      in <
        ({
          String label,
          Key buttonKey,
          RobotFaceState state,
          DoseLogEventKind expectedKind,
        })
      >[
        (
          label: 'confirm taken',
          buttonKey: RobotFaceScreen.confirmTakenButtonKey,
          state: const RobotFaceState(
            mode: RobotFaceMode.waitingForConfirmation,
            nextEventLabel: 'Taken? · Morning meds',
            isFlipped: false,
            isLandscapeOnly: true,
            rampProgress: 1,
            isInAwakeWindow: true,
            actionDoseId: 'demo-dose',
            availableActions: {RobotFaceActionKind.confirmTaken},
          ),
          expectedKind: DoseLogEventKind.doseTakenConfirmed,
        ),
        (
          label: 'skip',
          buttonKey: RobotFaceScreen.skipDoseButtonKey,
          state: const RobotFaceState(
            mode: RobotFaceMode.waitingForConfirmation,
            nextEventLabel: 'Taken? · Morning meds',
            isFlipped: false,
            isLandscapeOnly: true,
            rampProgress: 1,
            isInAwakeWindow: true,
            actionDoseId: 'demo-dose',
            availableActions: {RobotFaceActionKind.skipDose},
          ),
          expectedKind: DoseLogEventKind.doseSkipped,
        ),
        (
          label: 'help request',
          buttonKey: RobotFaceScreen.needHelpButtonKey,
          state: const RobotFaceState(
            mode: RobotFaceMode.waitingForConfirmation,
            nextEventLabel: 'Taken? · Morning meds',
            isFlipped: false,
            isLandscapeOnly: true,
            rampProgress: 1,
            isInAwakeWindow: true,
            actionDoseId: 'demo-dose',
            availableActions: {RobotFaceActionKind.askForHelp},
          ),
          expectedKind: DoseLogEventKind.caregiverHelpRequested,
        ),
        (
          label: 'missed recognition',
          buttonKey: RobotFaceScreen.recognizeMissedDoseButtonKey,
          state: const RobotFaceState(
            mode: RobotFaceMode.missed,
            nextEventLabel: '8:30 AM · Morning meds',
            isFlipped: false,
            isLandscapeOnly: true,
            rampProgress: 1,
            isInAwakeWindow: true,
            actionDoseId: 'demo-dose',
            availableActions: {RobotFaceActionKind.recognizeMissedDose},
          ),
          expectedKind: DoseLogEventKind.doseMissedRecognized,
        ),
      ]) {
    testWidgets('${testCase.label} uses the scoped app clock', (tester) async {
      final clock = _RawAppClock(DateTime(2040, 1, 2, 8, 45));
      final doseActionLogger = _FakeRobotFaceDoseActionLogger();

      await tester.pumpWidget(
        _RobotFaceTestApp(
          appClock: clock,
          doseActionLogger: doseActionLogger.call,
          initialState: testCase.state,
        ),
      );
      await tester.pump();

      clock.value = DateTime(2040, 1, 2, 8, 55);
      await tester.tap(find.byKey(testCase.buttonKey));
      await tester.pump();

      expect(doseActionLogger.events, hasLength(1));
      expect(doseActionLogger.events.single.kind, testCase.expectedKind);
      expect(doseActionLogger.events.single.occurredAt, clock.now().toUtc());
      expect(doseActionLogger.events.single.occurredAt.isUtc, isTrue);
    });
  }

  testWidgets('action PIN blocks Robot Face confirm taken until accepted', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    ).setActionPin('1234');
    final doseActionLogger = _FakeRobotFaceDoseActionLogger();

    await tester.pumpWidget(
      _RobotFaceTestApp(
        database: database,
        doseActionLogger: doseActionLogger.call,
        initialState: const RobotFaceState(
          mode: RobotFaceMode.doseReady,
          nextEventLabel: 'Now · Morning meds',
          isFlipped: false,
          isLandscapeOnly: true,
          rampProgress: 1,
          isInAwakeWindow: true,
          statusLabel: 'Ready to dispense',
          actionDoseId: 'dose-123',
          availableActions: {
            RobotFaceActionKind.confirmTaken,
            RobotFaceActionKind.skipDose,
          },
        ),
      ),
    );

    await tester.pump();
    expect(find.byKey(RobotFaceScreen.confirmTakenButtonKey), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(RobotFaceScreen.confirmTakenButtonKey),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(RobotFaceScreen.confirmTakenButtonKey));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Enter Action PIN'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(doseActionLogger.events, isEmpty);

    await tester.tap(find.byKey(RobotFaceScreen.confirmTakenButtonKey));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byKey(const Key('action-pin-field')), '1234');
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(doseActionLogger.events, hasLength(1));
    expect(
      doseActionLogger.events.single.kind,
      DoseLogEventKind.doseTakenConfirmed,
    );
  });

  testWidgets('action PIN does not gate missed-dose recognition', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    ).setActionPin('1234');
    final doseActionLogger = _FakeRobotFaceDoseActionLogger();

    await tester.pumpWidget(
      _RobotFaceTestApp(
        database: database,
        doseActionLogger: doseActionLogger.call,
        initialState: const RobotFaceState(
          mode: RobotFaceMode.missed,
          nextEventLabel: '8:00 AM · Morning meds',
          isFlipped: false,
          isLandscapeOnly: true,
          rampProgress: 1,
          isInAwakeWindow: true,
          statusLabel: 'Missed dose alert',
          actionDoseId: 'dose-123',
          availableActions: {RobotFaceActionKind.recognizeMissedDose},
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.byKey(RobotFaceScreen.recognizeMissedDoseButtonKey));
    await tester.pump();

    expect(find.text('Enter Action PIN'), findsNothing);
    expect(doseActionLogger.events, hasLength(1));
    expect(
      doseActionLogger.events.single.kind,
      DoseLogEventKind.doseMissedRecognized,
    );
    expect(doseActionLogger.events.single.marksDoseTaken, isFalse);
  });

  testWidgets(
    'Robot Face confirm taken reuses Today terminal dose side effects',
    (WidgetTester tester) async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      const scheduleId = 'vitamin-d-morning';
      final doseId = TodayNextDoseHelper.doseIdForDate(
        scheduleId,
        DateTime.now(),
      );
      await LocalPrescriptionRepository(database).upsertPrescription(
        Prescription(
          id: 'vitamin-d',
          name: 'Vitamin D',
          pillType: PillType.capsule,
          remainingDoses: 2,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      await LocalReminderRepository(database).upsertSchedule(
        ReminderSchedule(
          id: scheduleId,
          label: 'Vitamin D',
          prescriptionId: 'vitamin-d',
          hour: 8,
          minute: 30,
          isEnabled: true,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      await LocalCarouselSlotRepository(database).assignSlot(
        CarouselSlot(
          id: 'schedule-1-$scheduleId',
          slotNumber: 1,
          prescriptionId: 'vitamin-d',
          scheduleId: scheduleId,
          profileId: ReminderSchedule.defaultProfileId,
          status: CarouselSlotStatus.loaded,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );

      await tester.pumpWidget(
        DoseyAppScope(
          database: database,
          bleGateway: _FakeBleGateway(),
          child: MaterialApp(
            home: RobotFaceScreen(
              initialState: RobotFaceState(
                mode: RobotFaceMode.waitingForConfirmation,
                nextEventLabel: 'Taken? · Morning meds',
                isFlipped: false,
                isLandscapeOnly: true,
                rampProgress: 1,
                isInAwakeWindow: true,
                statusLabel: 'Waiting for confirmation',
                actionDoseId: doseId,
                availableActions: const {
                  RobotFaceActionKind.confirmTaken,
                  RobotFaceActionKind.skipDose,
                  RobotFaceActionKind.askForHelp,
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.byKey(RobotFaceScreen.confirmTakenButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final slot = await (database.select(
        database.carouselSlots,
      )..where((row) => row.id.equals('schedule-1-$scheduleId'))).getSingle();
      final prescription = await (database.select(
        database.prescriptions,
      )..where((row) => row.id.equals('vitamin-d'))).getSingle();

      expect(slot.status, CarouselSlotStatus.needsReview.storageValue);
      expect(prescription.remainingDoses, 1);
    },
  );

  testWidgets('Robot Face confirm taken retires an already dispensed slot', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    const scheduleId = 'vitamin-d-morning';
    final doseId = TodayNextDoseHelper.doseIdForDate(
      scheduleId,
      DateTime.now(),
    );
    await LocalPrescriptionRepository(database).upsertPrescription(
      Prescription(
        id: 'vitamin-d',
        name: 'Vitamin D',
        pillType: PillType.capsule,
        remainingDoses: 2,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    await LocalReminderRepository(database).upsertSchedule(
      ReminderSchedule(
        id: scheduleId,
        label: 'Vitamin D',
        prescriptionId: 'vitamin-d',
        hour: 8,
        minute: 30,
        isEnabled: true,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    await LocalCarouselSlotRepository(database).assignSlot(
      CarouselSlot(
        id: 'schedule-1-$scheduleId',
        slotNumber: 1,
        prescriptionId: 'vitamin-d',
        scheduleId: scheduleId,
        profileId: ReminderSchedule.defaultProfileId,
        status: CarouselSlotStatus.dispensed,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );

    await tester.pumpWidget(
      DoseyAppScope(
        database: database,
        bleGateway: _FakeBleGateway(),
        child: MaterialApp(
          home: RobotFaceScreen(
            initialState: RobotFaceState(
              mode: RobotFaceMode.waitingForConfirmation,
              nextEventLabel: 'Taken? · Morning meds',
              isFlipped: false,
              isLandscapeOnly: true,
              rampProgress: 1,
              isInAwakeWindow: true,
              statusLabel: 'Waiting for confirmation',
              actionDoseId: doseId,
              availableActions: const {
                RobotFaceActionKind.confirmTaken,
                RobotFaceActionKind.skipDose,
                RobotFaceActionKind.askForHelp,
              },
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.byKey(RobotFaceScreen.confirmTakenButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final slot = await (database.select(
      database.carouselSlots,
    )..where((row) => row.id.equals('schedule-1-$scheduleId'))).getSingle();

    expect(slot.status, CarouselSlotStatus.needsReview.storageValue);
  });

  testWidgets(
    'keeps actions available when shared dose logging reports failure',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _RobotFaceTestApp(
          doseActionLogger: (_, _, _) async => false,
          initialState: const RobotFaceState(
            mode: RobotFaceMode.waitingForConfirmation,
            nextEventLabel: 'Taken? · Morning meds',
            isFlipped: false,
            isLandscapeOnly: true,
            rampProgress: 1,
            isInAwakeWindow: true,
            statusLabel: 'Waiting for confirmation',
            actionDoseId: 'vitamin-d-morning:2026-07-08',
            availableActions: {
              RobotFaceActionKind.confirmTaken,
              RobotFaceActionKind.skipDose,
              RobotFaceActionKind.askForHelp,
            },
          ),
        ),
      );

      await tester.pump();

      final confirmButton = find.byKey(RobotFaceScreen.confirmTakenButtonKey);
      await tester.tap(confirmButton);
      await tester.pump();

      expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);
    },
  );

  testWidgets('ignores duplicate rapid confirm taps before rebuild', (
    WidgetTester tester,
  ) async {
    final doseActionLogger = _FakeRobotFaceDoseActionLogger(
      delayCompletion: true,
    );

    await tester.pumpWidget(
      _RobotFaceTestApp(
        doseActionLogger: doseActionLogger.call,
        initialState: const RobotFaceState(
          mode: RobotFaceMode.doseReady,
          nextEventLabel: 'Now · Morning meds',
          isFlipped: false,
          isLandscapeOnly: true,
          rampProgress: 1,
          isInAwakeWindow: true,
          statusLabel: 'Ready to dispense',
          actionDoseId: 'dose-123',
          availableActions: {
            RobotFaceActionKind.confirmTaken,
            RobotFaceActionKind.skipDose,
            RobotFaceActionKind.askForHelp,
          },
        ),
      ),
    );

    await tester.pump();

    final buttonFinder = find.byKey(RobotFaceScreen.confirmTakenButtonKey);

    await tester.tap(buttonFinder, warnIfMissed: false);
    await tester.tap(buttonFinder, warnIfMissed: false);
    await tester.pump();

    expect(doseActionLogger.events, hasLength(1));
    expect(
      doseActionLogger.events.single.kind,
      DoseLogEventKind.doseTakenConfirmed,
    );

    doseActionLogger.completePendingLog();
    await tester.pump();
  });

  testWidgets('logs skip action without marking the dose taken', (
    WidgetTester tester,
  ) async {
    final doseActionLogger = _FakeRobotFaceDoseActionLogger();

    await tester.pumpWidget(
      _RobotFaceTestApp(
        doseActionLogger: doseActionLogger.call,
        initialState: const RobotFaceState(
          mode: RobotFaceMode.doseReady,
          nextEventLabel: 'Now · Morning meds',
          isFlipped: false,
          isLandscapeOnly: true,
          rampProgress: 1,
          isInAwakeWindow: true,
          statusLabel: 'Ready to dispense',
          actionDoseId: 'dose-123',
          availableActions: {
            RobotFaceActionKind.confirmTaken,
            RobotFaceActionKind.skipDose,
            RobotFaceActionKind.askForHelp,
          },
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.byKey(RobotFaceScreen.skipDoseButtonKey));
    await tester.pump();

    expect(doseActionLogger.events, hasLength(1));
    expect(doseActionLogger.events.single.kind, DoseLogEventKind.doseSkipped);
    expect(doseActionLogger.events.single.doseId, 'dose-123');
    expect(doseActionLogger.events.single.marksDoseTaken, isFalse);
    expect(find.text('Skip logged.'), findsOneWidget);
  });

  testWidgets('logs help action without marking the dose taken', (
    WidgetTester tester,
  ) async {
    final doseActionLogger = _FakeRobotFaceDoseActionLogger();

    await tester.pumpWidget(
      _RobotFaceTestApp(
        doseActionLogger: doseActionLogger.call,
        initialState: const RobotFaceState(
          mode: RobotFaceMode.doseReady,
          nextEventLabel: 'Now · Morning meds',
          isFlipped: false,
          isLandscapeOnly: true,
          rampProgress: 1,
          isInAwakeWindow: true,
          statusLabel: 'Ready to dispense',
          actionDoseId: 'dose-123',
          availableActions: {
            RobotFaceActionKind.confirmTaken,
            RobotFaceActionKind.skipDose,
            RobotFaceActionKind.askForHelp,
          },
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.byKey(RobotFaceScreen.needHelpButtonKey));
    await tester.pump();

    expect(doseActionLogger.events, hasLength(1));
    expect(
      doseActionLogger.events.single.kind,
      DoseLogEventKind.caregiverHelpRequested,
    );
    expect(doseActionLogger.events.single.doseId, 'dose-123');
    expect(doseActionLogger.events.single.marksDoseTaken, isFalse);
    expect(find.text('Help request logged.'), findsOneWidget);
  });

  testWidgets('disables help after the first help request for the same dose', (
    WidgetTester tester,
  ) async {
    final doseActionLogger = _FakeRobotFaceDoseActionLogger();

    await tester.pumpWidget(
      _RobotFaceTestApp(
        doseActionLogger: doseActionLogger.call,
        initialState: const RobotFaceState(
          mode: RobotFaceMode.waitingForConfirmation,
          nextEventLabel: 'Taken? · Morning meds',
          isFlipped: false,
          isLandscapeOnly: true,
          rampProgress: 1,
          isInAwakeWindow: true,
          statusLabel: 'Waiting for confirmation',
          actionDoseId: 'dose-123',
          availableActions: {
            RobotFaceActionKind.confirmTaken,
            RobotFaceActionKind.skipDose,
            RobotFaceActionKind.askForHelp,
          },
        ),
      ),
    );

    await tester.pump();

    final helpButtonFinder = find.byKey(RobotFaceScreen.needHelpButtonKey);

    await tester.tap(helpButtonFinder);
    await tester.pump();

    expect(doseActionLogger.events, hasLength(1));
    expect(
      doseActionLogger.events.single.kind,
      DoseLogEventKind.caregiverHelpRequested,
    );
    expect(tester.widget<FilledButton>(helpButtonFinder).onPressed, isNull);

    await tester.tap(helpButtonFinder, warnIfMissed: false);
    await tester.pump();

    expect(doseActionLogger.events, hasLength(1));
  });
}

class _RawAppClock implements AppClock {
  _RawAppClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;

  @override
  Stream<DateTime> get ticks => const Stream<DateTime>.empty();
}

class _RobotFaceTestApp extends StatefulWidget {
  const _RobotFaceTestApp({
    super.key,
    this.database,
    this.controller,
    this.stateStream,
    this.initialState,
    this.isActive = true,
    this.doseActionLogger,
    this.appClock,
  });

  final DoseyDatabase? database;
  final RobotFaceController? controller;
  final Stream<RobotFaceState>? stateStream;
  final RobotFaceState? initialState;
  final bool isActive;
  final RobotFaceDoseActionLogger? doseActionLogger;
  final AppClock? appClock;

  @override
  State<_RobotFaceTestApp> createState() => _RobotFaceTestAppState();
}

class _RobotFaceTestAppState extends State<_RobotFaceTestApp> {
  late final DoseyDatabase _database =
      widget.database ?? DoseyDatabase.inMemory();

  @override
  void dispose() {
    if (widget.database == null) {
      unawaited(_database.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DoseyAppScope(
      database: _database,
      appClock: widget.appClock,
      bleGateway: _FakeBleGateway(),
      connectivityGateway: _FakeConnectivityGateway(),
      permissionGateway: _FakePermissionGateway(),
      reminderScheduler: _FakeReminderScheduler(),
      missedDoseReconciliationService: _FakeMissedDoseReconciliationService(),
      child: MaterialApp(
        home: RobotFaceScreen(
          controller: widget.controller,
          stateStream: widget.stateStream,
          initialState: widget.initialState,
          isActive: widget.isActive,
          doseActionLogger: widget.doseActionLogger,
        ),
      ),
    );
  }
}

class _FakeRobotFaceDoseActionLogger {
  _FakeRobotFaceDoseActionLogger({this.delayCompletion = false});

  final List<DoseLogEvent> events = <DoseLogEvent>[];
  final bool delayCompletion;
  Completer<bool>? _pendingLogCompleter;
  BuildContext? _pendingContext;
  String? _pendingSuccessMessage;

  Future<bool> call(
    BuildContext context,
    DoseLogEvent event,
    String successMessage,
  ) async {
    events.add(event);
    if (delayCompletion) {
      _pendingContext = context;
      _pendingSuccessMessage = successMessage;
      _pendingLogCompleter = Completer<bool>();
      final result = await _pendingLogCompleter!.future;
      _pendingLogCompleter = null;
      _pendingContext = null;
      _pendingSuccessMessage = null;
      return result;
    }
    _showSuccess(context, successMessage);
    return true;
  }

  void completePendingLog({bool result = true}) {
    if (result && _pendingContext != null && _pendingSuccessMessage != null) {
      _showSuccess(_pendingContext!, _pendingSuccessMessage!);
    }
    _pendingLogCompleter?.complete(result);
  }

  void _showSuccess(BuildContext context, String successMessage) {
    if (!context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(successMessage)));
  }
}

class _IdleControllerGateway implements ControllerGateway {
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
  Stream<ControllerSnapshot> watchController() {
    return Stream.value(const ControllerSnapshot.disconnected());
  }
}

class _ConnectedControllerGateway implements ControllerGateway {
  const _ConnectedControllerGateway();

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
  Stream<ControllerSnapshot> watchController() {
    return Stream.value(const ControllerSnapshot.connected());
  }
}

class _IdleControllerLifecycleService extends ControllerLifecycleService {
  _IdleControllerLifecycleService()
    : super(
        controller: _IdleControllerGateway(),
        commandRepository: _UnusedControllerCommandRepository(),
        doseLog: _FakeDoseLog(),
        carouselSlots: _UnusedCarouselSlotRepository(),
      );
}

class _IdleScheduleProfileRepository implements ScheduleProfileRepository {
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
  Stream<ScheduleProfile?> watchActiveProfile() {
    return Stream.value(null);
  }

  @override
  Stream<List<ScheduleProfile>> watchProfiles() {
    return Stream.value(const <ScheduleProfile>[]);
  }
}

class _FixedAppSettingsRepository extends LocalAppSettingsRepository {
  _FixedAppSettingsRepository(super.database, this._role)
    : super(defaultRole: _role);

  final AppDeviceRole _role;

  @override
  Stream<AppDeviceRole> watchDeviceRole() {
    return Stream.value(_role);
  }
}

class _FixedRobotFaceSettingsRepository extends RobotFaceSettingsRepository {
  _FixedRobotFaceSettingsRepository(super.database);

  @override
  Stream<RobotFaceSettings> watchSettings() {
    return Stream.value(const RobotFaceSettings());
  }
}

class _RobotFaceInteractionControllerHarness {
  _RobotFaceInteractionControllerHarness()
    : database = DoseyDatabase.inMemory(),
      clock = StreamController<DateTime>.broadcast(),
      initialTime = DateTime(2026, 7, 13, 12) {
    currentTime = initialTime;
    controller = RobotFaceController(
      settings: _FixedAppSettingsRepository(
        database,
        AppDeviceRole.androidRobot,
      ),
      robotFaceSettings: _FixedRobotFaceSettingsRepository(database),
      controller: const _ConnectedControllerGateway(),
      controllerLifecycle: _IdleControllerLifecycleService(),
      scheduleProfiles: _IdleScheduleProfileRepository(),
      reminders: _FakeReminderRepository(),
      doseLog: _FakeDoseLog(),
      clock: clock.stream,
      now: () => currentTime,
    );
  }

  final DoseyDatabase database;
  final StreamController<DateTime> clock;
  final DateTime initialTime;
  late final RobotFaceController controller;
  late DateTime currentTime;

  void advance(Duration duration) {
    currentTime = currentTime.add(duration);
    clock.add(currentTime);
  }

  Future<void> dispose() async {
    await clock.close();
    await controller.close();
    await database.close();
  }
}

class _UnusedControllerCommandRepository
    implements ControllerCommandRepository {
  @override
  Future<ControllerCommandEvent> appendEvent(
    String sessionId,
    ControllerCommandEventType eventType, {
    required DateTime occurredAt,
    String? details,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ControllerCommandSession> createSession({
    required ControllerCommandType commandType,
    required DateTime now,
    String? doseId,
    String? scheduleId,
    String? slotId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<ControllerCommandEvent>> getEventsForSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<ControllerCommandSession?> getLatestRelevantSession() {
    throw UnimplementedError();
  }

  @override
  Future<ControllerCommandSession> getSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<List<ControllerCommandSession>> getUnresolvedSessions() {
    throw UnimplementedError();
  }

  @override
  Future<void> updateSessionState(
    String sessionId,
    ControllerCommandSessionState state, {
    ControllerCommandFailureReason? failureReason,
    DateTime? acceptedAt,
    DateTime? resolvedAt,
    DateTime? updatedAt,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<ControllerCommandSession?> watchLatestRelevantSession() {
    return const Stream<ControllerCommandSession?>.empty();
  }

  @override
  Stream<List<ControllerCommandHistoryEntry>> watchRecentHistory({
    int limit = 12,
  }) {
    return const Stream<List<ControllerCommandHistoryEntry>>.empty();
  }

  @override
  Stream<List<ControllerCommandSession>> watchUnresolvedSessions() {
    return const Stream<List<ControllerCommandSession>>.empty();
  }
}

class _UnusedCarouselSlotRepository implements CarouselSlotRepository {
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
  Stream<List<CarouselSlot>> watchSlots({String? profileId}) {
    return Stream.value(const <CarouselSlot>[]);
  }
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
