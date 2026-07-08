import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings.dart';

class RobotFaceSettingsRepository {
  RobotFaceSettingsRepository(this._database);

  static const _isFlippedKey = 'robot_face_is_flipped';
  static const _dimAfterInactivityKey = 'robot_face_dim_after_inactivity';
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
          _wakeBeforeDoseMinutesKey,
          _stayAwakeAfterDoseMinutesKey,
        })
        .map(_mapSettings);
  }

  Future<RobotFaceSettings> getSettings() async {
    final settings = await _database.getAppSettings({
      _isFlippedKey,
      _dimAfterInactivityKey,
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

    return RobotFaceSettings(
      isFlipped: values[_isFlippedKey] == 'true',
      dimAfterInactivity: values[_dimAfterInactivityKey] != 'false',
      wakeBeforeDoseMinutes:
          int.tryParse(values[_wakeBeforeDoseMinutesKey] ?? '') ??
          RobotFaceSettings.defaultWakeBeforeDoseMinutes,
      stayAwakeAfterDoseMinutes:
          int.tryParse(values[_stayAwakeAfterDoseMinutesKey] ?? '') ??
          RobotFaceSettings.defaultStayAwakeAfterDoseMinutes,
    );
  }
}
