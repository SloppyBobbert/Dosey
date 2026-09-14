import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/app_theme_preference.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/robot_face/demo_face_lab_controller.dart';
import 'package:dosey_app/features/robot_face/robot_face_screen.dart';
import 'package:dosey_app/features/robot_face/robot_face_canvas.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'robot_face_action_host_test.dart' show robotFacePreviewApp;
import 'robot_face_test_font.dart';

// PREVIEW ONLY: the test engine forces font-less ButtonStyles to Ahem.
// Explicitly supply cached Roboto on their render spans, preserving every
// production size, weight, color and control constraint; then relayout.
// This is a host font approximation, not device font qualification. Existing
// golden suites never call this helper and retain their original font policy.
void _normalizePreviewFonts(WidgetTester tester) {
  InlineSpan normalize(InlineSpan span) {
    if (span is! TextSpan) return span;
    return TextSpan(
      text: span.text,
      style: (span.style ?? const TextStyle()).copyWith(
        fontFamily: span.style?.fontFamily ?? robotFaceTestFont,
      ),
      children: span.children?.map(normalize).toList(),
      semanticsLabel: span.semanticsLabel,
    );
  }

  for (final paragraph in tester.renderObjectList<RenderParagraph>(
    find.byType(RichText),
  )) {
    paragraph.text = normalize(paragraph.text);
  }
}

void main() {
  setUpAll(loadRobotFaceTestFont);
  for (final brightness in Brightness.values) {
    for (final mode in RobotFaceMode.values) {
      testWidgets('daily preview ${mode.name} ${brightness.name}', (
        tester,
      ) async {
        await _preview(tester, mode: mode, brightness: brightness);
      });
      for (final portrait in [false, true]) {
        testWidgets('flipped ${mode.name} ${brightness.name} $portrait', (
          tester,
        ) async {
          await _preview(
            tester,
            mode: mode,
            brightness: brightness,
            portrait: portrait,
            flipped: true,
          );
        });
        testWidgets('large text ${mode.name} ${brightness.name} $portrait', (
          tester,
        ) async {
          await _preview(
            tester,
            mode: mode,
            brightness: brightness,
            portrait: portrait,
            scale: 2,
          );
        });
      }
      testWidgets('daily preview ${mode.name} ${brightness.name} portrait', (
        tester,
      ) async {
        await _preview(
          tester,
          mode: mode,
          brightness: brightness,
          portrait: true,
        );
      });
    }
  }
  for (final face in DemoFacePreview.values) {
    for (final brightness in Brightness.values) {
      for (final portrait in [false, true]) {
        testWidgets('Face Lab ${face.name} ${brightness.name} $portrait', (
          tester,
        ) async {
          await _preview(
            tester,
            mode: RobotFaceMode.idle,
            face: face,
            brightness: brightness,
            portrait: portrait,
          );
        });
      }
    }
  }
  for (final brightness in Brightness.values) {
    testWidgets('network advisory ${brightness.name}', (tester) async {
      await _preview(
        tester,
        mode: RobotFaceMode.idle,
        brightness: brightness,
        networkOffline: true,
      );
    });
  }
  testWidgets('daily preview waiting 200 percent', (tester) async {
    await _preview(
      tester,
      mode: RobotFaceMode.waitingForConfirmation,
      scale: 2,
    );
  });
  testWidgets('daily preview ready portrait', (tester) async {
    await _preview(tester, mode: RobotFaceMode.doseReady, portrait: true);
  });
}

Future<void> _preview(
  WidgetTester tester, {
  required RobotFaceMode mode,
  Brightness brightness = Brightness.dark,
  double scale = 1,
  bool portrait = false,
  DemoFacePreview? face,
  bool networkOffline = false,
  bool flipped = false,
}) async {
  tester.view.physicalSize = portrait
      ? const Size(400, 800)
      : const Size(800, 400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final database = DoseyDatabase.inMemory();
  addTearDown(database.close);
  await LocalAppSettingsRepository(
    database,
    defaultRole: AppDeviceRole.androidRobot,
  ).setThemePreference(
    brightness == Brightness.light
        ? AppThemePreference.light
        : AppThemePreference.dark,
  );
  final states = StreamController<RobotFaceState>.broadcast();
  addTearDown(states.close);
  await tester.pumpWidget(
    robotFacePreviewApp(
      states: states.stream,
      database: database,
      scale: scale,
    ),
  );
  final reminder = mode == RobotFaceMode.idle
      ? '8:00 PM · Evening medication'
      : '8:00 AM · Morning medication';
  final status = switch (mode) {
    RobotFaceMode.error =>
      'The carousel could not turn. Ask your caregiver for help.',
    RobotFaceMode.waitingForConfirmation =>
      'Check the cup before confirming you took your medication.',
    RobotFaceMode.dispensing =>
      'Please wait while your medication is dispensed.',
    RobotFaceMode.doseReady => 'Ready to dispense',
    RobotFaceMode.missed => 'Missed dose alert',
    _ => 'Controller connected',
  };
  // Fictional reminder and presentation state only; never linked to a person.
  final liveState = RobotFaceState(
    mode: mode,
    nextEventLabel: reminder,
    statusLabel: status,
    isFlipped: flipped,
    isLandscapeOnly: true,
    rampProgress: 1,
    isInAwakeWindow: true,
    actionDoseId: mode == RobotFaceMode.idle ? null : 'fictional-preview-dose',
    availableActions: switch (mode) {
      RobotFaceMode.idle => const {},
      RobotFaceMode.waitingForConfirmation => const {
        RobotFaceActionKind.confirmTaken,
        RobotFaceActionKind.skipDose,
        RobotFaceActionKind.askForHelp,
      },
      RobotFaceMode.missed => const {RobotFaceActionKind.recognizeMissedDose},
      _ => const {RobotFaceActionKind.askForHelp},
    },
  );
  final state = face != null || networkOffline
      ? DemoFaceLabState(
          face: face,
          internetOffline: networkOffline,
        ).previewStateFor(liveState)
      : liveState;
  states.add(state);
  await tester.pumpAndSettle();
  expect(
    Theme.of(tester.element(find.byType(RobotFaceScreen))).brightness,
    brightness,
  );
  expect(tester.takeException(), isNull);
  _normalizePreviewFonts(tester);
  tester
      .renderObject(find.byKey(RobotFaceScreen.displayFrameKey))
      .markNeedsLayout();
  await tester.pumpAndSettle();
  tester
      .renderObject(find.byKey(RobotFaceScreen.displayFrameKey))
      .markNeedsPaint();
  await tester.pump();
  expect(tester.takeException(), isNull);
  // Prove proportional glyphs for every rendered control, including the
  // font-less exit and prominent missed-dose button (Ahem is monospaced).
  for (final paragraph in tester.renderObjectList<RenderParagraph>(
    find.descendant(
      of: find.byType(ButtonStyleButton),
      matching: find.byType(RichText),
    ),
  )) {
    final label = paragraph.text.toPlainText();
    final widths = <double>[];
    for (var i = 0; i < label.length; i++) {
      if (label[i].trim().isEmpty) continue;
      widths.addAll(
        paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: i, extentOffset: i + 1),
            )
            .map((box) => box.right - box.left),
      );
    }
    expect(
      widths.reduce((a, b) => a > b ? a : b) -
          widths.reduce((a, b) => a < b ? a : b),
      greaterThan(1),
      reason: 'Real-font control: $label',
    );
    expect(paragraph.text.style?.fontFamily, robotFaceTestFont);
    expect(paragraph.didExceedMaxLines, isFalse);
  }
  final directory = Platform.environment['ROBOT_FACE_PREVIEW_DIR'];
  {
    final name =
        '${face == null ? mode.name : 'lab_${face.name}'}${networkOffline ? '_internetOffline' : ''}${flipped ? '_flipped' : ''}_${brightness.name}_${scale.toInt()}x_${portrait ? 'portrait' : 'landscape'}';
    final paintFinder = find.descendant(
      of: find.byType(RobotFaceCanvas),
      matching: find.byType(CustomPaint),
    );
    final box = tester.renderObject<RenderBox>(paintFinder);
    final dynamic painter = tester.widget<CustomPaint>(paintFinder).painter!;
    final eyes = (painter.debugPaintedEyeRects as List<Rect>)
        .map(
          (rect) => MatrixUtils.transformRect(box.getTransformTo(null), rect),
        )
        .toList();
    List<double?> rectData(Rect rect) => [
      rect.left,
      rect.top,
      rect.width,
      rect.height,
    ].map((value) => value.isFinite ? value : null).toList();
    final surfaceFinder = find.descendant(
      of: find.byType(RobotFaceSurface),
      matching: find.byType(CustomPaint),
    );
    final surfaceBox = tester.renderObject<RenderBox>(surfaceFinder);
    final dynamic surfacePainter = tester
        .widget<CustomPaint>(surfaceFinder)
        .painter!;
    final surface = MatrixUtils.transformRect(
      surfaceBox.getTransformTo(null),
      surfacePainter.debugPaintedSurfaceRect as Rect,
    );
    expect(surface.width, closeTo(tester.view.physicalSize.width, 0.001));
    expect(surface.height, closeTo(tester.view.physicalSize.height, 0.001));
    if (!portrait &&
        scale == 1 &&
        face == null &&
        !flipped &&
        !networkOffline &&
        [RobotFaceMode.idle, RobotFaceMode.doseReady].contains(mode)) {
      expect(eyes.first.width, greaterThan(230));
      expect(eyes.first.height, greaterThan(150));
    }
    expect(
      tester
          .getRect(find.byKey(RobotFaceScreen.bottomCardKey))
          .overlaps(tester.getRect(find.byKey(RobotFaceScreen.exitButtonKey))),
      isFalse,
      reason: '$name status/exit',
    );
    for (final eye in eyes) {
      expect(
        surface.contains(eye.topLeft) && surface.contains(eye.bottomRight),
        isTrue,
      );
      for (final key in [
        RobotFaceScreen.exitButtonKey,
        RobotFaceScreen.bottomCardKey,
      ]) {
        expect(
          eye.overlaps(tester.getRect(find.byKey(key))),
          isFalse,
          reason:
              '$name eye $eye overlaps $key ${tester.getRect(find.byKey(key))}',
        );
      }
    }
    if (!portrait && scale == 1 && !flipped) {
      expect(
        eyes.first.width,
        greaterThan(220),
        reason: '$name ordinary eye scale',
      );
    }
    final geometry = {
      'mode': state.mode.name,
      'condition': state.controllerCondition?.name,
      'faceLab': face?.name,
      'networkAdvisory': state.networkAdvisory?.name,
      'baseEyes': (painter.debugBaseEyeRects(box.size) as List<Rect>)
          .map(
            (rect) => rectData(
              MatrixUtils.transformRect(box.getTransformTo(null), rect),
            ),
          )
          .toList(),
      'paintedSurface': rectData(surface),
      'canvas': rectData(tester.getRect(find.byKey(RobotFaceScreen.canvasKey))),
      'eyes': eyes.map(rectData).toList(),
      'status': rectData(
        tester.getRect(find.byKey(RobotFaceScreen.bottomCardKey)),
      ),
      'font': 'cached Roboto host approximation; production theme',
    };
    if (directory == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('ordinary-fixture')),
    );
    await tester.runAsync(() async {
      await File('$directory/$name.json').writeAsString(jsonEncode(geometry));
      final image = await boundary.toImage();
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '$directory/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }
}
