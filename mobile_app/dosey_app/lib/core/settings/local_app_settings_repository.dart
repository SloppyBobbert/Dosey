import 'dart:math';

import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/audit/local_admin_audit_repository.dart';
import 'package:dosey_app/core/settings/app_theme_preference.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';

class GuidedTrialCompletion {
  const GuidedTrialCompletion({
    required this.completedAt,
    required this.appVersion,
  });

  final DateTime completedAt;
  final String appVersion;

  @override
  bool operator ==(Object other) =>
      other is GuidedTrialCompletion &&
      other.completedAt == completedAt &&
      other.appVersion == appVersion;

  @override
  int get hashCode => Object.hash(completedAt, appVersion);
}

class LocalAppSettingsRepository {
  LocalAppSettingsRepository(this._database, {required this.defaultRole});

  static const _deviceRoleKey = 'device_role';
  static const _themePreferenceKey = 'theme_preference';
  static const _onboardingCompletedKey = 'onboarding_completed';
  static const _safetyAcknowledgedKey = 'safety_acknowledged';
  static const _actionPinHashKey = 'action_pin_hash';
  static const _actionPinSaltKey = 'action_pin_salt';
  static const _guidedTrialCompletedKey = 'guided_trial_completed';
  static const _guidedTrialCompletedAtKey = 'guided_trial_completed_at';
  static const _guidedTrialAppVersionKey = 'guided_trial_app_version';

  final DoseyDatabase _database;
  final AppDeviceRole defaultRole;

  Stream<AppThemePreference> watchThemePreference() {
    final query = _database.select(_database.appSettings)
      ..where((setting) => setting.key.equals(_themePreferenceKey));

    return query.watchSingleOrNull().map(
      (setting) =>
          AppThemePreference.fromStorageValue(setting?.value ?? '') ??
          AppThemePreference.dark,
    );
  }

  Future<void> setThemePreference(AppThemePreference preference) {
    return _setValue(_themePreferenceKey, preference.storageValue);
  }

  Stream<AppDeviceRole> watchDeviceRole() {
    return watchPersistedDeviceRole().map((role) => role ?? defaultRole);
  }

  Stream<AppDeviceRole?> watchPersistedDeviceRole() {
    final query = _database.select(_database.appSettings)
      ..where((setting) => setting.key.equals(_deviceRoleKey));

    return query.watchSingleOrNull().map((setting) {
      if (setting == null) return null;
      final role = AppDeviceRole.fromStorageValue(setting.value);
      if (role == null) {
        throw FormatException('Unsupported persisted device role.');
      }
      return role;
    });
  }

  Future<AppDeviceRole> getDeviceRole() async {
    return await getPersistedDeviceRole() ?? defaultRole;
  }

  Future<AppDeviceRole?> getPersistedDeviceRole() async {
    final query = _database.select(_database.appSettings)
      ..where((setting) => setting.key.equals(_deviceRoleKey));
    final setting = await query.getSingleOrNull();
    if (setting == null) return null;
    final role = AppDeviceRole.fromStorageValue(setting.value);
    if (role == null) {
      throw FormatException('Unsupported persisted device role.');
    }
    return role;
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

  Future<GuidedTrialCompletion?> getGuidedTrialCompletion() async {
    final settings = await _database.getAppSettings({
      _guidedTrialCompletedKey,
      _guidedTrialCompletedAtKey,
      _guidedTrialAppVersionKey,
    });
    final valuesByKey = {
      for (final setting in settings) setting.key: setting.value,
    };
    if (valuesByKey[_guidedTrialCompletedKey] != 'true') return null;

    final completedAt = DateTime.tryParse(
      valuesByKey[_guidedTrialCompletedAtKey] ?? '',
    );
    final appVersion = valuesByKey[_guidedTrialAppVersionKey]?.trim() ?? '';
    if (completedAt == null || appVersion.isEmpty) return null;

    return GuidedTrialCompletion(
      completedAt: completedAt.toUtc(),
      appVersion: appVersion,
    );
  }

  Future<void> setGuidedTrialCompleted({
    required DateTime completedAt,
    required String appVersion,
  }) {
    final normalizedVersion = appVersion.trim();
    if (normalizedVersion.isEmpty) {
      throw ArgumentError.value(appVersion, 'appVersion', 'must not be empty');
    }
    return _database.transaction(() async {
      await _setValue(_guidedTrialCompletedKey, true.toString());
      await _setValue(
        _guidedTrialCompletedAtKey,
        completedAt.toUtc().toIso8601String(),
      );
      await _setValue(_guidedTrialAppVersionKey, normalizedVersion);
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
