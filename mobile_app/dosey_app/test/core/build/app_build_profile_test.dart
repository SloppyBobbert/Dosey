import 'package:dosey_app/core/build/app_build_profile.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('personal is the safe default for missing and unknown values', () {
    expect(AppBuildProfile.fromValue(null), AppBuildProfile.personal);
    expect(AppBuildProfile.fromValue('unknown'), AppBuildProfile.personal);
  });

  test('robot must be selected explicitly', () {
    expect(AppBuildProfile.fromValue('robot'), AppBuildProfile.robot);
    expect(AppBuildProfile.fromValue('personal'), AppBuildProfile.personal);
  });

  test('capabilities resolve by profile and platform', () {
    final personal = AppBuildProfile.personal.resolve(
      AppDevicePlatform.android,
    );
    final robot = AppBuildProfile.robot.resolve(AppDevicePlatform.android);
    final iosRobotDefine = AppBuildProfile.robot.resolve(AppDevicePlatform.ios);

    expect(personal.defaultRole, AppDeviceRole.androidPersonal);
    expect(
      personal.allowedRoles,
      containsAll([AppDeviceRole.androidPersonal, AppDeviceRole.androidRobot]),
    );
    expect(personal.requiresSignInFor(AppDeviceRole.androidPersonal), isTrue);
    expect(personal.canHostRobotFor(AppDeviceRole.androidRobot), isTrue);
    expect(personal.showsRobotFaceFor(AppDeviceRole.androidRobot), isTrue);

    expect(robot.defaultRole, AppDeviceRole.androidRobot);
    expect(robot.allowedRoles, [AppDeviceRole.androidRobot]);
    expect(robot.requiresSignInFor(AppDeviceRole.androidRobot), isFalse);
    expect(robot.canHostRobotFor(AppDeviceRole.androidRobot), isTrue);
    expect(robot.showsRobotFaceFor(AppDeviceRole.androidRobot), isTrue);
    expect(robot.showsRobotPhoneSetupFor(AppDeviceRole.androidRobot), isTrue);

    expect(iosRobotDefine.defaultRole, AppDeviceRole.iosPersonal);
    expect(iosRobotDefine.allowedRoles, [AppDeviceRole.iosPersonal]);
    expect(iosRobotDefine.requiresSignInFor(AppDeviceRole.iosPersonal), isTrue);
    expect(iosRobotDefine.canHostRobotFor(AppDeviceRole.iosPersonal), isFalse);
  });
}
