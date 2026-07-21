enum RobotVoiceVolumePreset {
  quiet(0.45),
  normal(1.0),
  loud(1.0);

  const RobotVoiceVolumePreset(this.volume);

  final double volume;
}

enum RobotReminderRepeatPolicy {
  noRepeats,
  repeatRemindersOnly,
  repeatRemindersAndReady,
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
    this.reminderVoiceEnabled = true,
    this.dispenseNarrationEnabled = true,
    this.safetyConfirmationVoiceEnabled = true,
    this.missedDoseVoiceEnabled = true,
    this.controllerAlertVoiceEnabled = true,
    this.idleChatterVoiceEnabled = true,
    int idleChatterCooldownMinutes = defaultIdleChatterCooldownMinutes,
    int reminderRepeatCooldownMinutes = defaultReminderRepeatCooldownMinutes,
    this.reminderRepeatPolicy = RobotReminderRepeatPolicy.noRepeats,
    int wakeBeforeDoseMinutes = defaultWakeBeforeDoseMinutes,
    int stayAwakeAfterDoseMinutes = defaultStayAwakeAfterDoseMinutes,
  }) : wakeBeforeDoseMinutes = wakeBeforeDoseMinutes < 0
           ? defaultWakeBeforeDoseMinutes
           : wakeBeforeDoseMinutes,
       idleChatterCooldownMinutes = idleChatterCooldownMinutes < 0
           ? defaultIdleChatterCooldownMinutes
           : idleChatterCooldownMinutes,
       reminderRepeatCooldownMinutes = reminderRepeatCooldownMinutes < 0
           ? defaultReminderRepeatCooldownMinutes
           : reminderRepeatCooldownMinutes,
       stayAwakeAfterDoseMinutes = stayAwakeAfterDoseMinutes < 0
           ? defaultStayAwakeAfterDoseMinutes
           : stayAwakeAfterDoseMinutes,
       voiceQuietHoursStartMinutes =
           voiceQuietHoursStartMinutes < 0 ||
               voiceQuietHoursStartMinutes >= 24 * 60
           ? defaultVoiceQuietHoursStartMinutes
           : voiceQuietHoursStartMinutes,
       voiceQuietHoursEndMinutes =
           voiceQuietHoursEndMinutes < 0 || voiceQuietHoursEndMinutes >= 24 * 60
           ? defaultVoiceQuietHoursEndMinutes
           : voiceQuietHoursEndMinutes;

  static const int defaultWakeBeforeDoseMinutes = 10;
  static const int defaultStayAwakeAfterDoseMinutes = 10;
  static const int defaultIdleChatterCooldownMinutes = 10;
  static const int defaultReminderRepeatCooldownMinutes = 5;
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
  final bool reminderVoiceEnabled;
  final bool dispenseNarrationEnabled;
  final bool safetyConfirmationVoiceEnabled;
  final bool missedDoseVoiceEnabled;
  final bool controllerAlertVoiceEnabled;
  final bool idleChatterVoiceEnabled;
  final int idleChatterCooldownMinutes;
  final int reminderRepeatCooldownMinutes;
  final RobotReminderRepeatPolicy reminderRepeatPolicy;
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
    bool? reminderVoiceEnabled,
    bool? dispenseNarrationEnabled,
    bool? safetyConfirmationVoiceEnabled,
    bool? missedDoseVoiceEnabled,
    bool? controllerAlertVoiceEnabled,
    bool? idleChatterVoiceEnabled,
    int? idleChatterCooldownMinutes,
    int? reminderRepeatCooldownMinutes,
    RobotReminderRepeatPolicy? reminderRepeatPolicy,
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
      reminderVoiceEnabled: reminderVoiceEnabled ?? this.reminderVoiceEnabled,
      dispenseNarrationEnabled:
          dispenseNarrationEnabled ?? this.dispenseNarrationEnabled,
      safetyConfirmationVoiceEnabled:
          safetyConfirmationVoiceEnabled ?? this.safetyConfirmationVoiceEnabled,
      missedDoseVoiceEnabled:
          missedDoseVoiceEnabled ?? this.missedDoseVoiceEnabled,
      controllerAlertVoiceEnabled:
          controllerAlertVoiceEnabled ?? this.controllerAlertVoiceEnabled,
      idleChatterVoiceEnabled:
          idleChatterVoiceEnabled ?? this.idleChatterVoiceEnabled,
      idleChatterCooldownMinutes:
          idleChatterCooldownMinutes ?? this.idleChatterCooldownMinutes,
      reminderRepeatCooldownMinutes:
          reminderRepeatCooldownMinutes ?? this.reminderRepeatCooldownMinutes,
      reminderRepeatPolicy: reminderRepeatPolicy ?? this.reminderRepeatPolicy,
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
        other.reminderVoiceEnabled == reminderVoiceEnabled &&
        other.dispenseNarrationEnabled == dispenseNarrationEnabled &&
        other.safetyConfirmationVoiceEnabled ==
            safetyConfirmationVoiceEnabled &&
        other.missedDoseVoiceEnabled == missedDoseVoiceEnabled &&
        other.controllerAlertVoiceEnabled == controllerAlertVoiceEnabled &&
        other.idleChatterVoiceEnabled == idleChatterVoiceEnabled &&
        other.idleChatterCooldownMinutes == idleChatterCooldownMinutes &&
        other.reminderRepeatCooldownMinutes == reminderRepeatCooldownMinutes &&
        other.reminderRepeatPolicy == reminderRepeatPolicy &&
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
    reminderVoiceEnabled,
    dispenseNarrationEnabled,
    safetyConfirmationVoiceEnabled,
    missedDoseVoiceEnabled,
    controllerAlertVoiceEnabled,
    idleChatterVoiceEnabled,
    idleChatterCooldownMinutes,
    reminderRepeatCooldownMinutes,
    reminderRepeatPolicy,
    wakeBeforeDoseMinutes,
    stayAwakeAfterDoseMinutes,
  );
}
