import 'dart:async';
import 'dart:ui' as ui;

import 'package:dosey_app/features/robot_face/robot_face_canvas.dart';
import 'package:dosey_app/features/robot_face/robot_face_screen.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'robot_face_golden_path.dart';
import 'robot_face_test_font.dart';

const _idle = RobotFaceState(
  mode: RobotFaceMode.idle,
  nextEventLabel: 'No reminders scheduled',
  isFlipped: false,
  isLandscapeOnly: true,
  rampProgress: 0,
  isInAwakeWindow: true,
);
const _ready = RobotFaceState(
  mode: RobotFaceMode.doseReady,
  nextEventLabel: 'Now · Morning meds',
  isFlipped: false,
  isLandscapeOnly: true,
  rampProgress: 1,
  isInAwakeWindow: true,
  actionDoseId: 'dose-1',
  availableActions: {RobotFaceActionKind.confirmTaken},
);
const _flipped = RobotFaceState(
  mode: RobotFaceMode.idle,
  nextEventLabel: 'No reminders scheduled',
  isFlipped: true,
  isLandscapeOnly: true,
  rampProgress: 0,
  isInAwakeWindow: true,
);
const _missed = RobotFaceState(
  mode: RobotFaceMode.missed,
  nextEventLabel: '8:00 AM · Morning meds',
  isFlipped: false,
  isLandscapeOnly: true,
  rampProgress: 1,
  isInAwakeWindow: true,
  actionDoseId: 'dose-1',
  availableActions: {RobotFaceActionKind.recognizeMissedDose},
);

void main() {
  for (final viewport in [const Size(800, 400), const Size(400, 800)]) {
    testWidgets(
      'square physical rectangle is invariant across flips in $viewport',
      (tester) async {
        await _setViewport(tester, viewport);
        Rect? initial;
        for (final flipped in [false, true]) {
          await tester.pumpWidget(
            _FaceTestApp(
              key: ValueKey(flipped),
              state: _ready.copyWith(isFlipped: flipped),
              padding: const EdgeInsets.fromLTRB(83, 31, 97, 149),
              textScaler: TextScaler.linear(2),
              reducedMotion: true,
            ),
          );
          final rect = _rect(tester, RobotFaceScreen.urgentPromptSurfaceKey);
          expect(rect, const Rect.fromLTWH(91, 39, 64, 64));
          if (initial != null) expect(rect, initial);
          initial = rect;
          expect(
            rect.overlaps(_rect(tester, RobotFaceScreen.bottomCardKey)),
            isFalse,
          );
          expect(
            rect.overlaps(_rect(tester, RobotFaceScreen.confirmTakenButtonKey)),
            isFalse,
          );
        }
      },
    );
  }
  testWidgets(
    'required reminder and fault survive constrained large text and reveal',
    (tester) async {
      const viewport = Size(800, 400);
      const padding = EdgeInsets.fromLTRB(83, 31, 97, 149);
      final semantics = tester.ensureSemantics();
      try {
        await _setViewport(tester, viewport);
        await tester.pumpWidget(
          _FaceTestApp(
            state: _ready.copyWith(
              mode: RobotFaceMode.error,
              controllerCondition: RobotFaceControllerCondition.fault,
              statusLabel: 'Controller fault',
              availableActions: {RobotFaceActionKind.askForHelp},
            ),
            padding: padding,
            textScaler: TextScaler.linear(2),
            reducedMotion: true,
          ),
        );
        for (final label in ['Now · Morning meds', 'Controller fault']) {
          expect(find.text(label).hitTestable(), findsOneWidget);
          expect(find.bySemanticsLabel(label), findsOneWidget);
        }
        await tester.tap(find.byKey(RobotFaceScreen.bottomCardKey));
        await tester.pump();
        expect(find.text('Controller fault').hitTestable(), findsOneWidget);
        final status = _rect(tester, RobotFaceScreen.bottomCardKey);
        final action = _rect(tester, RobotFaceScreen.needHelpButtonKey);
        expect(status.overlaps(action), isFalse);
        for (final rect in _faceRects(tester)) {
          expect(status.overlaps(rect), isFalse);
          expect(action.overlaps(rect), isFalse);
        }
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'glyph containment rejects a visibly clipped unbroken identifier',
    (tester) async {
      await tester.runAsync(loadRobotFaceTestFont);
      const identifier = 'VISIBLE_IDENTIFIER_100mg/25mg!';
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 70,
              height: 20,
              child: ClipRect(
                key: ValueKey('glyph-clip'),
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  maxWidth: double.infinity,
                  maxHeight: double.infinity,
                  child: Text(
                    identifier,
                    textScaler: TextScaler.linear(2),
                    style: TextStyle(
                      fontFamily: robotFaceTestFont,
                      fontSize: 12,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(identifier),
      );
      expect(
        _textGlyphsFit(paragraph, tester.getRect(find.text(identifier))),
        isTrue,
      );
      expect(
        _textGlyphsFit(
          paragraph,
          tester.getRect(find.byKey(const ValueKey('glyph-clip'))),
        ),
        isFalse,
      );
    },
  );

  for (final viewport in [
    const Size(800, 400),
    const Size(400, 800),
    const Size(800, 360),
    const Size(360, 800),
  ]) {
    for (final flipped in [false, true]) {
      for (final longLabel
          in viewport.shortestSide == 360 ? [false] : [false, true]) {
        for (final brightness in Brightness.values) {
          final medication = longLabel
              ? 'Demo extended-release morning medication 100 mg / 25 mg combination tablet'
              : 'Demo medication';
          testWidgets(
            'severe 200% fault and shortage are fully visible $viewport flipped=$flipped long=$longLabel $brightness',
            (tester) async {
              final semantics = tester.ensureSemantics();
              try {
                await _setViewport(tester, viewport);
                await tester.runAsync(loadRobotFaceTestFont);
                await tester.pumpWidget(
                  _FaceTestApp(
                    fontFamily: robotFaceTestFont,
                    brightness: brightness,
                    withExit: true,
                    state: _ready.copyWith(
                      mode: RobotFaceMode.error,
                      isFlipped: flipped,
                      controllerCondition: RobotFaceControllerCondition.fault,
                      statusLabel: 'Controller fault. Ask for help.',
                      availableActions: {RobotFaceActionKind.askForHelp},
                      hasPinnedShortageAlert: true,
                      activeShortageMedicationLabel: medication,
                      networkAdvisory: longLabel
                          ? RobotFaceNetworkAdvisory.internetOffline
                          : null,
                      activeShortageScheduledLabel: '8:00 AM',
                      activeShortageSlotNumber: 2,
                    ),
                    padding: const EdgeInsets.fromLTRB(83, 31, 97, 149),
                    textScaler: TextScaler.linear(2),
                    reducedMotion: true,
                  ),
                );
                final textFinder = find.descendant(
                  of: find.byKey(RobotFaceScreen.bottomCardKey),
                  matching: find.byType(Text),
                );
                expect(textFinder, findsOneWidget);
                final statusText = tester.widget<Text>(textFinder);
                expect(statusText.style!.fontSize, 12);
                expect(statusText.style!.height, 1.2);
                final label = statusText.data!;
                final text = tester.getRect(textFinder);
                final status = _rect(tester, RobotFaceScreen.bottomCardKey);
                final action = _rect(tester, RobotFaceScreen.needHelpButtonKey);
                debugPrint(
                  'Full-containment measurement long=$longLabel text=$text status=$status action=$action viewport=$viewport',
                );
                for (final meaning in [
                  'Now · Morning meds',
                  'Controller fault. Ask for help.',
                  'Shortage:',
                  medication,
                  if (longLabel)
                    'Internet offline. Local reminders still work.',
                  '8:00 AM',
                  'Slot 2',
                  'Local only',
                  'pinned until loading is handled',
                  'Check Carousel loading before dispense',
                ]) {
                  expect(label, contains(meaning));
                }
                expect(find.bySemanticsLabel(label), findsOneWidget);
                expect(find.text('Need help').hitTestable(), findsOneWidget);
                final helpParagraph = tester.renderObject<RenderParagraph>(
                  find.text('Need help'),
                );
                debugPrint(
                  'Help label style=${helpParagraph.text.style} size=${helpParagraph.size}',
                );
                // Soft-wrapped trailing spaces have selection boxes outside the
                // line; check every visible word, plus the whole paragraph box.
                final helpTextRect = tester.getRect(find.text('Need help'));
                expect(
                  action.inflate(0.001).contains(helpTextRect.topLeft),
                  isTrue,
                );
                expect(
                  action.inflate(0.001).contains(helpTextRect.bottomRight),
                  isTrue,
                );
                expect(helpParagraph.text.style!.fontSize, 12);
                expect(helpParagraph.textScaler.scale(12), 24);
                expect(_textGlyphsFit(helpParagraph, action), isTrue);
                expect(
                  tester
                      .widget<FilledButton>(
                        find.byKey(RobotFaceScreen.needHelpButtonKey),
                      )
                      .style!
                      .shape!
                      .resolve({}),
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                );
                final paragraph = tester.renderObject<RenderParagraph>(
                  textFinder,
                );
                expect(paragraph.textScaler.scale(12), 24);
                expect(_textGlyphsFit(paragraph, status), isTrue);
                expect(
                  tester
                      .state<ScrollableState>(
                        find.descendant(
                          of: find.byKey(RobotFaceScreen.bottomCardKey),
                          matching: find.byType(Scrollable),
                        ),
                      )
                      .position
                      .maxScrollExtent,
                  0,
                );
                final prompt = _rect(
                  tester,
                  RobotFaceScreen.urgentPromptSurfaceKey,
                );
                debugPrint(
                  'Severe measured text=$text status=$status action=$action viewport=$viewport',
                );
                expect(status.inflate(0.001).contains(text.topLeft), isTrue);
                expect(
                  status.inflate(0.001).contains(text.bottomRight),
                  isTrue,
                );
                expect(textFinder.hitTestable(), findsOneWidget);
                expect(action.shortestSide, greaterThanOrEqualTo(48 - 0.001));
                expect(text.overlaps(action), isFalse);
                expect(prompt.overlaps(text), isFalse);
                expect(prompt.overlaps(action), isFalse);
                final exit = _rect(tester, RobotFaceScreen.exitButtonKey);
                expect(exit.shortestSide, greaterThanOrEqualTo(48));
                expect(
                  tester
                      .widget<RotatedBox>(
                        find.descendant(
                          of: find.byKey(RobotFaceScreen.exitButtonKey),
                          matching: find.byType(RotatedBox),
                        ),
                      )
                      .quarterTurns,
                  (viewport.height > viewport.width ? 1 : 0) +
                      (flipped ? 2 : 0),
                );
                expect(exit.overlaps(prompt), isFalse);
                expect(exit.overlaps(text), isFalse);
                expect(exit.overlaps(action), isFalse);
                expect(find.bySemanticsLabel('Open Today'), findsOneWidget);
                expect(prompt, const Rect.fromLTWH(91, 39, 64, 64));
                final safe = Rect.fromLTRB(
                  83,
                  31,
                  viewport.width - 97,
                  viewport.height - 149,
                );
                for (final rect in [text, action, prompt, exit]) {
                  expect(safe.contains(rect.topLeft), isTrue);
                  expect(safe.contains(rect.bottomRight), isTrue);
                }
                final exitStyle = tester
                    .widget<IconButton>(
                      find.byKey(RobotFaceScreen.exitButtonKey),
                    )
                    .style!;
                final foreground = exitStyle.foregroundColor!.resolve({})!;
                final background = exitStyle.backgroundColor!.resolve({})!;
                expect(foreground, const Color(0xFFD5F4FF));
                expect(background, const Color(0xED102A43));
                expect(
                  (foreground.computeLuminance() + 0.05) /
                      (background.computeLuminance() + 0.05),
                  greaterThan(7),
                );
                expect(
                  tester
                      .widget<Icon>(
                        find.descendant(
                          of: find.byKey(RobotFaceScreen.exitButtonKey),
                          matching: find.byType(Icon),
                        ),
                      )
                      .icon,
                  Icons.arrow_back_rounded,
                );
                await tester.tap(find.byKey(RobotFaceScreen.bottomCardKey));
                await tester.pump();
                expect(tester.getRect(textFinder), text);
                expect(find.bySemanticsLabel(label), findsOneWidget);
                expect(tester.takeException(), isNull);
              } finally {
                semantics.dispose();
              }
            },
          );
        }
      }
    }
  }

  for (final viewport in [
    const Size(720, 360),
    const Size(360, 720),
    const Size(640, 320),
    const Size(320, 640),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final flipped in [false, true]) {
        for (final brightness in Brightness.values) {
          for (final medication in [
            'Demo metformin extended-release 500 mg tablet',
            'Demo lisinopril / hydrochlorothiazide 20 mg / 12.5 mg tablet',
          ]) {
            testWidgets(
              'bounded real-font $viewport scale=$scale flipped=$flipped $brightness $medication',
              (tester) async {
                final semantics = tester.ensureSemantics();
                try {
                  await _setViewport(tester, viewport);
                  await tester.runAsync(loadRobotFaceTestFont);
                  const padding = EdgeInsets.fromLTRB(16, 24, 16, 24);
                  await tester.pumpWidget(
                    _FaceTestApp(
                      fontFamily: robotFaceTestFont,
                      brightness: brightness,
                      withExit: true,
                      padding: padding,
                      textScaler: TextScaler.linear(scale),
                      reducedMotion: true,
                      state: _ready.copyWith(
                        mode: RobotFaceMode.error,
                        isFlipped: flipped,
                        controllerCondition: RobotFaceControllerCondition.fault,
                        statusLabel: 'Controller fault. Ask for help.',
                        availableActions: {RobotFaceActionKind.askForHelp},
                        hasPinnedShortageAlert: true,
                        activeShortageMedicationLabel: medication,
                        activeShortageScheduledLabel: '8:00 AM',
                        activeShortageSlotNumber: 2,
                        networkAdvisory:
                            RobotFaceNetworkAdvisory.internetOffline,
                      ),
                    ),
                  );
                  final finder = find.descendant(
                    of: find.byKey(RobotFaceScreen.bottomCardKey),
                    matching: find.byType(Text),
                  );
                  final text = tester.widget<Text>(finder);
                  for (final meaning in [
                    'Now · Morning meds',
                    'Controller fault. Ask for help.',
                    medication,
                    '8:00 AM',
                    'Slot 2',
                    'Local only; pinned until loading is handled. Check Carousel loading before dispense.',
                    'Internet offline. Local reminders still work.',
                  ]) {
                    expect(text.data, contains(meaning));
                  }
                  expect(find.bySemanticsLabel(text.data!), findsOneWidget);
                  expect(text.style!.fontSize, 12);
                  expect(text.style!.height, 1.2);
                  final paragraph = tester.renderObject<RenderParagraph>(
                    finder,
                  );
                  expect(paragraph.textScaler.scale(12), 12 * scale);
                  final card = _rect(tester, RobotFaceScreen.bottomCardKey);
                  final rect = tester.getRect(finder);
                  debugPrint(
                    'Bounded content viewport=$viewport scale=$scale label=$medication text=$rect status=$card',
                  );
                  expect(card.inflate(0.001).contains(rect.topLeft), isTrue);
                  expect(
                    card.inflate(0.001).contains(rect.bottomRight),
                    isTrue,
                  );
                  expect(_textGlyphsFit(paragraph, card), isTrue);
                  expect(
                    tester
                        .state<ScrollableState>(
                          find.descendant(
                            of: find.byKey(RobotFaceScreen.bottomCardKey),
                            matching: find.byType(Scrollable),
                          ),
                        )
                        .position
                        .maxScrollExtent,
                    0,
                  );
                  final action = _rect(
                    tester,
                    RobotFaceScreen.needHelpButtonKey,
                  );
                  final exit = _rect(tester, RobotFaceScreen.exitButtonKey);
                  final badge = _rect(
                    tester,
                    RobotFaceScreen.urgentPromptSurfaceKey,
                  );
                  for (final target in [action, exit]) {
                    expect(target.shortestSide, greaterThanOrEqualTo(48));
                  }
                  final surfaces = [card, action, exit, badge];
                  for (var i = 0; i < surfaces.length; i++) {
                    _expectInsideSafeBounds(surfaces[i], padding, viewport);
                    for (var j = i + 1; j < surfaces.length; j++) {
                      expect(surfaces[i].overlaps(surfaces[j]), isFalse);
                    }
                    for (final eye in _faceRects(tester)) {
                      expect(surfaces[i].overlaps(eye), isFalse);
                    }
                  }
                  expect(find.text('Need help').hitTestable(), findsOneWidget);
                  expect(find.bySemanticsLabel('Open Today'), findsOneWidget);
                  expect(tester.takeException(), isNull);
                } finally {
                  semantics.dispose();
                }
              },
            );
          }
        }
      }
    }
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('non-shortage compact descender ink scale=$scale', (
      tester,
    ) async {
      await _setViewport(tester, const Size(800, 400));
      await tester.runAsync(loadRobotFaceTestFont);
      const label = 'Normal glyphs: Agjpqy / 100 mg.';
      await tester.pumpWidget(
        _FaceTestApp(
          fontFamily: robotFaceTestFont,
          textScaler: TextScaler.linear(scale),
          padding: const EdgeInsets.fromLTRB(83, 31, 97, 149),
          reducedMotion: true,
          state: _ready.copyWith(
            mode: RobotFaceMode.error,
            statusLabel: label,
            availableActions: {RobotFaceActionKind.askForHelp},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      final style = tester.widget<Text>(find.text(label)).style!;
      final width = paragraph.size.width;
      final card = _rect(tester, RobotFaceScreen.bottomCardKey);
      final top = paragraph.localToGlobal(Offset.zero).dy;
      final allocatedBottom = card.bottom - top;
      final allocatedTop = card.top - top;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: const ValueKey('non-shortage-reference'),
              child: ColoredBox(
                color: Colors.black,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    width: width,
                    child: Text(
                      label,
                      textScaler: TextScaler.linear(scale),
                      style: style.copyWith(
                        fontFamily: robotFaceTestFont,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('non-shortage-reference')),
      );
      final rows = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          var first = image.height;
          var last = -1;
          for (var y = 0; y < image.height; y++) {
            for (var x = 0; x < image.width; x++) {
              if (bytes.getUint8((y * image.width + x) * 4) > 0) {
                if (y < first) first = y;
                last = y;
              }
            }
          }
          return [first - 8, last - 8];
        } finally {
          image.dispose();
        }
      });
      debugPrint(
        'Non-shortage scale=$scale ink=$rows allocated=$allocatedTop..$allocatedBottom',
      );
      expect(rows![0], greaterThanOrEqualTo(allocatedTop));
      expect(rows[1], lessThan(allocatedBottom));
    });
  }

  for (final startsOverflowing in [false, true]) {
    testWidgets('idle metrics schedule hint frame overflow=$startsOverflowing', (
      tester,
    ) async {
      await _setViewport(tester, const Size(800, 360));
      await tester.pumpWidget(
        _FaceTestApp(
          reducedMotion: true,
          textScaler: TextScaler.linear(2),
          padding: const EdgeInsets.fromLTRB(83, 31, 97, 149),
          state: _ready.copyWith(
            mode: RobotFaceMode.error,
            nextEventLabel: startsOverflowing
                ? 'Reminder details ' * 30
                : 'Reminder',
            availableActions: {RobotFaceActionKind.askForHelp},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = find.descendant(
        of: find.byKey(RobotFaceScreen.bottomCardKey),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scroll).position;
      expect(position.maxScrollExtent > 0, startsOverflowing);
      expect(tester.binding.hasScheduledFrame, isFalse);
      // Replay the native post-frame microtask delivery after unrelated startup
      // frames have settled. No pump may supply the frame under test.
      final context = tester.element(scroll);
      scheduleMicrotask(
        () => ScrollMetricsNotification(
          metrics: position.copyWith(
            maxScrollExtent: startsOverflowing ? 0 : 1000,
            viewportDimension: startsOverflowing
                ? 0
                : position.viewportDimension,
          ),
          context: context,
        ).dispatch(context),
      );
      await tester.idle();
      expect(
        tester.binding.hasScheduledFrame,
        isTrue,
        reason: startsOverflowing
            ? 'Fit metrics must request a frame'
            : 'Initial overflow metrics must request a frame',
      );
      // A newer measurement returning to the current state cancels the stale
      // pending change; it must not schedule another rebuild in the callback.
      ScrollMetricsNotification(
        metrics: position.copyWith(),
        context: context,
      ).dispatch(context);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(
        find.text('Scroll for more details').hitTestable(),
        startsOverflowing ? findsOneWidget : findsNothing,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final viewport in [const Size(800, 360), const Size(720, 360)]) {
    for (final flipped in [false, true]) {
      for (final brightness in Brightness.values) {
        testWidgets('scroll fallback $viewport $flipped $brightness', (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          try {
            await _setViewport(tester, viewport);
            await tester.runAsync(loadRobotFaceTestFont);
            const padding = EdgeInsets.fromLTRB(83, 31, 97, 149);
            const medication =
                'Demo extended-release morning medication 100 mg / 25 mg combination tablet';
            await tester.pumpWidget(
              _FaceTestApp(
                fontFamily: robotFaceTestFont,
                brightness: brightness,
                withExit: true,
                textScaler: TextScaler.linear(2),
                padding: padding,
                reducedMotion: true,
                state: _ready.copyWith(
                  mode: RobotFaceMode.error,
                  isFlipped: flipped,
                  statusLabel: 'Controller fault. Ask for help.',
                  availableActions: {RobotFaceActionKind.askForHelp},
                  hasPinnedShortageAlert: true,
                  activeShortageMedicationLabel: medication,
                  activeShortageScheduledLabel: '8:00 AM',
                  activeShortageSlotNumber: 2,
                  networkAdvisory: RobotFaceNetworkAdvisory.internetOffline,
                ),
              ),
            );
            // Metrics arrive after layout. Do not lend the hint a forced pump:
            // reduced motion must schedule its own follow-up frame.
            expect(
              tester.binding.hasScheduledFrame,
              isTrue,
              reason: 'Initial overflow metrics must request a frame',
            );
            await tester.pumpAndSettle();
            final card = find.byKey(RobotFaceScreen.bottomCardKey);
            final scroll = find.descendant(
              of: card,
              matching: find.byType(Scrollable),
            );
            final position = tester.state<ScrollableState>(scroll).position;
            final details = find.descendant(
              of: card,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Text &&
                    (widget.data?.contains(medication) ?? false),
              ),
            );
            final text = tester.widget<Text>(details);
            for (final meaning in [
              'Now · Morning meds',
              'Controller fault. Ask for help.',
              medication,
              '8:00 AM',
              'Slot 2',
              'Local only; pinned until loading is handled. Check Carousel loading before dispense.',
              'Internet offline. Local reminders still work.',
            ]) {
              expect(text.data, contains(meaning));
            }
            expect(find.bySemanticsLabel(text.data!), findsOneWidget);
            final paragraph = tester.renderObject<RenderParagraph>(details);
            expect(paragraph.textScaler.scale(12), 24);
            expect(text.style!.fontSize, 12);
            expect(text.style!.height, 1.2);
            expect(position.maxScrollExtent, greaterThan(0));
            expect(
              find.text('Scroll for more details').hitTestable(),
              findsOneWidget,
            );
            await _expectScrollGolden(
              tester,
              'goldens/robot_face_scroll_${viewport.width.toInt()}_${flipped}_${brightness.name}_start.png',
            );
            final pinnedKeys = [
              RobotFaceScreen.urgentPromptSurfaceKey,
              RobotFaceScreen.needHelpButtonKey,
              RobotFaceScreen.exitButtonKey,
            ];
            final pinned = pinnedKeys.map((key) => _rect(tester, key)).toList();
            expect(pinned.first, const Rect.fromLTWH(91, 39, 64, 64));
            final surfaces = [...pinned, tester.getRect(card)];
            for (var i = 0; i < surfaces.length; i++) {
              _expectInsideSafeBounds(surfaces[i], padding, viewport);
              for (var j = i + 1; j < surfaces.length; j++) {
                expect(surfaces[i].overlaps(surfaces[j]), isFalse);
              }
            }
            for (final target in pinned.skip(1)) {
              expect(target.shortestSide, greaterThanOrEqualTo(48 - 0.001));
            }
            // Native semantics must offer forward scrolling, not just a visual hint.
            final scrollNodes = <SemanticsNode>[];
            void collect(SemanticsNode node) {
              if (node.getSemanticsData().hasAction(SemanticsAction.scrollUp) ||
                  node.getSemanticsData().hasAction(
                    SemanticsAction.scrollDown,
                  )) {
                scrollNodes.add(node);
              }
              node.visitChildren((child) {
                collect(child);
                return true;
              });
            }

            collect(tester.getSemantics(scroll));
            expect(scrollNodes, isNotEmpty);
            final scrollNode = scrollNodes.first;
            scrollNode.owner!.performAction(
              scrollNode.id,
              scrollNode.getSemanticsData().hasAction(SemanticsAction.scrollUp)
                  ? SemanticsAction.scrollUp
                  : SemanticsAction.scrollDown,
            );
            await tester.pumpAndSettle();
            expect(position.pixels, greaterThan(0));
            // Every complete word box must enter the viewport during traversal.
            final boxes = <ui.TextBox>[
              for (final word in RegExp(r'\S+').allMatches(text.data!))
                ...paragraph.getBoxesForSelection(
                  TextSelection(baseOffset: word.start, extentOffset: word.end),
                ),
            ];
            final reached = <int>{};
            final extent = position.maxScrollExtent;
            for (
              double offset = 0;
              offset < extent + position.viewportDimension / 2;
              offset += position.viewportDimension / 2
            ) {
              position.jumpTo(offset.clamp(0, extent));
              await tester.pumpAndSettle();
              final visible = tester
                  .getRect(
                    find.descendant(
                      of: card,
                      matching: find.byType(SingleChildScrollView),
                    ),
                  )
                  .inflate(0.001);
              for (var i = 0; i < boxes.length; i++) {
                final rect = MatrixUtils.transformRect(
                  paragraph.getTransformTo(null),
                  boxes[i].toRect(),
                );
                if (visible.contains(rect.topLeft) &&
                    visible.contains(rect.bottomRight)) {
                  reached.add(i);
                }
              }
              for (var i = 0; i < pinnedKeys.length; i++) {
                expect(_rect(tester, pinnedKeys[i]), pinned[i]);
              }
            }
            expect(reached.length, boxes.length);
            position.jumpTo(extent);
            await tester.pumpAndSettle();
            expect(position.extentAfter, 0);
            await _expectScrollGolden(
              tester,
              'goldens/robot_face_scroll_${viewport.width.toInt()}_${flipped}_${brightness.name}_end.png',
            );
            expect(
              find.text('Scroll for more details').hitTestable(),
              findsNothing,
            );
            expect(
              tester.getSemantics(card).toStringDeep(),
              isNot(contains('Scroll for more details')),
            );
            for (var i = 0; i < pinnedKeys.length; i++) {
              expect(_rect(tester, pinnedKeys[i]), pinned[i]);
            }
            expect(find.text('Need help').hitTestable(), findsOneWidget);
            position.jumpTo(0);
            await tester.pumpAndSettle();
            expect(
              find.text('Scroll for more details').hitTestable(),
              findsOneWidget,
            );
            expect(tester.binding.hasScheduledFrame, isFalse);
            await _setViewport(tester, const Size(800, 500));
            await tester
                .pump(); // Consume only the frame requested by resizing.
            expect(
              tester.binding.hasScheduledFrame,
              isTrue,
              reason: 'Overflow-to-fit metrics must request their own frame',
            );
            await tester.pumpAndSettle();
            expect(
              tester.state<ScrollableState>(scroll).position,
              same(position),
            );
            expect(position.maxScrollExtent, 0);
            expect(find.text('Scroll for more details'), findsNothing);
            expect(_textGlyphsFit(paragraph, tester.getRect(card)), isTrue);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        });
      }
    }
  }

  for (final sample in [(viewport: const Size(800, 400), scale: 3.0)]) {
    testWidgets(
      'unqualified content capacity is reported, not counted visible $sample',
      (tester) async {
        await _setViewport(tester, sample.viewport);
        await tester.runAsync(loadRobotFaceTestFont);
        const medication =
            'Demo extended-release morning medication 100 mg / 25 mg combination tablet';
        await tester.pumpWidget(
          _FaceTestApp(
            fontFamily: robotFaceTestFont,
            withExit: true,
            textScaler: TextScaler.linear(sample.scale),
            padding: const EdgeInsets.fromLTRB(83, 31, 97, 149),
            reducedMotion: true,
            state: _ready.copyWith(
              mode: RobotFaceMode.error,
              statusLabel: 'Controller fault. Ask for help.',
              availableActions: {RobotFaceActionKind.askForHelp},
              hasPinnedShortageAlert: true,
              activeShortageMedicationLabel: medication,
              activeShortageScheduledLabel: '8:00 AM',
              activeShortageSlotNumber: 2,
              networkAdvisory: RobotFaceNetworkAdvisory.internetOffline,
            ),
          ),
        );
        final finder = find.descendant(
          of: find.byKey(RobotFaceScreen.bottomCardKey),
          matching: find.byType(Text),
        );
        final paragraph = tester.renderObject<RenderParagraph>(finder);
        final viewportHeight = tester
            .getSize(find.byKey(RobotFaceScreen.bottomCardKey))
            .height;
        final requiredStatus = paragraph.size.height + 4 * sample.scale;
        final actionHeight = tester
            .getSize(find.byKey(RobotFaceScreen.needHelpButtonKey))
            .height;
        debugPrint(
          'UNQUALIFIED $sample: textHeight=${paragraph.size.height} paddedStatus=$requiredStatus statusCapacity=$viewportHeight '
          'actions=$actionHeight stackedMinimum=${requiredStatus + actionHeight} deficit=${requiredStatus - viewportHeight}',
        );
        expect(paragraph.text.toPlainText(), contains(medication));
        expect(paragraph.textScaler.scale(12), 12 * sample.scale);
        expect(requiredStatus, greaterThan(viewportHeight));
        expect(
          _textGlyphsFit(
            paragraph,
            _rect(tester, RobotFaceScreen.bottomCardKey),
          ),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('rail rejection remeasures the same action panel at body width', (
    tester,
  ) async {
    await tester.runAsync(loadRobotFaceTestFont);
    await _setViewport(tester, const Size(800, 400));
    await tester.pumpWidget(
      _FaceTestApp(
        fontFamily: robotFaceTestFont,
        reducedMotion: true,
        textScaler: TextScaler.linear(2),
        padding: const EdgeInsets.fromLTRB(83, 31, 97, 149),
        state: _ready.copyWith(
          mode: RobotFaceMode.error,
          availableActions: {RobotFaceActionKind.askForHelp},
        ),
      ),
    );
    final panel = find.byKey(RobotFaceScreen.actionPanelKey);
    final originalState = tester.state(panel);
    expect(_rect(tester, RobotFaceScreen.needHelpButtonKey).height, 66);
    await _setViewport(tester, const Size(800, 360));
    await tester.pump();
    expect(tester.state(panel), same(originalState));
    final action = _rect(tester, RobotFaceScreen.needHelpButtonKey);
    expect(action.height, 48);
    expect(action.width, greaterThan(64));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact action-only is used only without mandatory details', (
    tester,
  ) async {
    await _setViewport(tester, const Size(800, 400));
    await tester.pumpWidget(
      _FaceTestApp(
        state: _ready.copyWith(nextEventLabel: ''),
        textScaler: TextScaler.linear(2),
        reducedMotion: true,
      ),
    );
    expect(_rect(tester, RobotFaceScreen.bottomCardKey).height, 0);
    expect(
      find.byKey(RobotFaceScreen.confirmTakenButtonKey).hitTestable(),
      findsOneWidget,
    );
    expect(
      _rect(tester, RobotFaceScreen.confirmTakenButtonKey).height,
      greaterThanOrEqualTo(48),
    );
  });

  for (final mode in [RobotFaceMode.doseReady, RobotFaceMode.error]) {
    for (final portrait in [false, true]) {
      for (final flipped in [false, true]) {
        for (final constrained in [false, true]) {
          for (final scale in [1.0, 2.0]) {
            testWidgets('$mode portrait=$portrait flipped=$flipped '
                'constrained=$constrained scale=$scale collision geometry', (
              tester,
            ) async {
              final viewport = portrait
                  ? const Size(400, 800)
                  : const Size(800, 400);
              final padding = constrained
                  ? const EdgeInsets.fromLTRB(83, 31, 97, 149)
                  : EdgeInsets.zero;
              final state = _ready.copyWith(
                mode: mode,
                isFlipped: flipped,
                controllerCondition: mode == RobotFaceMode.error
                    ? RobotFaceControllerCondition.fault
                    : null,
                availableActions: mode == RobotFaceMode.error
                    ? {RobotFaceActionKind.askForHelp}
                    : {RobotFaceActionKind.confirmTaken},
              );
              await _setViewport(tester, viewport);
              await tester.pumpWidget(
                _FaceTestApp(
                  state: state,
                  padding: padding,
                  withExit: true,
                  textScaler: TextScaler.linear(scale),
                ),
              );
              final prompt = _rect(
                tester,
                RobotFaceScreen.urgentPromptSurfaceKey,
              );
              final card = _rect(tester, RobotFaceScreen.bottomCardKey);
              final action = _rect(
                tester,
                mode == RobotFaceMode.error
                    ? RobotFaceScreen.needHelpButtonKey
                    : RobotFaceScreen.confirmTakenButtonKey,
              );
              _expectInsideSafeBounds(prompt, padding, viewport);
              _expectInsideSafeBounds(card, padding, viewport);
              _expectInsideSafeBounds(action, padding, viewport);
              expect(action.shortestSide, greaterThanOrEqualTo(48 - 0.001));
              expect(prompt.overlaps(card), isFalse, reason: 'prompt/card');
              expect(prompt.overlaps(action), isFalse, reason: 'prompt/action');
              final exit = _rect(tester, RobotFaceScreen.exitButtonKey);
              _expectInsideSafeBounds(exit, padding, viewport);
              expect(exit.shortestSide, greaterThanOrEqualTo(48 - 0.001));
              expect(exit.overlaps(prompt), isFalse, reason: 'exit/prompt');
              expect(exit.overlaps(card), isFalse, reason: 'exit/status');
              expect(exit.overlaps(action), isFalse, reason: 'exit/action');
              final faceRects = _faceRects(tester);
              for (final rect in faceRects) {
                expect(exit.overlaps(rect), isFalse, reason: 'exit/face');
                expect(
                  prompt.overlaps(rect),
                  isFalse,
                  reason: 'prompt/face $prompt $rect',
                );
                expect(
                  card.overlaps(rect),
                  isFalse,
                  reason: 'card/face $card $rect',
                );
                expect(action.overlaps(rect), isFalse, reason: 'action/face');
              }
              // Sample an ambient cycle using the painter's actual post-cap,
              // post-minimum-height, post-tilt geometry and the fitted transform.
              for (var frame = 0; frame < 13; frame += 1) {
                await tester.pump(const Duration(milliseconds: 400));
                for (final rect in _faceRects(tester)) {
                  expect(
                    prompt.overlaps(rect),
                    isFalse,
                    reason: 'moving prompt/face',
                  );
                  expect(
                    card.overlaps(rect),
                    isFalse,
                    reason: 'moving status/face',
                  );
                  expect(
                    action.overlaps(rect),
                    isFalse,
                    reason: 'moving action/face',
                  );
                }
              }
              if (portrait || flipped || constrained || scale == 2) {
                expect(prompt.width, closeTo(64, 0.001));
                expect(prompt.height, closeTo(64, 0.001));
                final box = tester.renderObject<RenderBox>(
                  find.byKey(RobotFaceScreen.urgentPromptKey),
                );
                final origin = box.localToGlobal(Offset.zero);
                final vector = box.localToGlobal(const Offset(1, 0)) - origin;
                final x = vector / vector.distance;
                final turn = (portrait ? 1 : 0) + (flipped ? 2 : 0);
                const directions = [
                  Offset(1, 0),
                  Offset(0, 1),
                  Offset(-1, 0),
                  Offset(0, -1),
                ];
                expect(x.dx, closeTo(directions[turn].dx, 0.001));
                expect(x.dy, closeTo(directions[turn].dy, 0.001));
              }
              expect(tester.takeException(), isNull);
            });
          }
        }
      }
    }
  }
  testWidgets(
    'landscape background fills viewport, face reserves status space',
    (tester) async {
      await _setViewport(tester, const Size(800, 400));
      await tester.pumpWidget(const _FaceTestApp());
      _expectReservedCanvas(tester, const Size(800, 400));
      _expectViewportRect(
        _rect(tester, RobotFaceScreen.displayFrameKey),
        const Size(800, 400),
      );
      expect(
        _rect(
          tester,
          RobotFaceScreen.canvasKey,
        ).overlaps(_rect(tester, RobotFaceScreen.bottomCardKey)),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('portrait keeps the clockwise viewport rotation at full size', (
    tester,
  ) async {
    await _setViewport(tester, const Size(400, 800));
    await tester.pumpWidget(const _FaceTestApp());
    _expectReservedCanvas(tester, const Size(400, 800));
    _expectViewportRect(
      _rect(tester, RobotFaceScreen.displayFrameKey),
      const Size(400, 800),
    );
    expect(tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait maps physical safe insets into the rotated overlay', (
    tester,
  ) async {
    await _setViewport(tester, const Size(400, 800));
    await tester.pumpWidget(
      const _FaceTestApp(padding: EdgeInsets.fromLTRB(17, 31, 29, 43)),
    );

    _expectReservedCanvas(tester, const Size(400, 800));
    final card = _rect(tester, RobotFaceScreen.bottomCardKey);
    expect(card.left, greaterThanOrEqualTo(17));
    expect(card.top, greaterThanOrEqualTo(31));
    expect(card.right, lessThanOrEqualTo(371));
    expect(card.bottom, lessThanOrEqualTo(757));
    expect(tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns, 1);
  });

  testWidgets('flipped landscape keeps the card inside physical safe insets', (
    tester,
  ) async {
    await _setViewport(tester, const Size(800, 400));
    await tester.pumpWidget(
      const _FaceTestApp(
        state: _flipped,
        padding: EdgeInsets.fromLTRB(17, 31, 29, 43),
        withExit: true,
      ),
    );

    _expectReservedCanvas(tester, const Size(800, 400));
    _expectInsideSafeBounds(
      _rect(tester, RobotFaceScreen.bottomCardKey),
      const EdgeInsets.fromLTRB(17, 31, 29, 43),
      const Size(800, 400),
    );
    expect(
      find.descendant(
        of: find.byKey(RobotFaceScreen.flipTransformKey),
        matching: find.byKey(RobotFaceScreen.bottomCardKey),
      ),
      findsOneWidget,
    );
    expect(
      _rect(tester, RobotFaceScreen.exitButtonKey).topLeft,
      const Offset(29, 43),
    );
  });

  testWidgets('flipped portrait keeps the card inside physical safe insets', (
    tester,
  ) async {
    await _setViewport(tester, const Size(400, 800));
    await tester.pumpWidget(
      const _FaceTestApp(
        state: _flipped,
        padding: EdgeInsets.fromLTRB(17, 31, 29, 43),
        withExit: true,
      ),
    );

    _expectReservedCanvas(tester, const Size(400, 800));
    _expectInsideSafeBounds(
      _rect(tester, RobotFaceScreen.bottomCardKey),
      const EdgeInsets.fromLTRB(17, 31, 29, 43),
      const Size(400, 800),
    );
    expect(tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns, 1);
    expect(
      find.descendant(
        of: find.byKey(RobotFaceScreen.flipTransformKey),
        matching: find.byKey(RobotFaceScreen.bottomCardKey),
      ),
      findsOneWidget,
    );
    expect(
      _rect(tester, RobotFaceScreen.exitButtonKey).topLeft,
      const Offset(29, 43),
    );
  });

  testWidgets(
    'landscape READY prompt follows the top safe inset and stays clear of its marker',
    (tester) async {
      const viewport = Size(800, 400);
      const padding = EdgeInsets.fromLTRB(83, 31, 97, 149);
      await _setViewport(tester, viewport);
      await tester.pumpWidget(
        const _FaceTestApp(state: _ready, padding: padding),
      );

      final prompt = _rect(tester, RobotFaceScreen.urgentPromptSurfaceKey);
      _expectInsideSafeBounds(prompt, padding, viewport);
      _expectPromptClearOfFace(tester, prompt);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'portrait READY prompt stays inside physical safe insets and clear of its marker',
    (tester) async {
      const viewport = Size(400, 800);
      const padding = EdgeInsets.fromLTRB(83, 31, 97, 149);
      await _setViewport(tester, viewport);
      await tester.pumpWidget(
        const _FaceTestApp(state: _ready, padding: padding),
      );

      final prompt = _rect(tester, RobotFaceScreen.urgentPromptSurfaceKey);
      _expectInsideSafeBounds(prompt, padding, viewport);
      _expectPromptClearOfFace(tester, prompt);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'flipped portrait HELP prompt stays inside physical safe insets and clear of its marker',
    (tester) async {
      const viewport = Size(400, 800);
      const padding = EdgeInsets.fromLTRB(83, 31, 97, 149);
      final help = _ready.copyWith(
        mode: RobotFaceMode.error,
        controllerCondition: RobotFaceControllerCondition.fault,
        nextEventLabel: 'Please ask for help',
        isFlipped: true,
        availableActions: {RobotFaceActionKind.askForHelp},
      );
      await _setViewport(tester, viewport);
      await tester.pumpWidget(_FaceTestApp(state: help, padding: padding));

      final prompt = _rect(tester, RobotFaceScreen.urgentPromptSurfaceKey);
      _expectInsideSafeBounds(prompt, padding, viewport);
      _expectPromptClearOfFace(tester, prompt);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'safe insets and 200 percent text reserve space before the face',
    (tester) async {
      await _setViewport(tester, const Size(800, 400));
      await tester.pumpWidget(
        const _FaceTestApp(
          state: _ready,
          padding: EdgeInsets.fromLTRB(24, 18, 30, 20),
          textScaler: TextScaler.linear(2),
          withExit: true,
        ),
      );
      _expectReservedCanvas(tester, const Size(800, 400));
      final card = _rect(tester, RobotFaceScreen.bottomCardKey);
      final exit = _rect(tester, RobotFaceScreen.exitButtonKey);
      expect(card.left, greaterThanOrEqualTo(24));
      expect(card.right, lessThanOrEqualTo(770));
      expect(card.bottom, lessThanOrEqualTo(380));
      expect(exit.left, greaterThanOrEqualTo(24));
      expect(exit.top, greaterThanOrEqualTo(18));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('status overlay reveals details through the face interaction', (
    tester,
  ) async {
    await _setViewport(tester, const Size(800, 400));
    var longPresses = 0;
    await tester.pumpWidget(_FaceTestApp(onLongPress: () => longPresses += 1));
    await tester.tapAt(const Offset(400, 100));
    await tester.pump();
    expect(_canvas(tester).animationRevision, -1);
    await tester.longPressAt(const Offset(400, 100));
    expect(longPresses, 1);
    final revisionAfterLongPress = _canvas(tester).animationRevision;
    await tester.tapAt(
      _rect(tester, RobotFaceScreen.bottomCardKey).topLeft + const Offset(4, 4),
    );
    await tester.pump();
    expect(_canvas(tester).animationRevision, lessThan(revisionAfterLongPress));
  });

  testWidgets('idle details stay compact until the face is tapped', (
    tester,
  ) async {
    await _setViewport(tester, const Size(800, 400));
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const _FaceTestApp());

    expect(
      find.bySemanticsLabel('Robot Face. Tap to show reminder details.'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Current reminder: No reminders scheduled. Tap the face for details.',
      ),
      findsNothing,
    );
    expect(find.text('NEXT EVENT'), findsNothing);

    await tester.tapAt(const Offset(400, 100));
    await tester.pump();

    expect(
      find.bySemanticsLabel('Robot Face. Reminder details are shown.'),
      findsOneWidget,
    );
    expect(find.text('NEXT EVENT'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a new ordinary reminder resets revealed details', (
    tester,
  ) async {
    await _setViewport(tester, const Size(800, 400));
    final states = StreamController<RobotFaceState>.broadcast();
    addTearDown(states.close);
    await tester.pumpWidget(_FaceTestApp(stateStream: states.stream));
    await tester.tapAt(const Offset(400, 100));
    await tester.pump();
    expect(find.text('NEXT EVENT'), findsOneWidget);

    states.add(_idle.copyWith(nextEventLabel: '6:00 PM · Evening meds'));
    await tester.pump();

    expect(find.text('NEXT EVENT'), findsNothing);
    expect(find.text('6:00 PM · Evening meds'), findsOneWidget);
  });

  testWidgets(
    'status hit boundary uses the face interaction while child actions remain usable',
    (tester) async {
      await _setViewport(tester, const Size(800, 400));
      final semantics = tester.ensureSemantics();
      var longPresses = 0;
      await tester.pumpWidget(
        _FaceTestApp(state: _ready, onLongPress: () => longPresses += 1),
      );

      final card = _rect(tester, RobotFaceScreen.bottomCardKey);
      await tester.tapAt(card.topLeft + const Offset(4, 4));
      await tester.longPressAt(card.topLeft + const Offset(4, 4));
      await tester.pump();
      expect(_canvas(tester).animationRevision, lessThan(0));
      expect(longPresses, 0);
      expect(
        find.byKey(RobotFaceScreen.confirmTakenButtonKey).hitTestable(),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('I can see it and took it'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'short safe area scrolls missed status while keeping its action visible',
    (tester) async {
      await _setViewport(tester, const Size(800, 360));
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        const _FaceTestApp(
          state: _missed,
          padding: EdgeInsets.fromLTRB(18, 12, 24, 20),
          textScaler: TextScaler.linear(2),
        ),
      );

      _expectViewportRect(
        _rect(tester, RobotFaceScreen.displayFrameKey),
        const Size(800, 360),
      );
      final scroll = find.byType(SingleChildScrollView);
      final scrollRect = tester.getRect(scroll);
      expect(scrollRect.left, greaterThanOrEqualTo(18));
      expect(scrollRect.right, lessThanOrEqualTo(776));
      expect(scrollRect.bottom, lessThanOrEqualTo(340));
      expect(find.text('This dose was missed.'), findsOneWidget);
      await tester.drag(scroll, const Offset(0, -400));
      await tester.pump();
      expect(
        find.text(
          'Follow your prescription instructions or ask your caregiver, pharmacist, or doctor.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(RobotFaceScreen.recognizeMissedDoseButtonKey).hitTestable(),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('I saw this missed dose'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'action panel returns for a new actionable state and flipped overlay transforms',
    (tester) async {
      await _setViewport(tester, const Size(800, 400));
      final states = StreamController<RobotFaceState>.broadcast();
      addTearDown(states.close);
      await tester.pumpWidget(_FaceTestApp(stateStream: states.stream));
      states.add(_ready);
      await tester.pump();
      states.add(_ready.copyWith(mode: RobotFaceMode.missed));
      await tester.pump();
      states.add(_ready.copyWith(mode: RobotFaceMode.idle, actionDoseId: null));
      await tester.pump();
      states.add(_ready);
      await tester.pump();
      expect(find.byKey(RobotFaceScreen.actionPanelKey), findsOneWidget);
      await tester.pumpWidget(const _FaceTestApp(withExit: true));
      final unflippedCard = _rect(tester, RobotFaceScreen.bottomCardKey);
      await tester.pumpWidget(
        const _FaceTestApp(
          key: ValueKey<String>('flipped-face'),
          state: _flipped,
          withExit: true,
        ),
      );
      expect(
        tester
            .widget<Transform>(find.byKey(RobotFaceScreen.flipTransformKey))
            .transform
            .storage[0],
        lessThan(0),
      );
      expect(
        _rect(tester, RobotFaceScreen.exitButtonKey).topLeft,
        const Offset(12, 12),
      );
      expect(
        _rect(tester, RobotFaceScreen.bottomCardKey).topLeft,
        isNot(unflippedCard.topLeft),
      );
    },
  );

  testWidgets('painted eye bounds survive unchanged-input rebuilds', (
    tester,
  ) async {
    await _setViewport(tester, const Size(800, 400));
    Widget canvas() => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: RobotFaceCanvas(state: _ready),
      ),
    );
    await tester.pumpWidget(canvas());
    final first = _faceRects(tester);
    await tester.pumpWidget(canvas());
    expect(_faceRects(tester), first);
    await tester.pumpWidget(canvas());
    expect(_faceRects(tester), first);
  });

  testWidgets('action panel identity survives a compact state', (tester) async {
    await _setViewport(tester, const Size(800, 400));
    final states = StreamController<RobotFaceState>.broadcast();
    addTearDown(states.close);
    final actionable = _ready.copyWith(
      availableActions: {RobotFaceActionKind.askForHelp},
    );
    await tester.pumpWidget(
      _FaceTestApp(state: actionable, stateStream: states.stream),
    );
    final panel = find.byKey(RobotFaceScreen.actionPanelKey);
    final firstState = tester.state(panel);

    states.add(_idle);
    await tester.pump();
    expect(
      tester.state(
        find.byKey(RobotFaceScreen.actionPanelKey, skipOffstage: false),
      ),
      same(firstState),
    );

    states.add(actionable);
    await tester.pump();
    expect(tester.state(panel), same(firstState));
  });
}

Future<void> _expectScrollGolden(WidgetTester tester, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('face-test-boundary')),
  );
  final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
  try {
    final bytes = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    for (final key in [
      RobotFaceScreen.urgentPromptSurfaceKey,
      RobotFaceScreen.exitButtonKey,
    ]) {
      final interior = _rect(tester, key).deflate(12);
      var ink = 0;
      for (var y = interior.top.ceil(); y < interior.bottom.floor(); y++) {
        for (var x = interior.left.ceil(); x < interior.right.floor(); x++) {
          final offset = (y * image.width + x) * 4;
          if (bytes.getUint8(offset) > 180 &&
              bytes.getUint8(offset + 1) > 90 &&
              bytes.getUint8(offset + 2) > 90) {
            ink++;
          }
        }
      }
      expect(ink, greaterThan(8), reason: 'Pinned surface must paint in $path');
    }
    // Compare the exact inspected image, not a second ancestor-layer capture.
    await expectLater(image, matchesGoldenFile(robotFaceGoldenPath(path)));
  } finally {
    image.dispose();
  }
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

RobotFaceCanvas _canvas(WidgetTester tester) =>
    tester.widget<RobotFaceCanvas>(find.byType(RobotFaceCanvas));
Rect _rect(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));
void _expectReservedCanvas(WidgetTester tester, Size viewport) {
  _expectViewportRect(_rect(tester, RobotFaceScreen.displayFrameKey), viewport);
  final canvas = _rect(tester, RobotFaceScreen.canvasKey);
  _expectInsideSafeBounds(canvas, EdgeInsets.zero, viewport);
  expect(canvas.shortestSide, greaterThan(0));
  expect(
    canvas.overlaps(_rect(tester, RobotFaceScreen.bottomCardKey)),
    isFalse,
  );
}

void _expectViewportRect(Rect rect, Size size) {
  expect(rect.left, closeTo(0, 0.001));
  expect(rect.top, closeTo(0, 0.001));
  expect(rect.width, closeTo(size.width, 0.001));
  expect(rect.height, closeTo(size.height, 0.001));
}

void _expectInsideSafeBounds(Rect rect, EdgeInsets padding, Size size) {
  expect(rect.left, greaterThanOrEqualTo(padding.left));
  expect(rect.top, greaterThanOrEqualTo(padding.top));
  expect(rect.right, lessThanOrEqualTo(size.width - padding.right));
  expect(rect.bottom, lessThanOrEqualTo(size.height - padding.bottom));
}

void _expectPromptClearOfFace(WidgetTester tester, Rect prompt) {
  expect(_faceRects(tester).any(prompt.overlaps), isFalse);
}

List<Rect> _faceRects(WidgetTester tester) {
  final paintFinder = find.descendant(
    of: find.byType(RobotFaceCanvas),
    matching: find.byType(CustomPaint),
  );
  final box = tester.renderObject<RenderBox>(paintFinder);
  final dynamic painter = tester.widget<CustomPaint>(paintFinder).painter!;
  final eyes = painter.debugPaintedEyeRects as List<Rect>;
  expect(eyes, hasLength(2));
  final markers = painter.debugStateMarkerGeometry(box.size) as List<Rect>;
  return <Rect>[...eyes, ...markers.map((rect) => rect.inflate(6))]
      .map((rect) => MatrixUtils.transformRect(box.getTransformTo(null), rect))
      .toList();
}

bool _textGlyphsFit(RenderParagraph paragraph, Rect container) {
  final text = paragraph.text.toPlainText();
  final lines = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
  if (lines.isEmpty) return false;
  // Check full line metrics against the allocated visible region, including
  // reserved edge padding. Word checks still include all visible punctuation.
  final localBounds = MatrixUtils.transformRect(
    Matrix4.inverted(paragraph.getTransformTo(null)),
    container,
  ).inflate(0.001);
  for (final line in lines) {
    if (line.top < localBounds.top || line.bottom > localBounds.bottom) {
      debugPrint(
        'Glyph line ${line.toRect()} outside visible local bounds $localBounds',
      );
      return false;
    }
  }
  final bounds = container.inflate(0.001);
  for (final word in RegExp(r'\S+').allMatches(text)) {
    for (final box in paragraph.getBoxesForSelection(
      TextSelection(baseOffset: word.start, extentOffset: word.end),
    )) {
      final glyph = MatrixUtils.transformRect(
        paragraph.getTransformTo(null),
        box.toRect(),
      );
      if (!bounds.contains(glyph.topLeft) ||
          !bounds.contains(glyph.bottomRight)) {
        return false;
      }
    }
  }
  return true;
}

class _FaceTestApp extends StatelessWidget {
  const _FaceTestApp({
    super.key,
    this.state = _idle,
    this.stateStream,
    this.padding = EdgeInsets.zero,
    this.textScaler = TextScaler.noScaling,
    this.withExit = false,
    this.reducedMotion = false,
    this.onLongPress,
    this.fontFamily,
    this.brightness = Brightness.light,
  });
  final RobotFaceState state;
  final Stream<RobotFaceState>? stateStream;
  final EdgeInsets padding;
  final TextScaler textScaler;
  final bool withExit;
  final bool reducedMotion;
  final VoidCallback? onLongPress;
  final String? fontFamily;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData(fontFamily: fontFamily, brightness: brightness),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: padding,
          textScaler: textScaler,
          disableAnimations: reducedMotion,
        ),
        child: RepaintBoundary(
          key: const ValueKey('face-test-boundary'),
          child: RobotFaceScreen(
            initialState: state,
            stateStream: stateStream,
            onLongPress: withExit ? () {} : onLongPress,
          ),
        ),
      ),
    ),
  );
}
