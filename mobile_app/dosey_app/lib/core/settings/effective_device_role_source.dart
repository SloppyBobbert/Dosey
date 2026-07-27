import 'package:dosey_app/core/build/app_build_profile.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';

class EffectiveDeviceRoleSource {
  EffectiveDeviceRoleSource(
    this._settings, {
    required AppBuildProfile profile,
    required AppDevicePlatform platform,
  }) : capabilities = profile.resolve(platform);

  final LocalAppSettingsRepository _settings;
  final AppBuildCapabilities capabilities;

  Stream<AppDeviceRole> watchDeviceRole() {
    return Stream<AppDeviceRole>.value(capabilities.fixedRole);
  }

  Future<AppDeviceRole> getDeviceRole() async => capabilities.fixedRole;

  Future<AppDeviceRole> getLegacyRoleForDiagnostics() {
    return _settings.getDeviceRole();
  }
}
