import 'package:dosey_app/core/build/app_build_profile.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';

/// Resolves a persisted role within the build profile's platform policy.
class EffectiveDeviceRoleSource {
  EffectiveDeviceRoleSource(
    this._settings, {
    required AppBuildProfile profile,
    required AppDevicePlatform platform,
  }) : capabilities = profile.resolve(platform);

  final LocalAppSettingsRepository _settings;
  final AppBuildCapabilities capabilities;

  Stream<AppDeviceRole> watchDeviceRole() {
    return _settings.watchPersistedDeviceRole().map(
      (role) => _validate(role ?? capabilities.defaultRole),
    );
  }

  Future<AppDeviceRole> getDeviceRole() async {
    return _validate(await _settings.getDeviceRole());
  }

  Future<AppDeviceRole> getLegacyRoleForDiagnostics() {
    return _settings.getDeviceRole();
  }

  AppDeviceRole _validate(AppDeviceRole role) {
    return capabilities.allows(role) ? role : capabilities.defaultRole;
  }
}
