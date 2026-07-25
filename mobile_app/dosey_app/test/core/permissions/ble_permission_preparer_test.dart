import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/permissions/ble_permission_preparer.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android 30 requires location in addition to Bluetooth access',
    () async {
      final permissions = _RecordingPermissionGateway();
      final preparer = BlePermissionPreparer(
        permissions: permissions,
        platform: AppDevicePlatform.android,
        androidSdk: _FakeAndroidSdkGateway(30),
      );

      expect(await preparer.prepare(), isTrue);
      expect(permissions.checked, [
        AppPermission.bluetoothScan,
        AppPermission.bluetoothConnect,
        AppPermission.locationWhenInUse,
      ]);
    },
  );

  test('Android 31 does not request legacy location access', () async {
    final permissions = _RecordingPermissionGateway();
    final preparer = BlePermissionPreparer(
      permissions: permissions,
      platform: AppDevicePlatform.android,
      androidSdk: _FakeAndroidSdkGateway(31),
    );

    expect(await preparer.prepare(), isTrue);
    expect(permissions.checked, [
      AppPermission.bluetoothScan,
      AppPermission.bluetoothConnect,
    ]);
  });

  test(
    'iOS requests its Bluetooth permission without Android access',
    () async {
      final permissions = _RecordingPermissionGateway();
      final androidSdk = _FakeAndroidSdkGateway(30);
      final preparer = BlePermissionPreparer(
        permissions: permissions,
        platform: AppDevicePlatform.ios,
        androidSdk: androidSdk,
      );

      expect(await preparer.prepare(), isTrue);
      expect(androidSdk.calls, 0);
      expect(permissions.checked, [AppPermission.bluetooth]);
    },
  );

  test('denied legacy location access prevents Android 30 scanning', () async {
    final permissions = _RecordingPermissionGateway(
      states: {AppPermission.locationWhenInUse: AppPermissionState.denied},
    );
    final preparer = BlePermissionPreparer(
      permissions: permissions,
      platform: AppDevicePlatform.android,
      androidSdk: _FakeAndroidSdkGateway(30),
    );

    expect(await preparer.prepare(), isFalse);
    expect(permissions.requested, [AppPermission.locationWhenInUse]);
  });
}

class _FakeAndroidSdkGateway implements AndroidSdkGateway {
  _FakeAndroidSdkGateway(this.version);

  final int version;
  int calls = 0;

  @override
  Future<int> currentVersion() async {
    calls += 1;
    return version;
  }
}

class _RecordingPermissionGateway implements AppPermissionGateway {
  _RecordingPermissionGateway({this.states = const {}});

  final Map<AppPermission, AppPermissionState> states;
  final List<AppPermission> checked = [];
  final List<AppPermission> requested = [];

  @override
  Future<AppPermissionState> check(AppPermission permission) async {
    checked.add(permission);
    return states[permission] ?? AppPermissionState.granted;
  }

  @override
  Future<AppPermissionState> request(AppPermission permission) async {
    requested.add(permission);
    return states[permission] ?? AppPermissionState.granted;
  }
}
