import 'package:dosey_app/core/display/screen_awake_gateway.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.sloppybobbert.dosey_app/screen_awake');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('method channel forwards enabled state', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    const gateway = MethodChannelScreenAwakeGateway();

    await gateway.setKeepScreenAwake(true);
    await gateway.setKeepScreenAwake(false);

    expect(calls.map((call) => call.method), [
      'setKeepScreenAwake',
      'setKeepScreenAwake',
    ]);
    expect(calls.map((call) => call.arguments), [
      <String, Object>{'enabled': true},
      <String, Object>{'enabled': false},
    ]);
  });
}
