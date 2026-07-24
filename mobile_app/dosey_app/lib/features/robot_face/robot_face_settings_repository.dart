import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings.dart';

class RobotFaceSettingsRepository {
  RobotFaceSettingsRepository(this._database);

  static const _isFlippedKey = 'robot_face_is_flipped';
  static const _dimAfterInactivityKey = 'robot_face_dim_after_inactivity';
  static const _voiceEnabledKey = 'robot_face_voice_enabled';
  static const _voiceVarietyEnabledKey = 'robot_face_voice_variety_enabled';
  static const _voiceVolumePresetKey = 'robot_face_voice_volume_preset';
  static const _voiceQuietHoursEnabledKey =
      'robot_face_voice_quiet_hours_enabled';
  static const _voiceQuietHoursStartMinutesKey =
      'robot_face_voice_quiet_hours_start_minutes';
  static const _voiceQuietHoursEndMinutesKey =
      'robot_face_voice_quiet_hours_end_minutes';
  static const _voiceSafetyDuringQuietHoursEnabledKey =
      'robot_face_voice_safety_during_quiet_hours_enabled';
  static const _reminderVoiceEnabledKey = 'robot_face_reminder_voice_enabled';
  static const _dispenseNarrationEnabledKey =
      'robot_face_dispense_narration_enabled';
  static const _safetyConfirmationVoiceEnabledKey =
      'robot_face_safety_confirmation_voice_enabled';
  static const _missedDoseVoiceEnabledKey =
      'robot_face_missed_dose_voice_enabled';
  static const _controllerAlertVoiceEnabledKey =
      'robot_face_controller_alert_voice_enabled';
  static const _idleChatterVoiceEnabledKey =
      'robot_face_idle_chatter_voice_enabled';
  static const _idleChatterCooldownMinutesKey =
      'robot_face_idle_chatter_cooldown_minutes';
  static const _reminderRepeatCooldownMinutesKey =
      'robot_face_reminder_repeat_cooldown_minutes';
  static const _reminderRepeatPolicyKey = 'robot_face_reminder_repeat_policy';
  static const _wakeBeforeDoseMinutesKey =
      'robot_face_wake_before_dose_minutes';
  static const _stayAwakeAfterDoseMinutesKey =
      'robot_face_stay_awake_after_dose_minutes';
  static const _returnToFaceAfterInactivityMinutesKey =
      'robot_face_return_to_face_after_inactivity_minutes';

  final DoseyDatabase _database;

  Stream<RobotFaceSettings> watchSettings() {
    return _database
        .watchAppSettings({
          _isFlippedKey,
          _dimAfterInactivityKey,
          _voiceEnabledKey,
          _voiceVarietyEnabledKey,
          _voiceVolumePresetKey,
          _voiceQuietHoursEnabledKey,
          _voiceQuietHoursStartMinutesKey,
          _voiceQuietHoursEndMinutesKey,
          _voiceSafetyDuringQuietHoursEnabledKey,
          _reminderVoiceEnabledKey,
          _dispenseNarrationEnabledKey,
          _safetyConfirmationVoiceEnabledKey,
          _missedDoseVoiceEnabledKey,
          _controllerAlertVoiceEnabledKey,
          _idleChatterVoiceEnabledKey,
          _idleChatterCooldownMinutesKey,
          _reminderRepeatCooldownMinutesKey,
          _reminderRepeatPolicyKey,
          _wakeBeforeDoseMinutesKey,
          _stayAwakeAfterDoseMinutesKey,
          _returnToFaceAfterInactivityMinutesKey,
        })
        .map(_mapSettings);
  }

  Future<RobotFaceSettings> getSettings() async {
    final settings = await _database.getAppSettings({
      _isFlippedKey,
      _dimAfterInactivityKey,
      _voiceEnabledKey,
      _voiceVarietyEnabledKey,
      _voiceVolumePresetKey,
      _voiceQuietHoursEnabledKey,
      _voiceQuietHoursStartMinutesKey,
      _voiceQuietHoursEndMinutesKey,
      _voiceSafetyDuringQuietHoursEnabledKey,
      _reminderVoiceEnabledKey,
      _dispenseNarrationEnabledKey,
      _safetyConfirmationVoiceEnabledKey,
      _missedDoseVoiceEnabledKey,
      _controllerAlertVoiceEnabledKey,
      _idleChatterVoiceEnabledKey,
      _idleChatterCooldownMinutesKey,
      _reminderRepeatCooldownMinutesKey,
      _reminderRepeatPolicyKey,
      _wakeBeforeDoseMinutesKey,
      _stayAwakeAfterDoseMinutesKey,
      _returnToFaceAfterInactivityMinutesKey,
    });

    return _mapSettings(settings);
  }

  Future<void> saveSettings(RobotFaceSettings settings) async {
    await _database.transaction(() async {
      await _database.setAppSetting(
        _isFlippedKey,
        settings.isFlipped.toString(),
      );
      await _database.setAppSetting(
        _dimAfterInactivityKey,
        settings.dimAfterInactivity.toString(),
      );
      await _database.setAppSetting(
        _voiceEnabledKey,
        settings.voiceEnabled.toString(),
      );
      await _database.setAppSetting(
        _voiceVarietyEnabledKey,
        settings.voiceVarietyEnabled.toString(),
      );
      await _database.setAppSetting(
        _voiceVolumePresetKey,
        settings.voiceVolumePreset.name,
      );
      await _database.setAppSetting(
        _voiceQuietHoursEnabledKey,
        settings.voiceQuietHoursEnabled.toString(),
      );
      await _database.setAppSetting(
        _voiceQuietHoursStartMinutesKey,
        settings.voiceQuietHoursStartMinutes.toString(),
      );
      await _database.setAppSetting(
        _voiceQuietHoursEndMinutesKey,
        settings.voiceQuietHoursEndMinutes.toString(),
      );
      await _database.setAppSetting(
        _voiceSafetyDuringQuietHoursEnabledKey,
        settings.voiceSafetyDuringQuietHoursEnabled.toString(),
      );
      await _database.setAppSetting(
        _reminderVoiceEnabledKey,
        settings.reminderVoiceEnabled.toString(),
      );
      await _database.setAppSetting(
        _dispenseNarrationEnabledKey,
        settings.dispenseNarrationEnabled.toString(),
      );
      await _database.setAppSetting(
        _safetyConfirmationVoiceEnabledKey,
        settings.safetyConfirmationVoiceEnabled.toString(),
      );
      await _database.setAppSetting(
        _missedDoseVoiceEnabledKey,
        settings.missedDoseVoiceEnabled.toString(),
      );
      await _database.setAppSetting(
        _controllerAlertVoiceEnabledKey,
        settings.controllerAlertVoiceEnabled.toString(),
      );
      await _database.setAppSetting(
        _idleChatterVoiceEnabledKey,
        settings.idleChatterVoiceEnabled.toString(),
      );
      await _database.setAppSetting(
        _idleChatterCooldownMinutesKey,
        settings.idleChatterCooldownMinutes.toString(),
      );
      await _database.setAppSetting(
        _reminderRepeatCooldownMinutesKey,
        settings.reminderRepeatCooldownMinutes.toString(),
      );
      await _database.setAppSetting(
        _reminderRepeatPolicyKey,
        settings.reminderRepeatPolicy.name,
      );
      await _database.setAppSetting(
        _wakeBeforeDoseMinutesKey,
        settings.wakeBeforeDoseMinutes.toString(),
      );
      await _database.setAppSetting(
        _stayAwakeAfterDoseMinutesKey,
        settings.stayAwakeAfterDoseMinutes.toString(),
      );
      await _database.setAppSetting(
        _returnToFaceAfterInactivityMinutesKey,
        settings.returnToFaceAfterInactivityMinutes.toString(),
      );
    });
  }

  RobotFaceSettings _mapSettings(List<AppSetting> settings) {
    final values = {for (final setting in settings) setting.key: setting.value};
    const defaultSettings = RobotFaceSettings();

    return RobotFaceSettings(
      isFlipped: values[_isFlippedKey] == 'true',
      dimAfterInactivity: values.containsKey(_dimAfterInactivityKey)
          ? values[_dimAfterInactivityKey] == 'true'
          : defaultSettings.dimAfterInactivity,
      voiceEnabled: values.containsKey(_voiceEnabledKey)
          ? values[_voiceEnabledKey] == 'true'
          : defaultSettings.voiceEnabled,
      voiceVarietyEnabled: values.containsKey(_voiceVarietyEnabledKey)
          ? values[_voiceVarietyEnabledKey] == 'true'
          : defaultSettings.voiceVarietyEnabled,
      voiceVolumePreset: _voiceVolumePresetFor(
        values[_voiceVolumePresetKey],
        defaultSettings.voiceVolumePreset,
      ),
      voiceQuietHoursEnabled: values.containsKey(_voiceQuietHoursEnabledKey)
          ? values[_voiceQuietHoursEnabledKey] == 'true'
          : defaultSettings.voiceQuietHoursEnabled,
      voiceQuietHoursStartMinutes:
          int.tryParse(values[_voiceQuietHoursStartMinutesKey] ?? '') ??
          RobotFaceSettings.defaultVoiceQuietHoursStartMinutes,
      voiceQuietHoursEndMinutes:
          int.tryParse(values[_voiceQuietHoursEndMinutesKey] ?? '') ??
          RobotFaceSettings.defaultVoiceQuietHoursEndMinutes,
      voiceSafetyDuringQuietHoursEnabled:
          values.containsKey(_voiceSafetyDuringQuietHoursEnabledKey)
          ? values[_voiceSafetyDuringQuietHoursEnabledKey] == 'true'
          : defaultSettings.voiceSafetyDuringQuietHoursEnabled,
      reminderVoiceEnabled: values.containsKey(_reminderVoiceEnabledKey)
          ? values[_reminderVoiceEnabledKey] == 'true'
          : defaultSettings.reminderVoiceEnabled,
      dispenseNarrationEnabled: values.containsKey(_dispenseNarrationEnabledKey)
          ? values[_dispenseNarrationEnabledKey] == 'true'
          : defaultSettings.dispenseNarrationEnabled,
      safetyConfirmationVoiceEnabled:
          values.containsKey(_safetyConfirmationVoiceEnabledKey)
          ? values[_safetyConfirmationVoiceEnabledKey] == 'true'
          : defaultSettings.safetyConfirmationVoiceEnabled,
      missedDoseVoiceEnabled: values.containsKey(_missedDoseVoiceEnabledKey)
          ? values[_missedDoseVoiceEnabledKey] == 'true'
          : defaultSettings.missedDoseVoiceEnabled,
      controllerAlertVoiceEnabled:
          values.containsKey(_controllerAlertVoiceEnabledKey)
          ? values[_controllerAlertVoiceEnabledKey] == 'true'
          : defaultSettings.controllerAlertVoiceEnabled,
      idleChatterVoiceEnabled: values.containsKey(_idleChatterVoiceEnabledKey)
          ? values[_idleChatterVoiceEnabledKey] == 'true'
          : defaultSettings.idleChatterVoiceEnabled,
      idleChatterCooldownMinutes:
          int.tryParse(values[_idleChatterCooldownMinutesKey] ?? '') ??
          RobotFaceSettings.defaultIdleChatterCooldownMinutes,
      reminderRepeatCooldownMinutes:
          int.tryParse(values[_reminderRepeatCooldownMinutesKey] ?? '') ??
          RobotFaceSettings.defaultReminderRepeatCooldownMinutes,
      reminderRepeatPolicy: _reminderRepeatPolicyFor(
        values[_reminderRepeatPolicyKey],
        defaultSettings.reminderRepeatPolicy,
      ),
      wakeBeforeDoseMinutes:
          int.tryParse(values[_wakeBeforeDoseMinutesKey] ?? '') ??
          RobotFaceSettings.defaultWakeBeforeDoseMinutes,
      stayAwakeAfterDoseMinutes:
          int.tryParse(values[_stayAwakeAfterDoseMinutesKey] ?? '') ??
          RobotFaceSettings.defaultStayAwakeAfterDoseMinutes,
      returnToFaceAfterInactivityMinutes:
          int.tryParse(values[_returnToFaceAfterInactivityMinutesKey] ?? '') ??
          RobotFaceSettings.defaultReturnToFaceAfterInactivityMinutes,
    );
  }

  RobotVoiceVolumePreset _voiceVolumePresetFor(
    String? rawValue,
    RobotVoiceVolumePreset fallback,
  ) {
    for (final preset in RobotVoiceVolumePreset.values) {
      if (preset.name == rawValue) {
        return preset;
      }
    }
    return fallback;
  }

  RobotReminderRepeatPolicy _reminderRepeatPolicyFor(
    String? rawValue,
    RobotReminderRepeatPolicy fallback,
  ) {
    for (final policy in RobotReminderRepeatPolicy.values) {
      if (policy.name == rawValue) {
        return policy;
      }
    }
    return fallback;
  }
}
