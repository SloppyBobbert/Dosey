import 'package:dosey_app/core/demo/demo_scenario.dart';
import 'package:dosey_app/core/demo/demo_scenario_service.dart';
import 'package:flutter/foundation.dart';

enum GuidedTrialStep {
  introduction,
  reminderPreview,
  doseReady,
  commandSent,
  commandAccepted,
  movementStarted,
  servoDone,
  movementExplanation,
  doseVisible,
  doseTaken,
  historyAndInventory,
  doseMissed,
  warningRecognized,
  controllerOffline,
  reconnectFailed,
  controllerReconnected,
  complete,
}

abstract interface class GuidedTrialScenarioRunner {
  Future<void> select(DemoScenarioId id);
  Future<void> next();
  Future<void> restart();
  void pause();
}

class DemoGuidedTrialScenarioRunner implements GuidedTrialScenarioRunner {
  DemoGuidedTrialScenarioRunner(this._scenarios);

  final DemoScenarioService _scenarios;

  @override
  Future<void> next() => _scenarios.next();

  @override
  void pause() => _scenarios.pause();

  @override
  Future<void> restart() => _scenarios.restart();

  @override
  Future<void> select(DemoScenarioId id) => _scenarios.select(id);
}

@immutable
class GuidedTrialState {
  const GuidedTrialState({
    required this.step,
    this.isRunning = false,
    this.isPaused = false,
    this.failureReason,
  });

  final GuidedTrialStep step;
  final bool isRunning;
  final bool isPaused;
  final String? failureReason;

  int get completedSteps => step.index;
  int get totalSteps => GuidedTrialStep.values.length - 1;
  bool get isComplete => step == GuidedTrialStep.complete;

  GuidedTrialState copyWith({
    GuidedTrialStep? step,
    bool? isRunning,
    bool? isPaused,
    String? failureReason,
    bool clearFailure = false,
  }) {
    return GuidedTrialState(
      step: step ?? this.step,
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      failureReason: clearFailure ? null : failureReason ?? this.failureReason,
    );
  }
}

class GuidedTrialController extends ChangeNotifier {
  GuidedTrialController({
    required GuidedTrialScenarioRunner scenarios,
    required Future<void> Function() completeTrial,
  }) : this._(scenarios, completeTrial);

  GuidedTrialController._(this._scenarios, this._completeTrial);

  final GuidedTrialScenarioRunner _scenarios;
  final Future<void> Function() _completeTrial;
  GuidedTrialState _state = const GuidedTrialState(
    step: GuidedTrialStep.introduction,
  );

  GuidedTrialState get state => _state;

  Future<void> next() async {
    if (_state.isRunning || _state.isPaused || _state.isComplete) return;
    _setState(_state.copyWith(isRunning: true, clearFailure: true));
    try {
      await _runCurrentStep();
      final nextStep = GuidedTrialStep.values[_state.step.index + 1];
      if (nextStep == GuidedTrialStep.complete) await _completeTrial();
      _setState(GuidedTrialState(step: nextStep, isPaused: _state.isPaused));
    } on Object catch (error) {
      _setState(
        _state.copyWith(isRunning: false, failureReason: error.toString()),
      );
    }
  }

  Future<void> retry() => next();

  void pause() {
    if (_state.isRunning || _state.isComplete) return;
    _scenarios.pause();
    _setState(_state.copyWith(isPaused: true));
  }

  void resume() {
    if (!_state.isPaused) return;
    _setState(_state.copyWith(isPaused: false));
  }

  Future<void> restart() async {
    _scenarios.pause();
    await _scenarios.restart();
    _setState(const GuidedTrialState(step: GuidedTrialStep.introduction));
  }

  Future<void> _runCurrentStep() async {
    switch (_state.step) {
      case GuidedTrialStep.introduction:
      case GuidedTrialStep.movementExplanation:
      case GuidedTrialStep.historyAndInventory:
        return;
      case GuidedTrialStep.reminderPreview:
        await _scenarios.select(DemoScenarioId.happyPath);
        await _scenarios.next();
      case GuidedTrialStep.doseReady:
      case GuidedTrialStep.commandSent:
      case GuidedTrialStep.commandAccepted:
      case GuidedTrialStep.movementStarted:
      case GuidedTrialStep.servoDone:
      case GuidedTrialStep.doseVisible:
      case GuidedTrialStep.doseTaken:
        await _scenarios.next();
      case GuidedTrialStep.doseMissed:
        await _scenarios.select(DemoScenarioId.missedRecognized);
        await _scenarios.next();
      case GuidedTrialStep.warningRecognized:
        await _scenarios.next();
      case GuidedTrialStep.controllerOffline:
        await _scenarios.select(DemoScenarioId.offlineReconnect);
        await _scenarios.next();
      case GuidedTrialStep.reconnectFailed:
      case GuidedTrialStep.controllerReconnected:
        await _scenarios.next();
      case GuidedTrialStep.complete:
        return;
    }
  }

  void _setState(GuidedTrialState state) {
    _state = state;
    notifyListeners();
  }
}

extension GuidedTrialStepCopy on GuidedTrialStep {
  String get title => switch (this) {
    GuidedTrialStep.introduction => 'Fake medication and simulated controller',
    GuidedTrialStep.reminderPreview => 'Upcoming reminder',
    GuidedTrialStep.doseReady => 'Dose ready',
    GuidedTrialStep.commandSent => 'Command sent',
    GuidedTrialStep.commandAccepted => 'Command accepted',
    GuidedTrialStep.movementStarted => 'Movement started',
    GuidedTrialStep.servoDone => 'Servo done',
    GuidedTrialStep.movementExplanation => 'Movement is not confirmation',
    GuidedTrialStep.doseVisible => 'Dose visible',
    GuidedTrialStep.doseTaken => 'Dose taken',
    GuidedTrialStep.historyAndInventory => 'History and inventory',
    GuidedTrialStep.doseMissed => 'Missed-dose warning',
    GuidedTrialStep.warningRecognized => 'Warning recognized',
    GuidedTrialStep.controllerOffline => 'Controller offline',
    GuidedTrialStep.reconnectFailed => 'Reconnect attempt',
    GuidedTrialStep.controllerReconnected => 'Controller reconnected',
    GuidedTrialStep.complete => 'Trial complete',
  };

  String get body => switch (this) {
    GuidedTrialStep.introduction =>
      'This trial uses fake medication, a fake schedule, and a simulated controller. Your real data will not change.',
    GuidedTrialStep.reminderPreview =>
      'Preview the reminder before the scheduled dose becomes ready.',
    GuidedTrialStep.doseReady =>
      'Advance the trial clock to make the dose ready.',
    GuidedTrialStep.commandSent => 'Send the simulated dispense request.',
    GuidedTrialStep.commandAccepted =>
      'The simulated controller accepts the command separately.',
    GuidedTrialStep.movementStarted =>
      'The simulator reports that movement has started.',
    GuidedTrialStep.servoDone =>
      'The simulator reports that servo movement has finished.',
    GuidedTrialStep.movementExplanation =>
      'Completed movement does not mean the dose is visible or taken.',
    GuidedTrialStep.doseVisible => 'Confirm that the fake dose is visible.',
    GuidedTrialStep.doseTaken => 'Confirm that the fake dose was taken.',
    GuidedTrialStep.historyAndInventory =>
      'Review the fake history and inventory change inside this trial only.',
    GuidedTrialStep.doseMissed =>
      'This dose was missed. Follow your prescription instructions or ask your caregiver, pharmacist, or doctor.',
    GuidedTrialStep.warningRecognized =>
      'Recognizing the warning does not mark the dose taken or skipped and does not change inventory.',
    GuidedTrialStep.controllerOffline =>
      'Simulate a missed heartbeat and an offline controller.',
    GuidedTrialStep.reconnectFailed =>
      'Practice a reconnect attempt that does not succeed yet.',
    GuidedTrialStep.controllerReconnected =>
      'Reconnect the simulated controller and verify a healthy heartbeat.',
    GuidedTrialStep.complete =>
      'The software trial passed using a simulator. It did not verify physical dispensing.',
  };
}
