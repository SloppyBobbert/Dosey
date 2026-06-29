import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';

class LocalAppSettingsRepository {
  LocalAppSettingsRepository(this._database, {required this.defaultRole});

  static const _deviceRoleKey = 'device_role';
  static const _onboardingCompletedKey = 'onboarding_completed';
  static const _safetyAcknowledgedKey = 'safety_acknowledged';

  final DoseyDatabase _database;
  final AppDeviceRole defaultRole;

  Stream<AppDeviceRole> watchDeviceRole() {
    final query = _database.select(_database.appSettings)
      ..where((setting) => setting.key.equals(_deviceRoleKey));

    return query.watchSingleOrNull().map((setting) {
      if (setting == null) {
        return defaultRole;
      }

      return AppDeviceRole.fromStorageValue(setting.value) ?? defaultRole;
    });
  }

  Future<AppDeviceRole> getDeviceRole() async {
    final query = _database.select(_database.appSettings)
      ..where((setting) => setting.key.equals(_deviceRoleKey));
    final setting = await query.getSingleOrNull();
    if (setting == null) {
      return defaultRole;
    }

    return AppDeviceRole.fromStorageValue(setting.value) ?? defaultRole;
  }

  Future<void> setDeviceRole(AppDeviceRole role) {
    return _setValue(_deviceRoleKey, role.storageValue);
  }

  Stream<bool> watchOnboardingCompleted() {
    final query = _database.select(_database.appSettings)
      ..where((setting) => setting.key.equals(_onboardingCompletedKey));

    return query.watchSingleOrNull().map((setting) {
      return setting?.value == 'true';
    });
  }

  Future<void> setOnboardingCompleted(bool completed) {
    return _setValue(_onboardingCompletedKey, completed.toString());
  }

  Stream<bool> watchSafetyAcknowledged() {
    final query = _database.select(_database.appSettings)
      ..where((setting) => setting.key.equals(_safetyAcknowledgedKey));

    return query.watchSingleOrNull().map((setting) {
      return setting?.value == 'true';
    });
  }

  Future<void> setSafetyAcknowledged(bool acknowledged) {
    return _setValue(_safetyAcknowledgedKey, acknowledged.toString());
  }

  Future<void> resetSetupState() {
    return _database.transaction(() async {
      await _setValue(_safetyAcknowledgedKey, false.toString());
      await _setValue(_onboardingCompletedKey, false.toString());
    });
  }

  Future<void> _setValue(String key, String value) {
    return _database
        .into(_database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: key,
            value: value,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }
}
