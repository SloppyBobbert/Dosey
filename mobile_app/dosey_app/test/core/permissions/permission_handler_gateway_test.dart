import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/permissions/permission_handler_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'app permissions clearly cover bluetooth scan connect and notifications',
    () {
      expect(AppPermission.values, [
        AppPermission.bluetooth,
        AppPermission.bluetoothScan,
        AppPermission.bluetoothConnect,
        AppPermission.locationWhenInUse,
        AppPermission.notifications,
      ]);
    },
  );

  test(
    'permission handler wrapper maps app-owned permissions and statuses',
    () async {
      final plugin = _FakePermissionHandlerPlugin(
        checkResponses: {
          PluginPermission.bluetooth: PluginPermissionStatus.granted,
          PluginPermission.bluetoothScan: PluginPermissionStatus.granted,
          PluginPermission.bluetoothConnect: PluginPermissionStatus.denied,
          PluginPermission.locationWhenInUse: PluginPermissionStatus.granted,
          PluginPermission.notification: PluginPermissionStatus.provisional,
        },
        requestResponses: {
          PluginPermission.bluetoothConnect: PluginPermissionStatus.granted,
          PluginPermission.notification:
              PluginPermissionStatus.permanentlyDenied,
        },
      );
      final gateway = PermissionHandlerGateway(plugin: plugin);

      expect(
        await gateway.check(AppPermission.bluetooth),
        AppPermissionState.granted,
      );
      expect(
        await gateway.check(AppPermission.bluetoothScan),
        AppPermissionState.granted,
      );
      expect(
        await gateway.check(AppPermission.bluetoothConnect),
        AppPermissionState.denied,
      );
      expect(
        await gateway.check(AppPermission.locationWhenInUse),
        AppPermissionState.granted,
      );
      expect(
        await gateway.check(AppPermission.notifications),
        AppPermissionState.granted,
      );

      expect(
        await gateway.request(AppPermission.bluetoothConnect),
        AppPermissionState.granted,
      );
      expect(
        await gateway.request(AppPermission.notifications),
        AppPermissionState.denied,
      );

      expect(plugin.checkedPermissions, [
        PluginPermission.bluetooth,
        PluginPermission.bluetoothScan,
        PluginPermission.bluetoothConnect,
        PluginPermission.locationWhenInUse,
        PluginPermission.notification,
      ]);
      expect(plugin.requestedPermissions, [
        PluginPermission.bluetoothConnect,
        PluginPermission.notification,
      ]);
    },
  );
}

class _FakePermissionHandlerPlugin implements PermissionHandlerPlugin {
  _FakePermissionHandlerPlugin({
    required this.checkResponses,
    required this.requestResponses,
  });

  final Map<PluginPermission, PluginPermissionStatus> checkResponses;
  final Map<PluginPermission, PluginPermissionStatus> requestResponses;
  final List<PluginPermission> checkedPermissions = [];
  final List<PluginPermission> requestedPermissions = [];

  @override
  Future<PluginPermissionStatus> check(PluginPermission permission) async {
    checkedPermissions.add(permission);
    return checkResponses[permission] ?? PluginPermissionStatus.denied;
  }

  @override
  Future<PluginPermissionStatus> request(PluginPermission permission) async {
    requestedPermissions.add(permission);
    return requestResponses[permission] ?? PluginPermissionStatus.denied;
  }
}
