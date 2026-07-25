import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:flutter/services.dart';

abstract interface class AndroidSdkGateway {
  Future<int> currentVersion();
}

class MethodChannelAndroidSdkGateway implements AndroidSdkGateway {
  const MethodChannelAndroidSdkGateway();

  static const _channel = MethodChannel(
    'com.sloppybobbert.dosey_app/android_platform',
  );

  @override
  Future<int> currentVersion() async {
    final version = await _channel.invokeMethod<int>('getSdkVersion');
    if (version == null) {
      throw StateError('Android SDK version was unavailable.');
    }
    return version;
  }
}

class BlePermissionPreparer {
  const BlePermissionPreparer({
    required this.permissions,
    required this.platform,
    required this.androidSdk,
  });

  final AppPermissionGateway permissions;
  final AppDevicePlatform platform;
  final AndroidSdkGateway androidSdk;

  Future<bool> prepare() async {
    final requiredPermissions = <AppPermission>[];
    if (platform == AppDevicePlatform.android) {
      requiredPermissions.addAll(const [
        AppPermission.bluetoothScan,
        AppPermission.bluetoothConnect,
      ]);
      if (await androidSdk.currentVersion() <= 30) {
        requiredPermissions.add(AppPermission.locationWhenInUse);
      }
    } else {
      requiredPermissions.add(AppPermission.bluetooth);
    }

    for (final permission in requiredPermissions) {
      var state = await permissions.check(permission);
      if (state != AppPermissionState.granted) {
        state = await permissions.request(permission);
      }
      if (state != AppPermissionState.granted) return false;
    }
    return true;
  }
}
