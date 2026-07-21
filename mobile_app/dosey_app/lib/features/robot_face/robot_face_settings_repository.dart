import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings.dart';

class RobotFaceSettingsRepository {
  RobotFaceSettingsRepository(this._database);

  static const _isFlippedKey = 'robot_face_is_flipped';
  static const _dimAfterInactivityKey = 'robot_face_dim_after_inactivity';
  static const _voiceEnabledKey = 'robot_face_voice_enabled';
  static const _voiceVarietyEnabledKey = 'robot_face_voice_variety_enabled';
  static const _wakeBeforeDoseMinutesKey =
      'robot_face_wake_before_dose_minutes';
  static const _stayAwakeAfterDoseMinutesKey =
      'robot_face_stay_awake_after_dose_minutes';

  final DoseyDatabase _database;

  Stream<RobotFaceSettings> watchSettings() {
    return _database
        .watchAppSettings({
          _isFlippedKey,
          _dimAfterInactivityKey,
          _voiceEnabledKey,
          _voiceVarietyEnabledKey,
          _wakeBeforeDoseMinutesKey,
          _stayAwakeAfterDoseMinutesKey,
        })
        .map(_mapSettings);
  }

  Future<RobotFaceSettings> getSettings() async {
    final settings = await _database.getAppSettings({
      _isFlippedKey,
      _dimAfterInactivityKey,
      _voiceEnabledKey,
      _voiceVarietyEnabledKey,
      _wakeBeforeDoseMinutesKey,
      _stayAwakeAfterDoseMinutesKey,
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
        _wakeBeforeDoseMinutesKey,
        settings.wakeBeforeDoseMinutes.toString(),
      );
      await _database.setAppSetting(
        _stayAwakeAfterDoseMinutesKey,
        settings.stayAwakeAfterDoseMinutes.toString(),
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
      wakeBeforeDoseMinutes:
          int.tryParse(values[_wakeBeforeDoseMinutesKey] ?? '') ??
          RobotFaceSettings.defaultWakeBeforeDoseMinutes,
      stayAwakeAfterDoseMinutes:
          int.tryParse(values[_stayAwakeAfterDoseMinutesKey] ?? '') ??
          RobotFaceSettings.defaultStayAwakeAfterDoseMinutes,
    );
  }
}
