import 'dart:async';

import 'package:dosey_app/core/demo/demo_scenario.dart';
import 'package:dosey_app/features/guided_trial/guided_trial.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeScenarioRunner scenarios;
  late GuidedTrialController controller;
  late int completionCalls;

  setUp(() {
    scenarios = _FakeScenarioRunner();
    completionCalls = 0;
    controller = GuidedTrialController(
      scenarios: scenarios,
      completeTrial: () async => completionCalls += 1,
    );
  });

  test('starts with an introduction before scenario execution', () {
    expect(controller.state.step, GuidedTrialStep.introduction);
    expect(controller.state.completedSteps, 0);
    expect(controller.state.isComplete, isFalse);
  });

  test('sequences happy path, missed warning, and reconnect', () async {
    while (!controller.state.isComplete) {
      await controller.next();
    }

    expect(scenarios.selected, [
      DemoScenarioId.happyPath,
      DemoScenarioId.missedRecognized,
      DemoScenarioId.offlineReconnect,
    ]);
    expect(controller.state.step, GuidedTrialStep.complete);
    expect(completionCalls, 1);
  });

  test('failed step stays current and can be retried', () async {
    await controller.next();
    scenarios.failure = StateError('Expected reminder was not observed.');

    await controller.next();

    expect(controller.state.step, GuidedTrialStep.reminderPreview);
    expect(controller.state.failureReason, contains('Expected reminder'));
    scenarios.failure = null;
    await controller.retry();
    expect(controller.state.step, GuidedTrialStep.doseReady);
  });

  test(
    'restart returns to deterministic baseline without completing',
    () async {
      await controller.next();
      await controller.next();
      await controller.restart();

      expect(controller.state.step, GuidedTrialStep.introduction);
      expect(controller.state.completedSteps, 0);
      expect(scenarios.restartCalls, 1);
      expect(completionCalls, 0);
    },
  );

  test('pause blocks progression until resume', () async {
    controller.pause();
    await controller.next();
    expect(controller.state.step, GuidedTrialStep.introduction);

    controller.resume();
    await controller.next();
    expect(controller.state.step, GuidedTrialStep.reminderPreview);
  });

  test('restart does nothing while a step is running', () async {
    await controller.next();
    scenarios.blockNext();
    final pendingNext = controller.next();

    await controller.restart();

    expect(scenarios.restartCalls, 0);
    scenarios.releaseNext();
    await pendingNext;
    expect(controller.state.step, GuidedTrialStep.doseReady);
  });

  test('async completion does not update state after disposal', () async {
    await controller.next();
    scenarios.blockNext();
    final pendingNext = controller.next();

    controller.dispose();
    scenarios.releaseNext();

    await expectLater(pendingNext, completes);
  });
}

class _FakeScenarioRunner implements GuidedTrialScenarioRunner {
  final selected = <DemoScenarioId>[];
  Object? failure;
  int restartCalls = 0;
  Completer<void>? _nextCompleter;

  void blockNext() => _nextCompleter = Completer<void>();

  void releaseNext() => _nextCompleter?.complete();

  @override
  Future<void> next() async {
    await _nextCompleter?.future;
    _nextCompleter = null;
    final error = failure;
    if (error != null) throw error;
  }

  @override
  void pause() {}

  @override
  Future<void> restart() async => restartCalls += 1;

  @override
  Future<void> select(DemoScenarioId id) async {
    selected.add(id);
  }
}
