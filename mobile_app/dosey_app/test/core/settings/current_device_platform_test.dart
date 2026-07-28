import 'package:dosey_app/core/settings/current_device_platform.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web detection wins over the supplied target platform', () {
    expect(
      currentAppDevicePlatform(isWeb: true, platform: TargetPlatform.android),
      AppDevicePlatform.web,
    );
    expect(
      currentAppDevicePlatform(isWeb: true, platform: TargetPlatform.iOS),
      AppDevicePlatform.web,
    );
  });

  test('injected platform preserves Android and iOS behavior', () {
    expect(
      currentAppDevicePlatform(isWeb: false, platform: TargetPlatform.android),
      AppDevicePlatform.android,
    );
    expect(
      currentAppDevicePlatform(isWeb: false, platform: TargetPlatform.iOS),
      AppDevicePlatform.ios,
    );
  });
}
