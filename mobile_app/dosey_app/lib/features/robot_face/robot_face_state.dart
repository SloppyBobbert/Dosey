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

enum RobotFaceNetworkAdvisory { internetOffline }

enum RobotFaceActionKind {
  confirmTaken,
  skipDose,
  askForHelp,
  recognizeMissedDose,
}

// Allows copyWith(actionDoseId: null) to clear the dose id instead of keeping
// the previous value.
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
    this.networkAdvisory,
    this.actionDoseId,
    this.voiceOccurrenceKey,
    this.isAwaitingControllerConfirmation = false,
    this.availableActions = const <RobotFaceActionKind>{},
    this.hasPinnedShortageAlert = false,
    this.activeShortageLabel,
    this.activeShortageMedicationLabel,
    this.activeShortageScheduledLabel,
    this.activeShortageSlotNumber,
  });

  final RobotFaceMode mode;
  final String nextEventLabel;
  final bool isFlipped;
  final bool isLandscapeOnly;
  final double rampProgress;
  final bool isInAwakeWindow;
  final String? statusLabel;
  final RobotFaceNetworkAdvisory? networkAdvisory;
  final String? actionDoseId;
  final String? voiceOccurrenceKey;
  final bool isAwaitingControllerConfirmation;
  // Non-empty only when the current dose should expose explicit human actions.
  final Set<RobotFaceActionKind> availableActions;
  final bool hasPinnedShortageAlert;
  final String? activeShortageLabel;
  final String? activeShortageMedicationLabel;
  final String? activeShortageScheduledLabel;
  final int? activeShortageSlotNumber;

  RobotFaceState copyWith({
    RobotFaceMode? mode,
    String? nextEventLabel,
    bool? isFlipped,
    bool? isLandscapeOnly,
    double? rampProgress,
    bool? isInAwakeWindow,
    String? statusLabel,
    RobotFaceNetworkAdvisory? networkAdvisory,
    Object? actionDoseId = _unset,
    Object? voiceOccurrenceKey = _unset,
    bool? isAwaitingControllerConfirmation,
    Set<RobotFaceActionKind>? availableActions,
    bool? hasPinnedShortageAlert,
    Object? activeShortageLabel = _unset,
    Object? activeShortageMedicationLabel = _unset,
    Object? activeShortageScheduledLabel = _unset,
    Object? activeShortageSlotNumber = _unset,
  }) {
    return RobotFaceState(
      mode: mode ?? this.mode,
      nextEventLabel: nextEventLabel ?? this.nextEventLabel,
      isFlipped: isFlipped ?? this.isFlipped,
      isLandscapeOnly: isLandscapeOnly ?? this.isLandscapeOnly,
      rampProgress: rampProgress ?? this.rampProgress,
      isInAwakeWindow: isInAwakeWindow ?? this.isInAwakeWindow,
      statusLabel: statusLabel ?? this.statusLabel,
      networkAdvisory: networkAdvisory ?? this.networkAdvisory,
      actionDoseId: identical(actionDoseId, _unset)
          ? this.actionDoseId
          : actionDoseId as String?,
      voiceOccurrenceKey: identical(voiceOccurrenceKey, _unset)
          ? this.voiceOccurrenceKey
          : voiceOccurrenceKey as String?,
      isAwaitingControllerConfirmation:
          isAwaitingControllerConfirmation ??
          this.isAwaitingControllerConfirmation,
      availableActions: availableActions ?? this.availableActions,
      hasPinnedShortageAlert:
          hasPinnedShortageAlert ?? this.hasPinnedShortageAlert,
      activeShortageLabel: identical(activeShortageLabel, _unset)
          ? this.activeShortageLabel
          : activeShortageLabel as String?,
      activeShortageMedicationLabel:
          identical(activeShortageMedicationLabel, _unset)
          ? this.activeShortageMedicationLabel
          : activeShortageMedicationLabel as String?,
      activeShortageScheduledLabel:
          identical(activeShortageScheduledLabel, _unset)
          ? this.activeShortageScheduledLabel
          : activeShortageScheduledLabel as String?,
      activeShortageSlotNumber: identical(activeShortageSlotNumber, _unset)
          ? this.activeShortageSlotNumber
          : activeShortageSlotNumber as int?,
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
        other.networkAdvisory == networkAdvisory &&
        other.actionDoseId == actionDoseId &&
        other.voiceOccurrenceKey == voiceOccurrenceKey &&
        other.isAwaitingControllerConfirmation ==
            isAwaitingControllerConfirmation &&
        other.hasPinnedShortageAlert == hasPinnedShortageAlert &&
        other.activeShortageLabel == activeShortageLabel &&
        other.activeShortageMedicationLabel == activeShortageMedicationLabel &&
        other.activeShortageScheduledLabel == activeShortageScheduledLabel &&
        other.activeShortageSlotNumber == activeShortageSlotNumber &&
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
    networkAdvisory,
    actionDoseId,
    voiceOccurrenceKey,
    isAwaitingControllerConfirmation,
    hasPinnedShortageAlert,
    activeShortageLabel,
    activeShortageMedicationLabel,
    activeShortageScheduledLabel,
    activeShortageSlotNumber,
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
