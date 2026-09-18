import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dosey_app/features/robot_face/robot_face_canvas.dart';
import 'package:dosey_app/features/robot_face/robot_face_screen.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'robot_face_golden_path.dart';
import 'robot_face_test_font.dart';

const double _goldenPrecisionTolerance = 0.00025;

void main() {
  test('golden tolerance accepts raster noise but rejects visual changes', () {
    expect(_isWithinGoldenTolerance(0.00019), isTrue);
    expect(_isWithinGoldenTolerance(_goldenPrecisionTolerance), isTrue);
    expect(_isWithinGoldenTolerance(0.00026), isFalse);
  });

  testWidgets(
    'Robot Face representative poses match the warm companion identity',
    (WidgetTester tester) async {
      final previousComparator = goldenFileComparator;
      goldenFileComparator = _TolerantGoldenFileComparator(
        Uri.parse(
          'test/features/robot_face/robot_face_canvas_golden_test.dart',
        ),
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
      const approaching = RobotFaceState(
        mode: RobotFaceMode.doseApproaching,
        nextEventLabel: 'Dose soon',
        isFlipped: false,
        isLandscapeOnly: true,
        rampProgress: 0.7,
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
                          Expanded(child: RobotFaceCanvas(state: approaching)),
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
        matchesGoldenFile(
          robotFaceGoldenPath('goldens/robot_face_warm_companion_poses.png'),
        ),
      );
    },
  );

  testWidgets('Robot Face ready and help overlays stay visually distinct', (
    WidgetTester tester,
  ) async {
    const ready = RobotFaceState(
      mode: RobotFaceMode.doseReady,
      nextEventLabel: 'Now · Morning meds',
      isFlipped: false,
      isLandscapeOnly: true,
      rampProgress: 1,
      isInAwakeWindow: true,
      actionDoseId: 'dose-1',
      availableActions: {RobotFaceActionKind.confirmTaken},
    );
    const help = RobotFaceState(
      mode: RobotFaceMode.error,
      controllerCondition: RobotFaceControllerCondition.fault,
      nextEventLabel: 'Please ask for help',
      isFlipped: false,
      isLandscapeOnly: true,
      rampProgress: 1,
      isInAwakeWindow: true,
      actionDoseId: 'dose-1',
      availableActions: {RobotFaceActionKind.askForHelp},
    );

    await tester.binding.setSurfaceSize(const Size(800, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Future<void> capture(
      RobotFaceState state,
      String goldenFile, {
      TextScaler textScaler = TextScaler.noScaling,
      EdgeInsets padding = EdgeInsets.zero,
      Brightness brightness = Brightness.light,
    }) async {
      await tester.runAsync(loadRobotFaceTestFont);
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(goldenFile),
          themeAnimationDuration: Duration.zero,
          theme: ThemeData(
            fontFamily: state.hasPinnedShortageAlert ? robotFaceTestFont : null,
            brightness: brightness,
          ),
          debugShowCheckedModeBanner: false,
          home: MediaQuery(
            data: MediaQueryData(
              disableAnimations: true,
              textScaler: textScaler,
              padding: padding,
            ),
            child: RepaintBoundary(
              key: const ValueKey<String>('robot-face-overlay-golden'),
              child: RobotFaceScreen(
                key: ValueKey<String>(goldenFile),
                initialState: state,
                onLongPress: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final exitRect = tester.getRect(
        find.byKey(RobotFaceScreen.exitButtonKey),
      );
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey<String>('robot-face-overlay-golden')),
      );
      final foregroundPixels = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          var count = 0;
          for (var y = exitRect.top.ceil(); y < exitRect.bottom.floor(); y++) {
            for (
              var x = exitRect.left.ceil();
              x < exitRect.right.floor();
              x++
            ) {
              final offset = (y * image.width + x) * 4;
              if (bytes.getUint8(offset) >= 180 &&
                  bytes.getUint8(offset + 1) >= 200 &&
                  bytes.getUint8(offset + 2) >= 210 &&
                  bytes.getUint8(offset + 3) >= 128) {
                count++;
              }
            }
          }
          return count;
        } finally {
          image.dispose();
        }
      });
      expect(
        foregroundPixels,
        greaterThan(8),
        reason: 'Exit must actually paint: $goldenFile',
      );
      debugPrint(
        'Exit painted: $goldenFile foregroundPixels=$foregroundPixels',
      );

      await expectLater(
        find.byKey(const ValueKey<String>('robot-face-overlay-golden')),
        matchesGoldenFile(robotFaceGoldenPath(goldenFile)),
      );
    }

    await capture(
      ready.copyWith(nextEventLabel: ''),
      'goldens/robot_face_compact_action_only.png',
      textScaler: TextScaler.linear(2),
      padding: const EdgeInsets.fromLTRB(83, 31, 97, 149),
    );
    await capture(
      help.copyWith(
        nextEventLabel: 'Now · Morning meds',
        statusLabel: 'Controller fault. Ask for help.',
        hasPinnedShortageAlert: true,
        activeShortageMedicationLabel: 'Demo medication',
        activeShortageScheduledLabel: '8:00 AM',
        activeShortageSlotNumber: 2,
      ),
      'goldens/robot_face_mandatory_shortage_large_text.png',
      textScaler: TextScaler.linear(2),
      padding: const EdgeInsets.fromLTRB(83, 31, 97, 149),
    );
    await capture(ready, 'goldens/robot_face_ready_overlay.png');
    await capture(help, 'goldens/robot_face_help_overlay.png');
    await capture(
      ready,
      'goldens/robot_face_padded_ready_overlay.png',
      padding: const EdgeInsets.fromLTRB(83, 31, 97, 149),
    );
    await capture(
      help,
      'goldens/robot_face_padded_help_overlay.png',
      padding: const EdgeInsets.fromLTRB(83, 31, 97, 149),
    );
    await capture(
      ready,
      'goldens/robot_face_ready_large_text.png',
      textScaler: TextScaler.linear(2),
    );
    await capture(
      help.copyWith(isFlipped: true),
      'goldens/robot_face_flipped_help_overlay.png',
    );
    final severe = help.copyWith(
      nextEventLabel: 'Now · Morning meds',
      statusLabel: 'Controller fault. Ask for help.',
      hasPinnedShortageAlert: true,
      activeShortageMedicationLabel: 'Demo medication',
      activeShortageScheduledLabel: '8:00 AM',
      activeShortageSlotNumber: 2,
    );
    await capture(
      severe.copyWith(isFlipped: true),
      'goldens/robot_face_mandatory_shortage_landscape_flipped.png',
      textScaler: TextScaler.linear(2),
      padding: const EdgeInsets.fromLTRB(83, 31, 97, 149),
    );
    final longSevere = severe.copyWith(
      activeShortageMedicationLabel:
          'Demo extended-release morning medication 100 mg / 25 mg combination tablet',
      networkAdvisory: RobotFaceNetworkAdvisory.internetOffline,
    );
    for (final portrait in [false, true]) {
      await tester.binding.setSurfaceSize(
        portrait ? const Size(400, 800) : const Size(800, 400),
      );
      for (final flipped in [false, true]) {
        await capture(
          longSevere.copyWith(isFlipped: flipped),
          'goldens/robot_face_long_status_${portrait}_$flipped.png',
          textScaler: TextScaler.linear(2),
          padding: const EdgeInsets.fromLTRB(83, 31, 97, 149),
        );
      }
      await capture(
        longSevere,
        'goldens/robot_face_exit_dark_$portrait.png',
        brightness: Brightness.dark,
        textScaler: TextScaler.linear(2),
        padding: const EdgeInsets.fromLTRB(83, 31, 97, 149),
      );
    }
    for (final portrait in [false, true]) {
      await tester.binding.setSurfaceSize(
        portrait ? const Size(360, 800) : const Size(800, 360),
      );
      for (final flipped in [false, true]) {
        for (final brightness in Brightness.values) {
          await capture(
            severe.copyWith(isFlipped: flipped),
            'goldens/robot_face_rejected_rail_${portrait}_${flipped}_${brightness.name}.png',
            brightness: brightness,
            textScaler: TextScaler.linear(2),
            padding: const EdgeInsets.fromLTRB(83, 31, 97, 149),
          );
        }
      }
      await tester.binding.setSurfaceSize(
        portrait ? const Size(320, 640) : const Size(640, 320),
      );
      for (final flipped in [false, true]) {
        await capture(
          longSevere.copyWith(
            isFlipped: flipped,
            activeShortageMedicationLabel:
                'Demo lisinopril / hydrochlorothiazide 20 mg / 12.5 mg tablet',
          ),
          'goldens/robot_face_small_real_font_${portrait}_$flipped.png',
          brightness: flipped ? Brightness.dark : Brightness.light,
          textScaler: TextScaler.linear(flipped ? 2 : 1),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        );
      }
    }
    await tester.binding.setSurfaceSize(const Size(400, 800));
    for (final flipped in [false, true]) {
      await capture(
        severe.copyWith(isFlipped: flipped),
        'goldens/robot_face_mandatory_shortage_portrait_$flipped.png',
        textScaler: TextScaler.linear(2),
        padding: const EdgeInsets.fromLTRB(83, 31, 97, 149),
      );
    }
    for (final state in [ready, help]) {
      final label = state.mode == RobotFaceMode.doseReady ? 'ready' : 'help';
      for (final flipped in [false, true]) {
        await capture(
          state.copyWith(isFlipped: flipped),
          'goldens/robot_face_portrait_${label}_$flipped.png',
        );
        await capture(
          state.copyWith(isFlipped: flipped),
          'goldens/robot_face_padded_portrait_${label}_$flipped.png',
          padding: const EdgeInsets.fromLTRB(83, 31, 97, 149),
          textScaler: TextScaler.linear(2),
        );
      }
    }
    await capture(
      ready.copyWith(isFlipped: true),
      'goldens/robot_face_flipped_portrait_large_text.png',
      textScaler: TextScaler.linear(2),
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
