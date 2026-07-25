import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHandlerGateway implements AppPermissionGateway {
  PermissionHandlerGateway({PermissionHandlerPlugin? plugin})
    : _plugin = plugin ?? PermissionHandlerPluginAdapter();

  final PermissionHandlerPlugin _plugin;

  @override
  Future<AppPermissionState> check(AppPermission permission) async {
    return _mapStatus(await _plugin.check(_mapPermission(permission)));
  }

  @override
  Future<AppPermissionState> request(AppPermission permission) async {
    return _mapStatus(await _plugin.request(_mapPermission(permission)));
  }

  static PluginPermission _mapPermission(AppPermission permission) {
    return switch (permission) {
      AppPermission.bluetooth => PluginPermission.bluetooth,
      AppPermission.bluetoothScan => PluginPermission.bluetoothScan,
      AppPermission.bluetoothConnect => PluginPermission.bluetoothConnect,
      AppPermission.locationWhenInUse => PluginPermission.locationWhenInUse,
      AppPermission.notifications => PluginPermission.notification,
    };
  }

  static AppPermissionState _mapStatus(PluginPermissionStatus status) {
    return switch (status) {
      // Limited/provisional access is enough for the prototype features we gate.
      PluginPermissionStatus.granted ||
      PluginPermissionStatus.limited ||
      PluginPermissionStatus.provisional => AppPermissionState.granted,
      PluginPermissionStatus.denied ||
      PluginPermissionStatus.permanentlyDenied ||
      PluginPermissionStatus.restricted => AppPermissionState.denied,
    };
  }
}

enum PluginPermission {
  bluetooth,
  bluetoothScan,
  bluetoothConnect,
  locationWhenInUse,
  notification,
}

enum PluginPermissionStatus {
  denied,
  granted,
  restricted,
  permanentlyDenied,
  limited,
  provisional,
}

abstract interface class PermissionHandlerPlugin {
  Future<PluginPermissionStatus> check(PluginPermission permission);

  Future<PluginPermissionStatus> request(PluginPermission permission);
}

class PermissionHandlerPluginAdapter implements PermissionHandlerPlugin {
  @override
  Future<PluginPermissionStatus> check(PluginPermission permission) async {
    return _mapStatus(await _mapPermission(permission).status);
  }

  @override
  Future<PluginPermissionStatus> request(PluginPermission permission) async {
    return _mapStatus(await _mapPermission(permission).request());
  }

  static Permission _mapPermission(PluginPermission permission) {
    return switch (permission) {
      PluginPermission.bluetooth => Permission.bluetooth,
      PluginPermission.bluetoothScan => Permission.bluetoothScan,
      PluginPermission.bluetoothConnect => Permission.bluetoothConnect,
      PluginPermission.locationWhenInUse => Permission.locationWhenInUse,
      PluginPermission.notification => Permission.notification,
    };
  }

  static PluginPermissionStatus _mapStatus(PermissionStatus status) {
    return switch (status) {
      PermissionStatus.denied => PluginPermissionStatus.denied,
      PermissionStatus.granted => PluginPermissionStatus.granted,
      PermissionStatus.restricted => PluginPermissionStatus.restricted,
      PermissionStatus.permanentlyDenied =>
        PluginPermissionStatus.permanentlyDenied,
      PermissionStatus.limited => PluginPermissionStatus.limited,
      PermissionStatus.provisional => PluginPermissionStatus.provisional,
    };
  }
}
