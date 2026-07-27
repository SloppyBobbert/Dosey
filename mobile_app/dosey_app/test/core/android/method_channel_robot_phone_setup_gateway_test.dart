import 'package:dosey_app/core/android/method_channel_robot_phone_setup_gateway.dart';
import 'package:dosey_app/core/android/robot_phone_setup_gateway.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(
    'com.sloppybobbert.dosey_app/robot_phone_setup',
  );

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('decodes statuses and ignores unknown keys', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getStatus');
          return <String, String>{
            'bluetooth': 'actionRequired',
            'wifi': 'ready',
            'notifications': 'unsupported',
            'batteryOptimization': 'actionRequired',
            'secureLock': 'ready',
            'futureStatus': 'ready',
          };
        });
    final gateway = MethodChannelRobotPhoneSetupGateway(
      permissions: const _PermissionGateway(AppPermissionState.granted),
      isAndroid: true,
    );

    final status = await gateway.readStatus();

    expect(
      status[RobotPhoneSetupItem.bluetooth],
      SetupReadiness.actionRequired,
    );
    expect(status[RobotPhoneSetupItem.wifi], SetupReadiness.ready);
    expect(
      status[RobotPhoneSetupItem.notifications],
      SetupReadiness.unsupported,
    );
  });

  test('reports Bluetooth permission separately from adapter state', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => <String, String>{'bluetooth': 'actionRequired'},
        );
    final gateway = MethodChannelRobotPhoneSetupGateway(
      permissions: const _PermissionGateway(AppPermissionState.denied),
      isAndroid: true,
    );

    final status = await gateway.readStatus();

    expect(
      status[RobotPhoneSetupItem.bluetooth],
      SetupReadiness.permissionRequired,
    );
  });

  test('invokes every setup action', () async {
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          return true;
        });
    final gateway = MethodChannelRobotPhoneSetupGateway(
      permissions: const _PermissionGateway(AppPermissionState.granted),
      isAndroid: true,
    );

    for (final action in RobotPhoneSetupAction.values) {
      expect(await gateway.open(action), SetupActionResult.opened);
    }

    expect(methods, [
      'openBluetoothSettings',
      'openWifiSettings',
      'openNotificationSettings',
      'openBatteryOptimizationSettings',
      'openSecuritySettings',
      'openAppDetails',
    ]);
  });

  test('is unsupported outside Android without invoking the channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw StateError('Channel invoked outside Android: ${call.method}');
        });
    final gateway = MethodChannelRobotPhoneSetupGateway(
      permissions: const _PermissionGateway(AppPermissionState.granted),
      isAndroid: false,
    );

    expect(
      (await gateway.readStatus()).values,
      everyElement(SetupReadiness.unsupported),
    );
    expect(
      await gateway.open(RobotPhoneSetupAction.appDetails),
      SetupActionResult.unsupported,
    );
  });
}

class _PermissionGateway implements AppPermissionGateway {
  const _PermissionGateway(this.state);

  final AppPermissionState state;

  @override
  Future<AppPermissionState> check(AppPermission permission) async => state;

  @override
  Future<AppPermissionState> request(AppPermission permission) async => state;
}
