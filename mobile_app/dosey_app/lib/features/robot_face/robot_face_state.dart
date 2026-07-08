enum RobotFaceMode {
  idle,
  sleepy,
  doseApproaching,
  doseReady,
  dispensing,
  waitingForConfirmation,
  happyConfirmed,
  missed,
  error,
  offline,
}

class RobotFaceState {
  const RobotFaceState({
    required this.mode,
    required this.nextEventLabel,
    required this.isFlipped,
    required this.isLandscapeOnly,
    required this.rampProgress,
    required this.isInAwakeWindow,
    this.statusLabel,
  });

  final RobotFaceMode mode;
  final String nextEventLabel;
  final bool isFlipped;
  final bool isLandscapeOnly;
  final double rampProgress;
  final bool isInAwakeWindow;
  final String? statusLabel;

  RobotFaceState copyWith({
    RobotFaceMode? mode,
    String? nextEventLabel,
    bool? isFlipped,
    bool? isLandscapeOnly,
    double? rampProgress,
    bool? isInAwakeWindow,
    String? statusLabel,
  }) {
    return RobotFaceState(
      mode: mode ?? this.mode,
      nextEventLabel: nextEventLabel ?? this.nextEventLabel,
      isFlipped: isFlipped ?? this.isFlipped,
      isLandscapeOnly: isLandscapeOnly ?? this.isLandscapeOnly,
      rampProgress: rampProgress ?? this.rampProgress,
      isInAwakeWindow: isInAwakeWindow ?? this.isInAwakeWindow,
      statusLabel: statusLabel ?? this.statusLabel,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is RobotFaceState &&
        other.mode == mode &&
        other.nextEventLabel == nextEventLabel &&
        other.isFlipped == isFlipped &&
        other.isLandscapeOnly == isLandscapeOnly &&
        other.rampProgress == rampProgress &&
        other.isInAwakeWindow == isInAwakeWindow &&
        other.statusLabel == statusLabel;
  }

  @override
  int get hashCode => Object.hash(
    mode,
    nextEventLabel,
    isFlipped,
    isLandscapeOnly,
    rampProgress,
    isInAwakeWindow,
    statusLabel,
  );
}
