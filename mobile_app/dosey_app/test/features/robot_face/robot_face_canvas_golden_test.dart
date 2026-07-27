import 'dart:typed_data';

import 'package:dosey_app/features/robot_face/robot_face_animation.dart';
import 'package:dosey_app/features/robot_face/robot_face_canvas.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const double _goldenPrecisionTolerance = 0.00025;

void main() {
  test('golden tolerance accepts raster noise but rejects visual changes', () {
    expect(_isWithinGoldenTolerance(0.00019), isTrue);
    expect(_isWithinGoldenTolerance(_goldenPrecisionTolerance), isTrue);
    expect(_isWithinGoldenTolerance(0.00026), isFalse);
  });

  testWidgets('Robot Face representative poses match the Classic identity', (
    WidgetTester tester,
  ) async {
    final previousComparator = goldenFileComparator;
    goldenFileComparator = _TolerantGoldenFileComparator(
      Uri.parse('test/features/robot_face/robot_face_canvas_golden_test.dart'),
    );
    addTearDown(() => goldenFileComparator = previousComparator);

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

bool _isWithinGoldenTolerance(double diffPercent) =>
    diffPercent <= _goldenPrecisionTolerance;

class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    if (result.passed || _isWithinGoldenTolerance(result.diffPercent)) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
