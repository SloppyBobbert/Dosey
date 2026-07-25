enum AppPermission {
  bluetooth,
  bluetoothScan,
  bluetoothConnect,
  locationWhenInUse,
  notifications,
}

enum AppPermissionState { unknown, granted, denied }

abstract interface class AppPermissionGateway {
  Future<AppPermissionState> check(AppPermission permission);

  Future<AppPermissionState> request(AppPermission permission);
}
