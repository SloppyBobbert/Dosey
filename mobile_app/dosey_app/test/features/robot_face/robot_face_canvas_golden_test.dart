import 'package:dosey_app/features/robot_face/robot_face_animation.dart';
import 'package:dosey_app/features/robot_face/robot_face_canvas.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Robot Face representative poses match the Classic identity', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const idle = RobotFaceState(
      mode: RobotFaceMode.idle,
      nextEventLabel: 'No reminders scheduled',
      isFlipped: false,
      isLandscapeOnly: true,
      rampProgress: 0,
      isInAwakeWindow: true,
    );
    const missed = RobotFaceState(
      mode: RobotFaceMode.missed,
      nextEventLabel: 'Dose missed',
      isFlipped: false,
      isLandscapeOnly: true,
      rampProgress: 1,
      isInAwakeWindow: true,
    );
    const sleepy = RobotFaceState(
      mode: RobotFaceMode.sleepy,
      nextEventLabel: 'Resting',
      isFlipped: false,
      isLandscapeOnly: true,
      rampProgress: 0,
      isInAwakeWindow: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: RepaintBoundary(
            key: const ValueKey<String>('robot-face-golden'),
            child: ColoredBox(
              color: Colors.black,
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        Expanded(child: RobotFaceCanvas(state: idle)),
                        Expanded(
                          child: RobotFaceCanvas(
                            state: idle,
                            animationCue: RobotFaceAnimationCue.notice,
                            animationRevision: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Expanded(
                    child: Row(
                      children: <Widget>[
                        Expanded(child: RobotFaceCanvas(state: missed)),
                        Expanded(child: RobotFaceCanvas(state: sleepy)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byKey(const ValueKey<String>('robot-face-golden')),
      matchesGoldenFile('goldens/robot_face_classic_poses.png'),
    );
  });
}
