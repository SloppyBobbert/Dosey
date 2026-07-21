class RobotFaceSettings {
  const RobotFaceSettings({
    this.isFlipped = false,
    this.dimAfterInactivity = true,
    this.voiceEnabled = false,
    this.voiceVarietyEnabled = false,
    int wakeBeforeDoseMinutes = defaultWakeBeforeDoseMinutes,
    int stayAwakeAfterDoseMinutes = defaultStayAwakeAfterDoseMinutes,
  }) : wakeBeforeDoseMinutes = wakeBeforeDoseMinutes < 0
           ? defaultWakeBeforeDoseMinutes
           : wakeBeforeDoseMinutes,
       stayAwakeAfterDoseMinutes = stayAwakeAfterDoseMinutes < 0
           ? defaultStayAwakeAfterDoseMinutes
           : stayAwakeAfterDoseMinutes;

  static const int defaultWakeBeforeDoseMinutes = 10;
  static const int defaultStayAwakeAfterDoseMinutes = 10;

  final bool isFlipped;
  final bool dimAfterInactivity;
  final bool voiceEnabled;
  final bool voiceVarietyEnabled;
  final int wakeBeforeDoseMinutes;
  final int stayAwakeAfterDoseMinutes;

  RobotFaceSettings copyWith({
    bool? isFlipped,
    bool? dimAfterInactivity,
    bool? voiceEnabled,
    bool? voiceVarietyEnabled,
    int? wakeBeforeDoseMinutes,
    int? stayAwakeAfterDoseMinutes,
  }) {
    return RobotFaceSettings(
      isFlipped: isFlipped ?? this.isFlipped,
      dimAfterInactivity: dimAfterInactivity ?? this.dimAfterInactivity,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      voiceVarietyEnabled: voiceVarietyEnabled ?? this.voiceVarietyEnabled,
      wakeBeforeDoseMinutes:
          wakeBeforeDoseMinutes ?? this.wakeBeforeDoseMinutes,
      stayAwakeAfterDoseMinutes:
          stayAwakeAfterDoseMinutes ?? this.stayAwakeAfterDoseMinutes,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is RobotFaceSettings &&
        other.isFlipped == isFlipped &&
        other.dimAfterInactivity == dimAfterInactivity &&
        other.voiceEnabled == voiceEnabled &&
        other.voiceVarietyEnabled == voiceVarietyEnabled &&
        other.wakeBeforeDoseMinutes == wakeBeforeDoseMinutes &&
        other.stayAwakeAfterDoseMinutes == stayAwakeAfterDoseMinutes;
  }

  @override
  int get hashCode => Object.hash(
    isFlipped,
    dimAfterInactivity,
    voiceEnabled,
    voiceVarietyEnabled,
    wakeBeforeDoseMinutes,
    stayAwakeAfterDoseMinutes,
  );
}
