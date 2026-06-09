import 'package:dosey_app/core/settings/device_role.dart';
import 'package:flutter/foundation.dart';

AppDevicePlatform currentAppDevicePlatform({TargetPlatform? platform}) {
  return switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.iOS => AppDevicePlatform.ios,
    _ => AppDevicePlatform.android,
  };
}
