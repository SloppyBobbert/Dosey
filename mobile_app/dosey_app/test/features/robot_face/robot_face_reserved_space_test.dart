import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'robot_face_test_font.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('scaled edge reservation contains all raster ink scale=$scale', (
      tester,
    ) async {
      await tester.runAsync(loadRobotFaceTestFont);
      const label = 'Normal glyphs: Agjpqy / 100 mg.';
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 616,
              child: RepaintBoundary(
                key: ValueKey('font-reference'),
                child: ColoredBox(
                  color: Colors.black,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      label,
                      textScaler: TextScaler.linear(scale),
                      style: const TextStyle(
                        fontFamily: robotFaceTestFont,
                        fontSize: 12,
                        height: 1.2,
                        letterSpacing: 0,
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
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('font-reference')),
      );
      final top = paragraph.localToGlobal(Offset.zero, ancestor: boundary).dy;
      final inkRows = await tester.runAsync(() async {
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
          return [first, last];
        } finally {
          image.dispose();
        }
      });
      final boxes = paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: label.length),
      );
      final edge = 2 * scale;
      debugPrint(
        'Font reference scale=$scale: selection=${boxes.first.toRect()} paragraphTop=$top height=${paragraph.size.height} inkRows=$inkRows reservedEdge=$edge',
      );
      expect(inkRows![1], greaterThanOrEqualTo(inkRows[0]));
      expect(inkRows[0], greaterThanOrEqualTo(top - edge));
      expect(inkRows[1], lessThan(top + paragraph.size.height + edge));
    });
  }

  testWidgets(
    'long mandatory content needs the measured side rail, not a smaller font',
    (tester) async {
      await tester.runAsync(loadRobotFaceTestFont);
      const text =
          'Now · Morning meds · Controller fault. Ask for help. · Shortage: '
          'Demo extended-release morning medication 100 mg / 25 mg combination tablet'
          ' · 8:00 AM · Slot 2. Local only; pinned until loading is handled. '
          'Check Carousel loading before dispense. · Internet offline. Local reminders still work.';
      const availableWidth = 800.0 - 83 - 97 - 16 - 72;
      const availableHeight = 400.0 - 31 - 149 - 16;
      final painter = TextPainter(
        text: const TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 12,
            height: 1.2,
            letterSpacing: 0,
            fontFamily: robotFaceTestFont,
          ),
        ),
        textScaler: TextScaler.linear(2),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: availableWidth);
      const edgePadding = 8.0; // Two 2dp edges at 200%.
      const reclaimableMargin = 8.0;
      final paddedHeight = painter.height + edgePadding;
      debugPrint(
        'Long required text: width=$availableWidth fullHeight=$availableHeight '
        'status=${painter.height} paddedStatus=$paddedHeight lines=${painter.computeLineMetrics().length} '
        'stackedMinimum=${paddedHeight + 48} railStatusMaximum=$availableHeight',
      );
      expect(
        paddedHeight + 48,
        greaterThan(availableHeight + reclaimableMargin),
      );
      expect(paddedHeight, lessThanOrEqualTo(availableHeight));
      painter.dispose();
    },
  );
}
