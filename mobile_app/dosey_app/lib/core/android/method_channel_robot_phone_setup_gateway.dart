import 'package:dosey_app/core/android/robot_phone_setup_gateway.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MethodChannelRobotPhoneSetupGateway implements RobotPhoneSetupGateway {
  MethodChannelRobotPhoneSetupGateway({
    required this.permissions,
    bool? isAndroid,
    this._channel = const MethodChannel(
      'com.sloppybobbert.dosey_app/robot_phone_setup',
    ),
  }) : _isAndroid =
           isAndroid ?? defaultTargetPlatform == TargetPlatform.android;

  final AppPermissionGateway permissions;
  final bool _isAndroid;
  final MethodChannel _channel;

  @override
  Future<Map<RobotPhoneSetupItem, SetupReadiness>> readStatus() async {
    if (!_isAndroid) return _unsupportedStatus;
    final raw = await _channel.invokeMapMethod<String, String>('getStatus');
    final result = <RobotPhoneSetupItem, SetupReadiness>{};
    for (final item in RobotPhoneSetupItem.values) {
      result[item] = _decodeReadiness(raw?[item.name]);
    }
    final bluetoothPermission = await permissions.check(
      AppPermission.bluetoothConnect,
    );
    if (bluetoothPermission != AppPermissionState.granted) {
      result[RobotPhoneSetupItem.bluetooth] = SetupReadiness.permissionRequired;
    }
    return result;
  }

  @override
  Future<SetupActionResult> open(RobotPhoneSetupAction action) async {
    if (!_isAndroid) return SetupActionResult.unsupported;
    final opened = await _channel.invokeMethod<bool>(_actionMethods[action]!);
    return opened == true
        ? SetupActionResult.opened
        : SetupActionResult.unsupported;
  }

  static final _unsupportedStatus = {
    for (final item in RobotPhoneSetupItem.values)
      item: SetupReadiness.unsupported,
  };

  static const _actionMethods = {
    RobotPhoneSetupAction.bluetoothSettings: 'openBluetoothSettings',
    RobotPhoneSetupAction.wifiSettings: 'openWifiSettings',
    RobotPhoneSetupAction.notificationSettings: 'openNotificationSettings',
    RobotPhoneSetupAction.batteryOptimizationSettings:
        'openBatteryOptimizationSettings',
    RobotPhoneSetupAction.securitySettings: 'openSecuritySettings',
    RobotPhoneSetupAction.appDetails: 'openAppDetails',
  };

  SetupReadiness _decodeReadiness(String? value) {
    return SetupReadiness.values.firstWhere(
      (readiness) => readiness.name == value,
      orElse: () => SetupReadiness.unsupported,
    );
  }
}
