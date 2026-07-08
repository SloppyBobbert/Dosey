import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings.dart';

class RobotFaceSettingsRepository {
  RobotFaceSettingsRepository(this._database);

  static const _isFlippedKey = 'robot_face_is_flipped';
  static const _dimAfterInactivityKey = 'robot_face_dim_after_inactivity';

  final DoseyDatabase _database;

  Stream<RobotFaceSettings> watchSettings() {
    return _database
        .watchAppSettings({_isFlippedKey, _dimAfterInactivityKey})
        .map(_mapSettings);
  }

  Future<RobotFaceSettings> getSettings() async {
    final settings = await _database.getAppSettings({
      _isFlippedKey,
      _dimAfterInactivityKey,
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
    });
  }

  RobotFaceSettings _mapSettings(List<AppSetting> settings) {
    final values = {for (final setting in settings) setting.key: setting.value};

    return RobotFaceSettings(
      isFlipped: values[_isFlippedKey] == 'true',
      dimAfterInactivity: values[_dimAfterInactivityKey] != 'false',
    );
  }
}
