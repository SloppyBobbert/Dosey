import 'package:dosey_app/core/settings/device_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('android can be robot phone or personal phone', () {
    expect(
      AppDeviceRole.allowedFor(AppDevicePlatform.android),
      containsAll([AppDeviceRole.androidRobot, AppDeviceRole.androidPersonal]),
    );
  });

  test('ios is personal phone only', () {
    expect(AppDeviceRole.allowedFor(AppDevicePlatform.ios), [
      AppDeviceRole.iosPersonal,
    ]);
    expect(
      AppDeviceRole.androidRobot.isAllowedOn(AppDevicePlatform.ios),
      isFalse,
    );
  });

  test('web is personal phone only and cannot use a restored robot role', () {
    expect(AppDeviceRole.allowedFor(AppDevicePlatform.web), [
      AppDeviceRole.webPersonal,
    ]);
    expect(
      AppDeviceRole.defaultFor(AppDevicePlatform.web),
      AppDeviceRole.webPersonal,
    );
    expect(
      AppDeviceRole.fromStorageValue(
        'android_robot',
      )!.isAllowedOn(AppDevicePlatform.web),
      isFalse,
    );
  });

  test('default role follows the device platform', () {
    expect(
      AppDeviceRole.defaultFor(AppDevicePlatform.android),
      AppDeviceRole.androidPersonal,
    );
    expect(
      AppDeviceRole.defaultFor(AppDevicePlatform.ios),
      AppDeviceRole.iosPersonal,
    );
  });

  test('robot controls only unlock for android robot mode', () {
    expect(AppDeviceRole.androidRobot.canHostRobot, isTrue);
    expect(AppDeviceRole.androidPersonal.canHostRobot, isFalse);
    expect(AppDeviceRole.iosPersonal.canHostRobot, isFalse);
    expect(AppDeviceRole.webPersonal.canHostRobot, isFalse);
  });
}
