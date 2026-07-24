import 'dart:async';
import 'dart:collection';

import 'package:dosey_app/core/controller/controller_bench_service.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/controller/controller_lifecycle_service.dart';
import 'package:dosey_app/core/controller/local_controller_command_repository.dart';
import 'package:dosey_app/core/controller/simulated_controller_gateway.dart';
import 'package:dosey_app/core/demo/demo_data_repository.dart';
import 'package:dosey_app/core/demo/demo_scenario.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/reminders/missed_dose_reconciliation_service.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/time/app_clock.dart';
import 'package:dosey_app/features/doses/dose_action_service.dart';

typedef DemoPlaybackDelay = Future<void> Function(Duration duration);

class DemoCommandSessionIdGenerator {
  int _next = 1;

  String call(ControllerCommandType commandType, DateTime _) {
    final sequence = _next.toString().padLeft(3, '0');
    _next += 1;
    return 'demo:command:$sequence:${commandType.name}';
  }

  void reset() => _next = 1;
}

class DemoStageGate {
  final Queue<Completer<void>> _pending = Queue<Completer<void>>();
  Completer<void>? _nextBlocked;
  bool enabled = true;

  Future<void> wait(Duration _) {
    if (!enabled) return Future<void>.value();
    final completer = Completer<void>();
    _pending.add(completer);
    _nextBlocked?.complete();
    _nextBlocked = null;
    return completer.future;
  }

  Future<void> waitUntilBlocked() {
    if (_pending.isNotEmpty) return Future<void>.value();
    return (_nextBlocked ??= Completer<void>()).future;
  }

  void releaseNext() {
    if (_pending.isEmpty) {
      throw StateError('No simulator stage is waiting.');
    }
    _pending.removeFirst().complete();
  }

  void reset() {
    while (_pending.isNotEmpty) {
      _pending.removeFirst().complete();
    }
    _nextBlocked?.complete();
    _nextBlocked = null;
    enabled = true;
  }
}

class DemoScenarioService {
  DemoScenarioService({
    required this.data,
    required this.database,
    required this.clock,
    required this.controller,
    required this.stageGate,
    required this.idGenerator,
    required this.lifecycle,
    required this.bench,
    required this.commandRepository,
    required this.doseActions,
    required this.reconciliation,
    DemoPlaybackDelay? playbackDelay,
  }) : _playbackDelay = playbackDelay ?? Future<void>.delayed,
       _state = DemoScenarioState(
         scenario: demoScenarioCatalog.first,
         completedSteps: 0,
         isPlaying: false,
       );

  final DemoDataRepository data;
  final DoseyDatabase database;
  final ControllableAppClock clock;
  final SimulatedControllerGateway controller;
  final DemoStageGate stageGate;
  final DemoCommandSessionIdGenerator idGenerator;
  final ControllerLifecycleService lifecycle;
  final ControllerBenchService bench;
  final ControllerCommandRepository commandRepository;
  final DoseActionService doseActions;
  final MissedDoseReconciliationService reconciliation;
  final DemoPlaybackDelay _playbackDelay;
  final StreamController<DemoScenarioState> _states =
      StreamController<DemoScenarioState>.broadcast();

  DemoScenarioState _state;
  Future<void>? _pendingCommand;
  Object? _pendingCommandError;
  bool _commandCompleted = true;
  bool _runningStep = false;
  int _stepGeneration = 0;
  Future<void> _resetBarrier = Future<void>.value();
  Object? _resetFailure;

  DemoScenarioState get state => _state;
  Stream<DemoScenarioState> get states => _states.stream;

  Future<void> select(DemoScenarioId id) async {
    pause();
    final scenario = demoScenarioCatalog.singleWhere((item) => item.id == id);
    await _enqueueReset(
      () => DemoScenarioState(
        scenario: scenario,
        completedSteps: 0,
        isPlaying: false,
      ),
    );
  }

  Future<void> restart() async {
    pause();
    await _enqueueReset(
      () => DemoScenarioState(
        scenario: _state.scenario,
        completedSteps: 0,
        isPlaying: false,
        isPresenting: _state.isPresenting,
      ),
    );
  }

  Future<void> startPresentation() async {
    pause();
    await _enqueueReset(
      () => DemoScenarioState(
        scenario: demoScenarioCatalog.first,
        completedSteps: 0,
        isPlaying: false,
        isPresenting: true,
      ),
    );
  }

  void stopPresentation() {
    pause();
    if (_state.isPresenting) {
      _emit(_state.copyWith(isPresenting: false));
    }
  }

  Future<void> next() async {
    final requestedGeneration = _stepGeneration;
    await _resetBarrier;
    if (requestedGeneration != _stepGeneration) return;
    _throwIfResetFailed();
    if (_runningStep || _state.isComplete) return;
    final generation = requestedGeneration;
    final scenario = _state.scenario.id;
    final step = _state.completedSteps;
    _runningStep = true;
    try {
      await _execute(scenario, step);
      if (generation == _stepGeneration) {
        _emit(_state.copyWith(completedSteps: step + 1));
      }
    } finally {
      _runningStep = false;
    }
  }

  Future<void> play() async {
    await _resetBarrier;
    _throwIfResetFailed();
    if (_state.isPlaying || _state.isComplete) return;
    _emit(_state.copyWith(isPlaying: true));
    while (_state.isPlaying && !_state.isComplete) {
      await next();
      if (_state.isPlaying && !_state.isComplete) {
        await _playbackDelay(
          _state.isPresenting
              ? const Duration(seconds: 2)
              : const Duration(milliseconds: 700),
        );
      }
    }
    if (_state.isPlaying) {
      _emit(_state.copyWith(isPlaying: false));
    }
  }

  void pause() {
    if (_state.isPlaying) {
      _emit(_state.copyWith(isPlaying: false));
    }
  }

  Future<void> close() async {
    pause();
    await _resetBarrier;
    await _settlePendingCommand();
    await _states.close();
  }

  Future<void> _enqueueReset(DemoScenarioState Function() nextState) {
    _stepGeneration += 1;
    final reset = _resetBarrier.then((_) async {
      try {
        await _resetBaseline();
        _resetFailure = null;
        _emit(nextState());
      } on Object catch (error) {
        _resetFailure = error;
        rethrow;
      }
    });
    _resetBarrier = reset.then<void>((_) {}, onError: (_, _) {});
    return reset;
  }

  void _throwIfResetFailed() {
    if (_resetFailure != null) {
      throw StateError(
        'Demo scenario reset failed. Restart the scenario before continuing.',
      );
    }
  }

  Future<void> _execute(DemoScenarioId scenario, int step) async {
    switch (scenario) {
      case DemoScenarioId.happyPath:
        await _happyPathStep(step);
      case DemoScenarioId.missedRecognized:
        await _missedStep(step);
      case DemoScenarioId.offlineReconnect:
        await _offlineStep(step);
      case DemoScenarioId.nack:
        await _runFailure(SimulatedDispenseOutcome.rejected);
      case DemoScenarioId.preAcceptanceTimeout:
        await _runFailure(SimulatedDispenseOutcome.timeoutBeforeAcceptance);
      case DemoScenarioId.jam:
        await _runFailure(SimulatedDispenseOutcome.jamAfterAcceptance);
      case DemoScenarioId.disconnectAfterAcceptance:
        await _runFailure(SimulatedDispenseOutcome.disconnectAfterAcceptance);
      case DemoScenarioId.globalSerialization:
        await _serializationStep(step);
    }
  }

  Future<void> _happyPathStep(int step) async {
    switch (step) {
      case 0:
        clock.set(_at(8, 25));
      case 1:
        clock.set(_at(8, 30));
      case 2:
        _startDoseCommand();
        await stageGate.waitUntilBlocked();
      case 3:
        await _releaseAndWaitFor(ControllerCommandEventType.ack);
      case 4:
        await _releaseAndWaitFor(ControllerCommandEventType.moveStarted);
      case 5:
        stageGate.releaseNext();
        await _awaitPendingCommand();
      case 6:
        await doseActions.record(
          DoseLogEvent.doseVisibleConfirmed(
            doseId: _doseId,
            occurredAt: clock.now(),
          ),
        );
      case 7:
        await doseActions.record(
          DoseLogEvent.doseTakenConfirmed(
            doseId: _doseId,
            occurredAt: clock.now(),
          ),
        );
      default:
        throw RangeError.index(step, _state.scenario.steps);
    }
  }

  Future<void> _missedStep(int step) async {
    switch (step) {
      case 0:
        clock.set(_at(10, 31));
        await reconciliation.reconcile();
      case 1:
        await doseActions.record(
          DoseLogEvent.doseMissedRecognized(
            doseId: _doseId,
            occurredAt: clock.now(),
          ),
        );
      default:
        throw RangeError.index(step, _state.scenario.steps);
    }
  }

  Future<void> _offlineStep(int step) async {
    stageGate.enabled = false;
    switch (step) {
      case 0:
        try {
          await controller.disconnect();
          try {
            await bench.run(ControllerBenchCommand.heartbeat);
          } on ControllerTransportOfflineException {
            _emit(_state.copyWith(lastMessage: 'Controller offline'));
          }
        } finally {
          stageGate.enabled = true;
        }
      case 1:
        try {
          await controller.connect();
          await bench.run(ControllerBenchCommand.heartbeat);
          _emit(_state.copyWith(lastMessage: 'Controller reconnected'));
        } finally {
          stageGate.enabled = true;
        }
      default:
        stageGate.enabled = true;
        throw RangeError.index(step, _state.scenario.steps);
    }
  }

  Future<void> _serializationStep(int step) async {
    switch (step) {
      case 0:
        _startDoseCommand();
        await stageGate.waitUntilBlocked();
        try {
          await lifecycle.requestManualServoTest();
        } on DuplicateDispenseRequestException catch (error) {
          _emit(_state.copyWith(lastMessage: error.message));
        }
      case 1:
        await _settlePendingCommand();
      default:
        throw RangeError.index(step, _state.scenario.steps);
    }
  }

  Future<void> _runFailure(SimulatedDispenseOutcome outcome) async {
    controller.queueNextDispenseOutcome(outcome);
    stageGate.enabled = false;
    try {
      await lifecycle.requestDoseDispense(
        doseId: _doseId,
        scheduleId: DemoDataRepository.scheduleId,
      );
    } on Object catch (error) {
      _emit(_state.copyWith(lastMessage: error.toString()));
    } finally {
      stageGate.enabled = true;
    }
  }

  void _startDoseCommand() {
    _pendingCommandError = null;
    _commandCompleted = false;
    _pendingCommand = lifecycle
        .requestDoseDispense(
          doseId: _doseId,
          scheduleId: DemoDataRepository.scheduleId,
        )
        .then<void>(
          (_) {},
          onError: (Object error, StackTrace _) {
            _pendingCommandError = error;
          },
        )
        .whenComplete(() => _commandCompleted = true);
  }

  Future<void> _releaseAndWaitFor(ControllerCommandEventType eventType) async {
    stageGate.releaseNext();
    await commandRepository.watchRecentHistory().firstWhere(
      (history) =>
          history.isNotEmpty &&
          history.first.events.any((event) => event.eventType == eventType),
    );
    await stageGate.waitUntilBlocked();
  }

  Future<void> _awaitPendingCommand() async {
    final command = _pendingCommand;
    if (command == null) return;
    await command;
    _pendingCommand = null;
    final error = _pendingCommandError;
    _pendingCommandError = null;
    if (error != null) throw error;
  }

  Future<void> _settlePendingCommand() async {
    var releases = 0;
    while (!_commandCompleted && releases < 4) {
      await stageGate.waitUntilBlocked();
      stageGate.releaseNext();
      releases += 1;
      await Future<void>.delayed(Duration.zero);
    }
    await _awaitPendingCommand();
  }

  Future<void> _resetBaseline() async {
    await _settlePendingCommand();
    stageGate.reset();
    idGenerator.reset();
    clock.set(data.seedTime);
    controller.queueNextDispenseOutcome(SimulatedDispenseOutcome.success);
    await data.resetAndSeed();
    await controller.connect();
  }

  DateTime _at(int hour, int minute) => DateTime.utc(
    data.seedTime.year,
    data.seedTime.month,
    data.seedTime.day,
    hour,
    minute,
  );

  String get _doseId {
    final date = data.seedTime;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${DemoDataRepository.scheduleId}:${date.year}-$month-$day';
  }

  void _emit(DemoScenarioState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }
}
