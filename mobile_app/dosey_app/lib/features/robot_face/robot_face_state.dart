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
    this.statusLabel,
  });

  final RobotFaceMode mode;
  final String nextEventLabel;
  final bool isFlipped;
  final bool isLandscapeOnly;
  final String? statusLabel;

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
        other.statusLabel == statusLabel;
  }

  @override
  int get hashCode => Object.hash(
    mode,
    nextEventLabel,
    isFlipped,
    isLandscapeOnly,
    statusLabel,
  );
}
