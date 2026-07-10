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

enum RobotFaceTone { calm, ready, attention, warning, offline }

enum RobotFaceActionKind { confirmTaken, skipDose, askForHelp }

const Object _unset = Object();

extension RobotFaceModePresentation on RobotFaceMode {
  RobotFaceTone get tone {
    return switch (this) {
      RobotFaceMode.idle ||
      RobotFaceMode.sleepy ||
      RobotFaceMode.happyConfirmed => RobotFaceTone.calm,
      RobotFaceMode.doseReady ||
      RobotFaceMode.waitingForConfirmation => RobotFaceTone.ready,
      RobotFaceMode.doseApproaching ||
      RobotFaceMode.dispensing => RobotFaceTone.attention,
      RobotFaceMode.missed || RobotFaceMode.error => RobotFaceTone.warning,
      RobotFaceMode.offline => RobotFaceTone.offline,
    };
  }

  bool get needsContextualAction {
    return switch (this) {
      RobotFaceMode.doseReady || RobotFaceMode.waitingForConfirmation => true,
      RobotFaceMode.idle ||
      RobotFaceMode.sleepy ||
      RobotFaceMode.doseApproaching ||
      RobotFaceMode.dispensing ||
      RobotFaceMode.happyConfirmed ||
      RobotFaceMode.missed ||
      RobotFaceMode.error ||
      RobotFaceMode.offline => false,
    };
  }
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
    this.actionDoseId,
    this.availableActions = const <RobotFaceActionKind>{},
  });

  final RobotFaceMode mode;
  final String nextEventLabel;
  final bool isFlipped;
  final bool isLandscapeOnly;
  final double rampProgress;
  final bool isInAwakeWindow;
  final String? statusLabel;
  final String? actionDoseId;
  final Set<RobotFaceActionKind> availableActions;

  RobotFaceState copyWith({
    RobotFaceMode? mode,
    String? nextEventLabel,
    bool? isFlipped,
    bool? isLandscapeOnly,
    double? rampProgress,
    bool? isInAwakeWindow,
    String? statusLabel,
    Object? actionDoseId = _unset,
    Set<RobotFaceActionKind>? availableActions,
  }) {
    return RobotFaceState(
      mode: mode ?? this.mode,
      nextEventLabel: nextEventLabel ?? this.nextEventLabel,
      isFlipped: isFlipped ?? this.isFlipped,
      isLandscapeOnly: isLandscapeOnly ?? this.isLandscapeOnly,
      rampProgress: rampProgress ?? this.rampProgress,
      isInAwakeWindow: isInAwakeWindow ?? this.isInAwakeWindow,
      statusLabel: statusLabel ?? this.statusLabel,
      actionDoseId: identical(actionDoseId, _unset)
          ? this.actionDoseId
          : actionDoseId as String?,
      availableActions: availableActions ?? this.availableActions,
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
        other.statusLabel == statusLabel &&
        other.actionDoseId == actionDoseId &&
        _setEquals(other.availableActions, availableActions);
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
    actionDoseId,
    _unorderedSetHash(availableActions),
  );

  static bool _setEquals<T>(Set<T> a, Set<T> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (final value in a) {
      if (!b.contains(value)) {
        return false;
      }
    }
    return true;
  }

  static int _unorderedSetHash<T>(Set<T> values) {
    var hash = 0;
    for (final value in values) {
      hash ^= value.hashCode;
    }
    return hash;
  }
}
