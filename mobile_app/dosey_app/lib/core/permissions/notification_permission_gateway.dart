import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/permissions/permission_handler_gateway.dart';

abstract interface class NotificationPermissionGateway {
  Future<AppPermissionState> check();

  Future<AppPermissionState> request();
}

class PermissionHandlerNotificationPermissionGateway
    implements NotificationPermissionGateway {
  PermissionHandlerNotificationPermissionGateway({
    PermissionHandlerPlugin? plugin,
  }) : _plugin = plugin ?? PermissionHandlerPluginAdapter();

  final PermissionHandlerPlugin _plugin;

  @override
  Future<AppPermissionState> check() async =>
      _mapStatus(await _plugin.check(PluginPermission.notification));

  @override
  Future<AppPermissionState> request() async =>
      _mapStatus(await _plugin.request(PluginPermission.notification));

  static AppPermissionState _mapStatus(PluginPermissionStatus status) {
    return switch (status) {
      PluginPermissionStatus.granted ||
      PluginPermissionStatus.limited ||
      PluginPermissionStatus.provisional => AppPermissionState.granted,
      PluginPermissionStatus.denied ||
      PluginPermissionStatus.permanentlyDenied ||
      PluginPermissionStatus.restricted => AppPermissionState.denied,
    };
  }
}
