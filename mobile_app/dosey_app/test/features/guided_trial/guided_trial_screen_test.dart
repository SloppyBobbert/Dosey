import 'package:dosey_app/core/demo/demo_scenario.dart';
import 'package:dosey_app/features/guided_trial/guided_trial.dart';
import 'package:dosey_app/features/guided_trial/guided_trial_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows product-facing trial progress and controls', (
    tester,
  ) async {
    final controller = GuidedTrialController(
      scenarios: _FakeRunner(),
      completeTrial: () async {},
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuidedTrialScreen(
            controller: controller,
            exitTrial: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Guided Trial Run'), findsOneWidget);
    expect(
      find.text('Fake medication and simulated controller'),
      findsOneWidget,
    );
    expect(find.text('Step 1 of 16'), findsOneWidget);
    expect(find.text('Next step'), findsOneWidget);
    expect(find.text('Auto-play'), findsNothing);
    expect(find.text('Start presentation'), findsNothing);
    expect(find.text('Demo scenario runner'), findsNothing);
    expect(find.text('Exit demo mode'), findsNothing);

    await tester.tap(find.text('Next step'));
    await tester.pump();
    expect(find.text('Step 2 of 16'), findsOneWidget);
  });

  testWidgets('confirms restart after progress', (tester) async {
    final controller = GuidedTrialController(
      scenarios: _FakeRunner(),
      completeTrial: () async {},
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuidedTrialScreen(
            controller: controller,
            exitTrial: () async {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Next step'));
    await tester.pump();
    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();

    expect(find.text('Restart guided trial?'), findsOneWidget);
  });

  testWidgets('shows failure and retries the current step', (tester) async {
    final runner = _FakeRunner()..failure = StateError('Expected ACK missing');
    final controller = GuidedTrialController(
      scenarios: runner,
      completeTrial: () async {},
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuidedTrialScreen(
            controller: controller,
            exitTrial: () async {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Next step'));
    await tester.pump();
    await tester.tap(find.text('Next step'));
    await tester.pump();
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.textContaining('Expected ACK missing'), findsOneWidget);
    expect(find.text('Retry step'), findsOneWidget);
  });

  testWidgets('completion keeps progress bounded and states simulator limits', (
    tester,
  ) async {
    final controller = GuidedTrialController(
      scenarios: _FakeRunner(),
      completeTrial: () async {},
    );
    addTearDown(controller.dispose);
    for (var index = 0; index < GuidedTrialStep.values.length - 1; index += 1) {
      await controller.next();
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuidedTrialScreen(
            controller: controller,
            exitTrial: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Step 16 of 16'), findsOneWidget);
    expect(find.text('Trial complete'), findsOneWidget);
    expect(
      find.textContaining('did not verify physical dispensing'),
      findsWidgets,
    );
    expect(find.text('Return to Dosey'), findsOneWidget);
  });

  testWidgets('history step requires an explicit reviewed-data continue', (
    tester,
  ) async {
    final controller = GuidedTrialController(
      scenarios: _FakeRunner(),
      completeTrial: () async {},
    );
    addTearDown(controller.dispose);
    for (var index = 0; index < 10; index += 1) {
      await controller.next();
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuidedTrialScreen(
            controller: controller,
            exitTrial: () async {},
          ),
        ),
      ),
    );

    expect(find.text('History and inventory'), findsOneWidget);
    expect(find.text('Continue after review'), findsOneWidget);
  });
}

class _FakeRunner implements GuidedTrialScenarioRunner {
  Object? failure;

  @override
  Future<void> next() async {
    final currentFailure = failure;
    failure = null;
    if (currentFailure != null) throw currentFailure;
  }

  @override
  void pause() {}

  @override
  Future<void> restart() async {}

  @override
  Future<void> select(DemoScenarioId id) async {}
}
