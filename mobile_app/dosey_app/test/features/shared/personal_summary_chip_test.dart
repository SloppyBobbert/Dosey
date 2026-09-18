import 'package:dosey_app/features/shared/personal_summary_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [240.0, 720.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('summary labels fit ${width}px at ${scale}x text', (
        tester,
      ) async {
        const labels = [
          '12 entered',
          '24 scheduled',
          'Feeds schedule builder',
          'Local label reference',
          'Active routine',
          '12 enabled / 24 scheduled',
          'Feeds Today timeline',
        ];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: width,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final label in labels)
                            PersonalSummaryChip(
                              icon: Icons.medication_outlined,
                              label: label,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        for (final label in labels) {
          final text = find.text(label);
          expect(text, findsOneWidget);
          final rect = tester.getRect(text);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
          expect(tester.widget<Text>(text).maxLines, isNull);
        }
      });
    }
  }
}
