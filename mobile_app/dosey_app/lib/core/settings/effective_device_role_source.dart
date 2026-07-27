import 'package:dosey_app/core/build/app_build_profile.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';

/// Resolves an immutable device role from the build profile and platform.
///
/// [AppBuildProfile.resolve] guarantees that [capabilities.fixedRole] is valid
/// for the supplied platform.
class EffectiveDeviceRoleSource {
  EffectiveDeviceRoleSource(
    this._settings, {
    required AppBuildProfile profile,
    required AppDevicePlatform platform,
  }) : capabilities = profile.resolve(platform);

  final LocalAppSettingsRepository _settings;
  final AppBuildCapabilities capabilities;

  /// Emits the fixed device role once and then closes.
  Stream<AppDeviceRole> watchDeviceRole() {
    return Stream<AppDeviceRole>.value(capabilities.fixedRole);
  }

  Future<AppDeviceRole> getDeviceRole() async => capabilities.fixedRole;

  Future<AppDeviceRole> getLegacyRoleForDiagnostics() {
    return _settings.getDeviceRole();
  }
}
