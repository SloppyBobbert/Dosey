class RobotFaceSettings {
  const RobotFaceSettings({
    this.isFlipped = false,
    this.dimAfterInactivity = true,
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
  final int wakeBeforeDoseMinutes;
  final int stayAwakeAfterDoseMinutes;

  RobotFaceSettings copyWith({
    bool? isFlipped,
    bool? dimAfterInactivity,
    int? wakeBeforeDoseMinutes,
    int? stayAwakeAfterDoseMinutes,
  }) {
    return RobotFaceSettings(
      isFlipped: isFlipped ?? this.isFlipped,
      dimAfterInactivity: dimAfterInactivity ?? this.dimAfterInactivity,
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
        other.wakeBeforeDoseMinutes == wakeBeforeDoseMinutes &&
        other.stayAwakeAfterDoseMinutes == stayAwakeAfterDoseMinutes;
  }

  @override
  int get hashCode => Object.hash(
    isFlipped,
    dimAfterInactivity,
    wakeBeforeDoseMinutes,
    stayAwakeAfterDoseMinutes,
  );
}
