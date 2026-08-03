import 'dart:async';

import 'package:dosey_app/features/robot_face/robot_face_canvas.dart';
import 'package:dosey_app/features/robot_face/robot_face_screen.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  testWidgets('landscape canvas fills the viewport behind the status card', (
    tester,
  ) async {
    await _setViewport(tester, const Size(800, 400));
    await tester.pumpWidget(const _FaceTestApp());
    _expectViewportRect(
      _rect(tester, RobotFaceScreen.canvasKey),
      const Size(800, 400),
    );
    _expectViewportRect(
      _rect(tester, RobotFaceScreen.displayFrameKey),
      const Size(800, 400),
    );
    expect(
      _rect(
        tester,
        RobotFaceScreen.canvasKey,
      ).overlaps(_rect(tester, RobotFaceScreen.bottomCardKey)),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait keeps the clockwise viewport rotation at full size', (
    tester,
  ) async {
    await _setViewport(tester, const Size(400, 800));
    await tester.pumpWidget(const _FaceTestApp());
    _expectViewportRect(
      _rect(tester, RobotFaceScreen.canvasKey),
      const Size(400, 800),
    );
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

    _expectViewportRect(
      _rect(tester, RobotFaceScreen.canvasKey),
      const Size(400, 800),
    );
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

    _expectViewportRect(
      _rect(tester, RobotFaceScreen.canvasKey),
      const Size(800, 400),
    );
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

    _expectViewportRect(
      _rect(tester, RobotFaceScreen.canvasKey),
      const Size(400, 800),
    );
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

  testWidgets('safe insets and 200 percent text do not constrain the canvas', (
    tester,
  ) async {
    await _setViewport(tester, const Size(800, 400));
    await tester.pumpWidget(
      const _FaceTestApp(
        state: _ready,
        padding: EdgeInsets.fromLTRB(24, 18, 30, 20),
        textScaler: TextScaler.linear(2),
        withExit: true,
      ),
    );
    _expectViewportRect(
      _rect(tester, RobotFaceScreen.canvasKey),
      const Size(800, 400),
    );
    final card = _rect(tester, RobotFaceScreen.bottomCardKey);
    final exit = _rect(tester, RobotFaceScreen.exitButtonKey);
    expect(card.left, greaterThanOrEqualTo(24));
    expect(card.right, lessThanOrEqualTo(770));
    expect(card.bottom, lessThanOrEqualTo(380));
    expect(exit.left, greaterThanOrEqualTo(24));
    expect(exit.top, greaterThanOrEqualTo(18));
    expect(tester.takeException(), isNull);
  });

  testWidgets('canvas gestures stay separate from the status overlay', (
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
    expect(_canvas(tester).animationRevision, revisionAfterLongPress);
  });

  testWidgets(
    'status hit boundary is silent while child actions remain usable',
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
      expect(_canvas(tester).animationRevision, 0);
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
    'short safe overlay scrolls missed content without resizing canvas',
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
        _rect(tester, RobotFaceScreen.canvasKey),
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
    'action panel identity and flipped overlay transform are retained',
    (tester) async {
      await _setViewport(tester, const Size(800, 400));
      final states = StreamController<RobotFaceState>.broadcast();
      addTearDown(states.close);
      await tester.pumpWidget(_FaceTestApp(stateStream: states.stream));
      states.add(_ready);
      await tester.pump();
      final panel = tester.state(
        find.byKey(RobotFaceScreen.actionPanelKey, skipOffstage: false),
      );
      states.add(_ready.copyWith(mode: RobotFaceMode.missed));
      await tester.pump();
      states.add(_ready.copyWith(mode: RobotFaceMode.idle, actionDoseId: null));
      await tester.pump();
      states.add(_ready);
      await tester.pump();
      expect(
        tester.state(
          find.byKey(RobotFaceScreen.actionPanelKey, skipOffstage: false),
        ),
        same(panel),
      );
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

class _FaceTestApp extends StatelessWidget {
  const _FaceTestApp({
    super.key,
    this.state = _idle,
    this.stateStream,
    this.padding = EdgeInsets.zero,
    this.textScaler = TextScaler.noScaling,
    this.withExit = false,
    this.onLongPress,
  });
  final RobotFaceState state;
  final Stream<RobotFaceState>? stateStream;
  final EdgeInsets padding;
  final TextScaler textScaler;
  final bool withExit;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(padding: padding, textScaler: textScaler),
        child: RobotFaceScreen(
          initialState: state,
          stateStream: stateStream,
          onLongPress: withExit ? () {} : onLongPress,
        ),
      ),
    ),
  );
}
