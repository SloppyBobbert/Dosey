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

    expect(personal.fixedRole, AppDeviceRole.androidPersonal);
    expect(personal.requiresSignIn, isTrue);
    expect(personal.canHostRobot, isFalse);
    expect(personal.showsRobotFace, isFalse);
    expect(personal.showsRobotPhoneSetup, isFalse);

    expect(robot.fixedRole, AppDeviceRole.androidRobot);
    expect(robot.requiresSignIn, isFalse);
    expect(robot.canHostRobot, isTrue);
    expect(robot.showsRobotFace, isTrue);
    expect(robot.showsRobotPhoneSetup, isTrue);

    expect(iosRobotDefine.fixedRole, AppDeviceRole.iosPersonal);
    expect(iosRobotDefine.requiresSignIn, isTrue);
    expect(iosRobotDefine.canHostRobot, isFalse);
  });
}
