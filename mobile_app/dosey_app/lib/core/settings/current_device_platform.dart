import 'package:dosey_app/core/settings/device_role.dart';
import 'package:flutter/foundation.dart';

AppDevicePlatform currentAppDevicePlatform({
  bool? isWeb,
  TargetPlatform? platform,
}) {
  if (isWeb ?? kIsWeb) {
    return AppDevicePlatform.web;
  }

  return switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.iOS => AppDevicePlatform.ios,
    _ => AppDevicePlatform.android,
  };
}
