import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';

class LocalAppSettingsRepository {
  LocalAppSettingsRepository(this._database, {required this.defaultRole});

  static const _deviceRoleKey = 'device_role';

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

  Future<void> setDeviceRole(AppDeviceRole role) {
    return _database
        .into(_database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: _deviceRoleKey,
            value: role.storageValue,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }
}
