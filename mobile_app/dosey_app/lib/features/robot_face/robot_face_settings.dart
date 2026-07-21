// ignore_for_file: prefer_initializing_formals

enum RobotVoiceVolumePreset {
  quiet(0.45),
  normal(1.0),
  loud(1.4);

  const RobotVoiceVolumePreset(this.volume);

  final double volume;
}

class RobotFaceSettings {
  const RobotFaceSettings({
    this.isFlipped = false,
    this.dimAfterInactivity = true,
    this.voiceEnabled = false,
    this.voiceVarietyEnabled = false,
    this.voiceVolumePreset = RobotVoiceVolumePreset.normal,
    this.voiceQuietHoursEnabled = false,
    int voiceQuietHoursStartMinutes = defaultVoiceQuietHoursStartMinutes,
    int voiceQuietHoursEndMinutes = defaultVoiceQuietHoursEndMinutes,
    this.voiceSafetyDuringQuietHoursEnabled = false,
    int wakeBeforeDoseMinutes = defaultWakeBeforeDoseMinutes,
    int stayAwakeAfterDoseMinutes = defaultStayAwakeAfterDoseMinutes,
  }) : wakeBeforeDoseMinutes = wakeBeforeDoseMinutes < 0
           ? defaultWakeBeforeDoseMinutes
           : wakeBeforeDoseMinutes,
       stayAwakeAfterDoseMinutes = stayAwakeAfterDoseMinutes < 0
           ? defaultStayAwakeAfterDoseMinutes
           : stayAwakeAfterDoseMinutes,
       voiceQuietHoursStartMinutes = voiceQuietHoursStartMinutes,
       voiceQuietHoursEndMinutes = voiceQuietHoursEndMinutes;

  static const int defaultWakeBeforeDoseMinutes = 10;
  static const int defaultStayAwakeAfterDoseMinutes = 10;
  static const int defaultVoiceQuietHoursStartMinutes = 22 * 60;
  static const int defaultVoiceQuietHoursEndMinutes = 7 * 60;

  final bool isFlipped;
  final bool dimAfterInactivity;
  final bool voiceEnabled;
  final bool voiceVarietyEnabled;
  final RobotVoiceVolumePreset voiceVolumePreset;
  final bool voiceQuietHoursEnabled;
  final int voiceQuietHoursStartMinutes;
  final int voiceQuietHoursEndMinutes;
  final bool voiceSafetyDuringQuietHoursEnabled;
  final int wakeBeforeDoseMinutes;
  final int stayAwakeAfterDoseMinutes;

  RobotFaceSettings copyWith({
    bool? isFlipped,
    bool? dimAfterInactivity,
    bool? voiceEnabled,
    bool? voiceVarietyEnabled,
    RobotVoiceVolumePreset? voiceVolumePreset,
    bool? voiceQuietHoursEnabled,
    int? voiceQuietHoursStartMinutes,
    int? voiceQuietHoursEndMinutes,
    bool? voiceSafetyDuringQuietHoursEnabled,
    int? wakeBeforeDoseMinutes,
    int? stayAwakeAfterDoseMinutes,
  }) {
    return RobotFaceSettings(
      isFlipped: isFlipped ?? this.isFlipped,
      dimAfterInactivity: dimAfterInactivity ?? this.dimAfterInactivity,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      voiceVarietyEnabled: voiceVarietyEnabled ?? this.voiceVarietyEnabled,
      voiceVolumePreset: voiceVolumePreset ?? this.voiceVolumePreset,
      voiceQuietHoursEnabled:
          voiceQuietHoursEnabled ?? this.voiceQuietHoursEnabled,
      voiceQuietHoursStartMinutes:
          voiceQuietHoursStartMinutes ?? this.voiceQuietHoursStartMinutes,
      voiceQuietHoursEndMinutes:
          voiceQuietHoursEndMinutes ?? this.voiceQuietHoursEndMinutes,
      voiceSafetyDuringQuietHoursEnabled:
          voiceSafetyDuringQuietHoursEnabled ??
          this.voiceSafetyDuringQuietHoursEnabled,
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
        other.voiceVolumePreset == voiceVolumePreset &&
        other.voiceQuietHoursEnabled == voiceQuietHoursEnabled &&
        other.voiceQuietHoursStartMinutes == voiceQuietHoursStartMinutes &&
        other.voiceQuietHoursEndMinutes == voiceQuietHoursEndMinutes &&
        other.voiceSafetyDuringQuietHoursEnabled ==
            voiceSafetyDuringQuietHoursEnabled &&
        other.wakeBeforeDoseMinutes == wakeBeforeDoseMinutes &&
        other.stayAwakeAfterDoseMinutes == stayAwakeAfterDoseMinutes;
  }

  @override
  int get hashCode => Object.hash(
    isFlipped,
    dimAfterInactivity,
    voiceEnabled,
    voiceVarietyEnabled,
    voiceVolumePreset,
    voiceQuietHoursEnabled,
    voiceQuietHoursStartMinutes,
    voiceQuietHoursEndMinutes,
    voiceSafetyDuringQuietHoursEnabled,
    wakeBeforeDoseMinutes,
    stayAwakeAfterDoseMinutes,
  );
}
