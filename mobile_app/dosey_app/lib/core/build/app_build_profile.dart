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
    if (platform == AppDevicePlatform.ios || this == personal) {
      return AppBuildCapabilities(
        fixedRole: platform == AppDevicePlatform.ios
            ? AppDeviceRole.iosPersonal
            : AppDeviceRole.androidPersonal,
        requiresSignIn: true,
        canHostRobot: false,
        showsRobotFace: false,
        showsRobotPhoneSetup: false,
      );
    }
    return const AppBuildCapabilities(
      fixedRole: AppDeviceRole.androidRobot,
      requiresSignIn: false,
      canHostRobot: true,
      showsRobotFace: true,
      showsRobotPhoneSetup: true,
    );
  }
}

class AppBuildCapabilities {
  const AppBuildCapabilities({
    required this.fixedRole,
    required this.requiresSignIn,
    required this.canHostRobot,
    required this.showsRobotFace,
    required this.showsRobotPhoneSetup,
  });

  final AppDeviceRole fixedRole;
  final bool requiresSignIn;
  final bool canHostRobot;
  final bool showsRobotFace;
  final bool showsRobotPhoneSetup;
}
