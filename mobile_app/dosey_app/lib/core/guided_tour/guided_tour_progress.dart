const int guidedTourVersion = 1;

enum GuidedTourState {
  unseen('unseen'),
  inProgress('in_progress'),
  skipped('skipped'),
  completed('completed');

  const GuidedTourState(this.storageValue);

  final String storageValue;

  static GuidedTourState? fromStorageValue(String value) {
    for (final state in GuidedTourState.values) {
      if (state.storageValue == value) return state;
    }
    return null;
  }
}

final class GuidedTourProgress {
  const GuidedTourProgress.unseen()
    : version = 0,
      state = GuidedTourState.unseen,
      step = 0;

  GuidedTourProgress.inProgress({required int step})
    : this._current(state: GuidedTourState.inProgress, step: step);

  GuidedTourProgress.skipped({required int step})
    : this._current(state: GuidedTourState.skipped, step: step);

  GuidedTourProgress.completed({required int step})
    : this._current(state: GuidedTourState.completed, step: step);

  GuidedTourProgress._current({required this.state, required this.step})
    : version = guidedTourVersion {
    if (step < 0) {
      throw ArgumentError.value(step, 'step', 'must not be negative');
    }
  }

  final int version;
  final GuidedTourState state;
  final int step;

  static GuidedTourProgress fromStorageValues({
    required String? version,
    required String? state,
    required String? step,
  }) {
    final parsedVersion = int.tryParse(version ?? '');
    final parsedState = state == null
        ? null
        : GuidedTourState.fromStorageValue(state);
    final parsedStep = int.tryParse(step ?? '');
    if (parsedVersion != guidedTourVersion ||
        parsedState == null ||
        parsedState == GuidedTourState.unseen ||
        parsedStep == null ||
        parsedStep < 0) {
      return const GuidedTourProgress.unseen();
    }

    return switch (parsedState) {
      GuidedTourState.inProgress => GuidedTourProgress.inProgress(
        step: parsedStep,
      ),
      GuidedTourState.skipped => GuidedTourProgress.skipped(step: parsedStep),
      GuidedTourState.completed => GuidedTourProgress.completed(
        step: parsedStep,
      ),
      GuidedTourState.unseen => const GuidedTourProgress.unseen(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is GuidedTourProgress &&
      other.version == version &&
      other.state == state &&
      other.step == step;

  @override
  int get hashCode => Object.hash(version, state, step);
}
