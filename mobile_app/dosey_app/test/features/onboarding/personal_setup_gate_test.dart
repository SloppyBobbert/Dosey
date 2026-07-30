import 'dart:async';

import 'package:dosey_app/core/settings/personal_setup_step.dart';
import 'package:dosey_app/features/onboarding/personal_setup_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'persists choice, resumes orientation, and waits for medication success',
    (tester) async {
      final steps = StreamController<PersonalSetupStep>.broadcast();
      addTearDown(steps.close);
      final saved = <PersonalSetupStep>[];

      Widget app() => MaterialApp(
        home: PersonalSetupGate(
          steps: steps.stream,
          saveStep: (step) async {
            saved.add(step);
            steps.add(step);
          },
          today: const Text('existing Today'),
          medications: (completeSetup) => TextButton(
            onPressed: completeSetup,
            child: const Text('existing Medications'),
          ),
          pairing: (completeSetup) => TextButton(
            onPressed: completeSetup,
            child: const Text('existing Pairing'),
          ),
        ),
      );

      await tester.pumpWidget(app());
      steps.add(PersonalSetupStep.chooseNextAction);
      await tester.pump();
      await tester.tap(find.text('Add medication'));
      await tester.pump();

      expect(saved, [PersonalSetupStep.orientThenAddMedication]);
      expect(find.textContaining('Today'), findsWidgets);
      expect(find.textContaining('Schedules'), findsOne);
      expect(find.textContaining('History'), findsOne);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      steps.add(PersonalSetupStep.orientThenAddMedication);
      await tester.pump();
      expect(find.text('Continue to medications'), findsOne);

      await tester.tap(find.text('Continue to medications'));
      await tester.pump();

      expect(saved.last, PersonalSetupStep.orientThenAddMedication);
      expect(find.text('existing Medications'), findsOne);

      await tester.tap(find.text('existing Medications'));
      await tester.pump();

      expect(saved.last, PersonalSetupStep.complete);
      expect(find.text('existing Today'), findsOne);
    },
  );

  testWidgets('pair choice waits for pairing success after orientation', (
    tester,
  ) async {
    final steps = StreamController<PersonalSetupStep>.broadcast();
    addTearDown(steps.close);
    final saved = <PersonalSetupStep>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PersonalSetupGate(
          steps: steps.stream,
          saveStep: (step) async {
            saved.add(step);
            steps.add(step);
          },
          today: const Text('existing Today'),
          medications: (_) => const Text('existing Medications'),
          pairing: (completeSetup) => TextButton(
            onPressed: completeSetup,
            child: const Text('existing Pairing'),
          ),
        ),
      ),
    );
    steps.add(PersonalSetupStep.chooseNextAction);
    await tester.pump();
    await tester.tap(find.text('Pair Robot'));
    await tester.pump();
    await tester.tap(find.text('Continue to pairing'));
    await tester.pump();

    expect(saved, [PersonalSetupStep.orientThenPairRobot]);
    expect(find.text('existing Pairing'), findsOne);

    await tester.tap(find.text('existing Pairing'));
    await tester.pump();

    expect(saved.last, PersonalSetupStep.complete);
    expect(find.text('existing Today'), findsOne);
  });

  testWidgets('choice remains scrollable with large text on a narrow phone', (
    tester,
  ) async {
    final steps = StreamController<PersonalSetupStep>.broadcast();
    addTearDown(steps.close);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: PersonalSetupGate(
          steps: steps.stream,
          saveStep: (_) async {},
          today: const Text('existing Today'),
          medications: (_) => const Text('existing Medications'),
          pairing: (_) => const Text('existing Pairing'),
        ),
      ),
    );
    steps.add(PersonalSetupStep.chooseNextAction);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.text('Add medication')).height, greaterThan(0));
    expect(
      tester
          .getSize(find.widgetWithText(FilledButton, 'Add medication'))
          .height,
      greaterThanOrEqualTo(48),
    );
  });
}
