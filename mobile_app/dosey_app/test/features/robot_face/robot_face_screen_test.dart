import 'dart:async';

import 'package:dosey_app/features/robot_face/robot_face_canvas.dart';
import 'package:dosey_app/features/robot_face/robot_face_screen.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';
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
        initialState: RobotFaceState(
          mode: RobotFaceMode.idle,
          nextEventLabel: 'No reminders scheduled',
          isFlipped: true,
          isLandscapeOnly: true,
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
        initialState: RobotFaceState(
          mode: RobotFaceMode.doseReady,
          nextEventLabel: 'Now · Morning meds',
          isFlipped: false,
          isLandscapeOnly: true,
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
}

class _RobotFaceTestApp extends StatelessWidget {
  const _RobotFaceTestApp({
    super.key,
    this.stateStream,
    required this.initialState,
    this.isActive = true,
  });

  final Stream<RobotFaceState>? stateStream;
  final RobotFaceState initialState;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: RobotFaceScreen(
        stateStream: stateStream,
        initialState: initialState,
        isActive: isActive,
      ),
    );
  }
}
