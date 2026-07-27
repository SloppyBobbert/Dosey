import 'package:flutter/widgets.dart';

class ExternalActionResumeGuard<T> {
  int _generation = 0;
  _ExternalActionState<T>? _state;

  ExternalActionResumeLease begin(T resumeTarget) {
    final generation = ++_generation;
    _state = _ExternalActionState(
      generation: generation,
      resumeTarget: resumeTarget,
    );
    return ExternalActionResumeLease._(() => _complete(generation));
  }

  void didChangeLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    _state?.armed = true;
  }

  T? consumeResumeTarget() {
    final state = _state;
    if (state == null || !state.armed) return null;
    _state = null;
    return state.resumeTarget;
  }

  void _complete(int generation) {
    final state = _state;
    if (state == null || state.generation != generation || state.armed) return;
    _state = null;
  }
}

class ExternalActionResumeLease {
  ExternalActionResumeLease._(this._onComplete);

  final void Function() _onComplete;
  bool _completed = false;

  void complete() {
    if (_completed) return;
    _completed = true;
    _onComplete();
  }
}

class _ExternalActionState<T> {
  _ExternalActionState({required this.generation, required this.resumeTarget});

  final int generation;
  final T resumeTarget;
  bool armed = false;
}
