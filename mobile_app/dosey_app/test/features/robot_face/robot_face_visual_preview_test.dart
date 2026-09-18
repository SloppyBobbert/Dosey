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
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'robot_face_action_host_test.dart' show robotFacePreviewApp;
import 'robot_face_test_font.dart';
import 'robot_face_edge_to_edge_canvas_test.dart'
    show robotFaceExpectEveryWordReachable;

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
  for (final mode in [
    RobotFaceMode.idle,
    RobotFaceMode.doseReady,
    RobotFaceMode.missed,
    RobotFaceMode.waitingForConfirmation,
    RobotFaceMode.error,
  ]) {
    for (final brightness in Brightness.values) {
      for (final open in [false, true]) {
        testWidgets('minimal ${mode.name} ${brightness.name} open=$open', (
          tester,
        ) async {
          await _preview(
            tester,
            mode: mode,
            brightness: brightness,
            openDetails: open,
            minimal: true,
          );
        });
      }
    }
  }
  for (final portrait in [false, true]) {
    for (final open in [false, true]) {
      testWidgets('minimal missed scaled portrait=$portrait open=$open', (
        tester,
      ) async {
        await _preview(
          tester,
          mode: RobotFaceMode.missed,
          scale: 2,
          portrait: portrait,
          openDetails: open,
          minimal: true,
        );
      });
    }
  }
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
        testWidgets('large flipped ${mode.name} ${brightness.name} $portrait', (
          tester,
        ) async {
          await _preview(
            tester,
            mode: mode,
            brightness: brightness,
            portrait: portrait,
            flipped: true,
            scale: 2,
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
  for (final brightness in Brightness.values) {
    for (final portrait in [false, true]) {
      for (final flipped in [false, true]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            'shortage ${brightness.name} portrait=$portrait flipped=$flipped scale=$scale',
            (tester) async {
              await _preview(
                tester,
                mode: RobotFaceMode.error,
                brightness: brightness,
                portrait: portrait,
                flipped: flipped,
                scale: scale,
                shortage: true,
              );
            },
          );
        }
      }
    }
  }
  for (final face in DemoFacePreview.values) {
    for (final brightness in Brightness.values) {
      for (final portrait in [false, true]) {
        testWidgets(
          'large Face Lab ${face.name} ${brightness.name} $portrait',
          (tester) async {
            await _preview(
              tester,
              mode: RobotFaceMode.idle,
              face: face,
              brightness: brightness,
              portrait: portrait,
              scale: 2,
            );
          },
        );
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
  bool openDetails = false,
  bool minimal = false,
  bool shortage = false,
}) async {
  for (final flip in face == null ? [flipped] : [false, true]) {
    for (final open in minimal ? [openDetails] : [false, true]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await _previewState(
        tester,
        mode: mode,
        brightness: brightness,
        scale: scale,
        portrait: portrait,
        face: face,
        networkOffline: networkOffline,
        flipped: flip,
        openDetails: open,
        minimal: minimal,
        shortage: shortage,
      );
    }
  }
}

Future<void> _previewState(
  WidgetTester tester, {
  required RobotFaceMode mode,
  Brightness brightness = Brightness.dark,
  double scale = 1,
  bool portrait = false,
  DemoFacePreview? face,
  bool networkOffline = false,
  bool flipped = false,
  bool openDetails = false,
  bool minimal = false,
  bool shortage = false,
}) async {
  final semantics = tester.ensureSemantics();
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
    controllerCondition: shortage ? RobotFaceControllerCondition.fault : null,
    hasPinnedShortageAlert: shortage,
    activeShortageMedicationLabel: shortage
        ? 'Demo morning medication 100 mg / 25 mg tablet'
        : null,
    activeShortageScheduledLabel: shortage ? '8:00 AM' : null,
    activeShortageSlotNumber: shortage ? 2 : null,
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
  if (openDetails) {
    await tester.tap(find.byKey(const ValueKey('robot-face-toggle-details')));
    await tester.pumpAndSettle();
  }
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
        '${face == null ? mode.name : 'lab_${face.name}'}${networkOffline ? '_internetOffline' : ''}${shortage ? '_shortage' : ''}${flipped ? '_flipped' : ''}_${brightness.name}_${scale.toInt()}x_${portrait ? 'portrait' : 'landscape'}${openDetails ? '_open' : '_main'}';
    final paintFinder = find.descendant(
      of: find.byType(RobotFaceCanvas),
      matching: find.byType(CustomPaint),
    );
    final box = tester.renderObject<RenderBox>(paintFinder);
    final dynamic painter = tester.widget<CustomPaint>(paintFinder).painter!;
    final eyes =
        (tester.getSize(find.byKey(RobotFaceScreen.detailRevealKey)).isEmpty
                ? <Rect>[]
                : painter.debugPaintedEyeRects as List<Rect>)
            .map(
              (rect) =>
                  MatrixUtils.transformRect(box.getTransformTo(null), rect),
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
        !openDetails &&
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
    if (!portrait && scale == 1 && !flipped && !openDetails) {
      expect(
        eyes.first.width,
        greaterThan(220),
        reason: '$name ordinary eye scale',
      );
    }
    if (mode == RobotFaceMode.missed && face == null) {
      expect(find.text('MISSED'), findsOneWidget);
      expect(find.text('This dose was missed.'), findsNothing);
      expect(find.text('Missed dose alert'), findsNothing);
      expect(find.text(reminder), openDetails ? findsOneWidget : findsNothing);
      expect(
        find.text(
          'Follow your prescription instructions or ask your caregiver, pharmacist, or doctor.',
        ),
        openDetails ? findsOneWidget : findsNothing,
      );
      final acknowledge = find.byKey(
        RobotFaceScreen.recognizeMissedDoseButtonKey,
      );
      expect(find.text('I saw this missed dose'), findsOneWidget);
      expect(tester.getSize(acknowledge).height, greaterThanOrEqualTo(48));
      final acknowledgeRect = tester.getRect(acknowledge);
      expect(
        acknowledgeRect.overlaps(
          tester.getRect(find.byKey(RobotFaceScreen.exitButtonKey)),
        ),
        isFalse,
      );
      for (final eye in eyes) {
        expect(eye.overlaps(acknowledgeRect), isFalse);
      }
      if (!portrait && scale == 1 && !flipped && !openDetails) {
        // Actual painted bounds, not just a larger empty canvas reservation.
        expect(eyes.first.width, greaterThan(260));
        expect(eyes.first.height, greaterThan(140));
      }
    }
    {
      for (final action in state.availableActions) {
        final key = switch (action) {
          RobotFaceActionKind.confirmTaken =>
            RobotFaceScreen.confirmTakenButtonKey,
          RobotFaceActionKind.skipDose => RobotFaceScreen.skipDoseButtonKey,
          RobotFaceActionKind.askForHelp => RobotFaceScreen.needHelpButtonKey,
          RobotFaceActionKind.recognizeMissedDose =>
            RobotFaceScreen.recognizeMissedDoseButtonKey,
        };
        expect(find.byKey(key).hitTestable(), findsOneWidget);
      }
      expect(
        find.byTooltip(openDetails ? 'Hide details' : 'Show details'),
        findsOneWidget,
      );
      if (minimal) {
        expect(
          find.text(reminder),
          openDetails ? findsOneWidget : findsNothing,
        );
        expect(
          find.text(status),
          openDetails && mode != RobotFaceMode.missed
              ? findsOneWidget
              : findsNothing,
        );
      }
      final toggle = find.byKey(const ValueKey('robot-face-toggle-details'));
      expect(toggle.hitTestable(), findsOneWidget);
      expect(tester.getSize(toggle), const Size(48, 48));
      final exitRect = tester.getRect(
        find.byKey(RobotFaceScreen.exitButtonKey),
      );
      expect(exitRect.width, greaterThanOrEqualTo(48));
      expect(exitRect.height, greaterThanOrEqualTo(48));
      expect(
        surface.contains(exitRect.topLeft) &&
            surface.contains(exitRect.bottomRight),
        isTrue,
      );
      expect(tester.getRect(toggle).overlaps(exitRect), isFalse);
      for (final eye in eyes) {
        expect(eye.overlaps(tester.getRect(toggle)), isFalse);
      }
      for (final key in [
        RobotFaceScreen.recognizeMissedDoseButtonKey,
        RobotFaceScreen.confirmTakenButtonKey,
        RobotFaceScreen.skipDoseButtonKey,
        RobotFaceScreen.needHelpButtonKey,
      ]) {
        final control = find.byKey(key);
        if (control.evaluate().isEmpty) continue;
        expect(control.hitTestable(), findsOneWidget);
        expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
        for (final eye in eyes) {
          expect(eye.overlaps(tester.getRect(control)), isFalse);
        }
      }
      if (shortage && !openDetails) {
        expect(
          find
              .text(
                'SHORTAGE · Check loading · Controller fault · Ask caregiver',
              )
              .hitTestable(),
          findsOneWidget,
        );
      }
      if (mode == RobotFaceMode.error &&
          face == null &&
          !shortage &&
          !openDetails) {
        expect(find.text('Device problem · Ask caregiver'), findsOneWidget);
      }
    }
    if (openDetails) {
      final detailTexts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(RobotFaceScreen.bottomCardKey),
              matching: find.byType(Text),
            ),
          )
          .toList();
      for (final text in detailTexts) {
        if (text.key == const ValueKey('robot-face-more-details')) continue;
        await robotFaceExpectEveryWordReachable(tester, find.byWidget(text));
      }
      expect(find.textContaining(state.nextEventLabel), findsWidgets);
      if (state.statusLabel != null && state.mode != RobotFaceMode.missed) {
        expect(find.textContaining(state.statusLabel!), findsWidgets);
      }
      if (shortage) {
        expect(
          find.textContaining(state.activeShortageMedicationLabel!),
          findsWidgets,
        );
      }
    }
    if (!openDetails) {
      final warning = switch (state.controllerCondition) {
        RobotFaceControllerCondition.fault => 'Controller fault',
        RobotFaceControllerCondition.bluetoothUnavailable =>
          'Bluetooth unavailable',
        RobotFaceControllerCondition.disconnected => 'Controller disconnected',
        RobotFaceControllerCondition.offline => 'Controller offline',
        RobotFaceControllerCondition.connecting => 'Controller connecting',
        RobotFaceControllerCondition.reconnecting => 'Controller reconnecting',
        RobotFaceControllerCondition.verifying => 'Controller verifying',
        _ => null,
      };
      if (warning != null) {
        expect(find.textContaining(warning).hitTestable(), findsWidgets);
      }
      final card = find.byKey(RobotFaceScreen.bottomCardKey);
      final visible = tester.getRect(card).inflate(0.001);
      for (final paragraph in tester.renderObjectList<RenderParagraph>(
        find.descendant(of: card, matching: find.byType(RichText)),
      )) {
        for (final word in RegExp(
          r'\S+',
        ).allMatches(paragraph.text.toPlainText())) {
          for (final box in paragraph.getBoxesForSelection(
            TextSelection(baseOffset: word.start, extentOffset: word.end),
          )) {
            final rect = MatrixUtils.transformRect(
              paragraph.getTransformTo(null),
              box.toRect(),
            );
            expect(
              visible.contains(rect.topLeft) &&
                  visible.contains(rect.bottomRight),
              isTrue,
              reason:
                  '$name main warning glyph must not require disclosure/scroll',
            );
          }
        }
      }
    }
    final geometry = {
      'scale': scale,
      'portrait': portrait,
      'flipped': flipped,
      'shortage': shortage,
      'controls': {
        for (final key in [
          RobotFaceScreen.exitButtonKey,
          const ValueKey('robot-face-toggle-details'),
          RobotFaceScreen.needHelpButtonKey,
          RobotFaceScreen.confirmTakenButtonKey,
          RobotFaceScreen.skipDoseButtonKey,
          RobotFaceScreen.recognizeMissedDoseButtonKey,
        ])
          if (find.byKey(key).evaluate().isNotEmpty)
            key.toString(): rectData(tester.getRect(find.byKey(key))),
      },
      'detailsOpen': openDetails,
      'visibleText': tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .whereType<String>()
          .toList(),
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
    semantics.dispose();
    if (directory != null) {
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
    if (minimal && openDetails) {
      await tester.tap(find.byKey(const ValueKey('robot-face-toggle-details')));
      await tester.pumpAndSettle();
      expect(find.text(reminder), findsNothing);
      expect(find.byTooltip('Show details'), findsOneWidget);
      Focus.of(tester.element(find.byIcon(Icons.info_outline))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text(reminder), findsOneWidget);
      expect(find.byTooltip('Hide details'), findsOneWidget);
    }
  }
}
