import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/app_theme_preference.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/robot_face/robot_face_screen.dart';
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
    for (final mode in [
      RobotFaceMode.idle,
      RobotFaceMode.doseReady,
      RobotFaceMode.error,
      RobotFaceMode.waitingForConfirmation,
      RobotFaceMode.dispensing,
      RobotFaceMode.missed,
    ]) {
      testWidgets('daily preview ${mode.name} ${brightness.name}', (
        tester,
      ) async {
        await _preview(tester, mode: mode, brightness: brightness);
      });
    }
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
  states.add(
    RobotFaceState(
      mode: mode,
      nextEventLabel: reminder,
      statusLabel: status,
      isFlipped: false,
      isLandscapeOnly: true,
      rampProgress: 1,
      isInAwakeWindow: true,
      actionDoseId: mode == RobotFaceMode.idle
          ? null
          : 'fictional-preview-dose',
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
    ),
  );
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
  if (directory != null) {
    final name =
        '${mode.name}_${brightness.name}_${scale.toInt()}x_${portrait ? 'portrait' : 'landscape'}';
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('ordinary-fixture')),
    );
    await tester.runAsync(() async {
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
