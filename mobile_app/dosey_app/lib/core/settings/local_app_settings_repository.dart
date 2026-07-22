import 'dart:math';

import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/audit/local_admin_audit_repository.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';

class LocalAppSettingsRepository {
  LocalAppSettingsRepository(this._database, {required this.defaultRole});

  static const _deviceRoleKey = 'device_role';
  static const _onboardingCompletedKey = 'onboarding_completed';
  static const _safetyAcknowledgedKey = 'safety_acknowledged';
  static const _actionPinHashKey = 'action_pin_hash';
  static const _actionPinSaltKey = 'action_pin_salt';

  final DoseyDatabase _database;
  final AppDeviceRole defaultRole;

  Stream<AppDeviceRole> watchDeviceRole() {
    final query = _database.select(_database.appSettings)
      ..where((setting) => setting.key.equals(_deviceRoleKey));

    return query.watchSingleOrNull().map((setting) {
      if (setting == null) {
        // Fall back to the platform-specific default role until setup picks one.
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
      // Keep device role intact; setup reset only replays safety/onboarding.
      await _setValue(_safetyAcknowledgedKey, false.toString());
      await _setValue(_onboardingCompletedKey, false.toString());
    });
  }

  Stream<bool> watchActionPinEnabled() {
    return _database
        .watchAppSettings({_actionPinHashKey, _actionPinSaltKey})
        .map(_hasCompleteActionPinSettings);
  }

  Future<bool> isActionPinEnabled() async {
    final settings = await _database.getAppSettings({
      _actionPinHashKey,
      _actionPinSaltKey,
    });
    return _hasCompleteActionPinSettings(settings);
  }

  Future<void> setActionPin(String pin, {AdminAuditEvent? auditEvent}) async {
    final normalizedPin = _normalizePin(pin);
    if (normalizedPin.length < 4) {
      throw ArgumentError.value(pin, 'pin', 'PIN must be at least 4 digits.');
    }
    if (!_isDigitsOnly(normalizedPin)) {
      throw ArgumentError.value(pin, 'pin', 'PIN must contain only digits.');
    }

    final salt = _newActionPinSalt();
    final hash = _hashActionPin(normalizedPin, salt);
    await _database.transaction(() async {
      await _setValue(_actionPinSaltKey, salt);
      await _setValue(_actionPinHashKey, hash);
      if (auditEvent != null) {
        await LocalAdminAuditRepository.insertEventIntoDatabase(
          _database,
          auditEvent,
        );
      }
    });
  }

  Future<bool> verifyActionPin(String pin) async {
    final settings = await _database.getAppSettings({
      _actionPinHashKey,
      _actionPinSaltKey,
    });
    final valuesByKey = {
      for (final setting in settings) setting.key: setting.value,
    };
    final expectedHash = valuesByKey[_actionPinHashKey];
    final salt = valuesByKey[_actionPinSaltKey];
    if (expectedHash == null || salt == null) {
      return false;
    }

    return _hashActionPin(_normalizePin(pin), salt) == expectedHash;
  }

  Future<void> clearActionPin({AdminAuditEvent? auditEvent}) {
    return _database.transaction(() async {
      await _database.deleteAppSettings({_actionPinHashKey, _actionPinSaltKey});
      if (auditEvent != null) {
        await LocalAdminAuditRepository.insertEventIntoDatabase(
          _database,
          auditEvent,
        );
      }
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

  static bool _hasCompleteActionPinSettings(List<AppSetting> settings) {
    final keys = settings.map((setting) => setting.key).toSet();
    return keys.contains(_actionPinHashKey) && keys.contains(_actionPinSaltKey);
  }

  static String _normalizePin(String pin) {
    return pin.trim();
  }

  static bool _isDigitsOnly(String pin) {
    return RegExp(r'^\d+$').hasMatch(pin);
  }

  static String _newActionPinSalt() {
    final random = Random.secure();
    return List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  static String _hashActionPin(String pin, String salt) {
    // This is a lightweight local deterrent, not medical-grade security.
    var hash = 0xcbf29ce484222325;
    for (final codeUnit in '$salt:$pin'.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
