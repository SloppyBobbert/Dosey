import 'package:dosey_app/core/settings/device_role.dart';

enum AppBuildProfile {
  personal,
  robot;

  static const configuredValue = String.fromEnvironment(
    'DOSEY_BUILD_PROFILE',
    defaultValue: 'personal',
  );

  static AppBuildProfile get current => fromValue(configuredValue);

  static AppBuildProfile fromValue(String? value) {
    return value == 'robot' ? robot : personal;
  }

  AppBuildCapabilities resolve(AppDevicePlatform platform) {
    if (platform != AppDevicePlatform.android) {
      return AppBuildCapabilities(
        defaultRole: platform == AppDevicePlatform.ios
            ? AppDeviceRole.iosPersonal
            : AppDeviceRole.webPersonal,
        allowedRoles: [
          platform == AppDevicePlatform.ios
              ? AppDeviceRole.iosPersonal
              : AppDeviceRole.webPersonal,
        ],
      );
    }
    if (this == personal) {
      return const AppBuildCapabilities(
        defaultRole: AppDeviceRole.androidPersonal,
        allowedRoles: [AppDeviceRole.androidPersonal],
      );
    }
    return const AppBuildCapabilities(
      defaultRole: AppDeviceRole.androidRobot,
      allowedRoles: [AppDeviceRole.androidRobot],
    );
  }
}

class AppBuildCapabilities {
  const AppBuildCapabilities({
    required this.defaultRole,
    required this.allowedRoles,
  });

  final AppDeviceRole defaultRole;
  final List<AppDeviceRole> allowedRoles;

  // Compatibility getters describe the profile default. Role-aware callers
  // should use the `For` methods below.
  AppDeviceRole get fixedRole => defaultRole;
  bool get requiresSignIn => requiresSignInFor(defaultRole);
  bool get canHostRobot => canHostRobotFor(defaultRole);
  bool get showsRobotFace => showsRobotFaceFor(defaultRole);
  bool get showsRobotPhoneSetup => showsRobotPhoneSetupFor(defaultRole);

  bool allows(AppDeviceRole role) => allowedRoles.contains(role);
  bool requiresSignInFor(AppDeviceRole role) => !role.canHostRobot;
  bool canHostRobotFor(AppDeviceRole role) => allows(role) && role.canHostRobot;
  bool showsRobotFaceFor(AppDeviceRole role) => canHostRobotFor(role);
  bool showsRobotPhoneSetupFor(AppDeviceRole role) => canHostRobotFor(role);
}
