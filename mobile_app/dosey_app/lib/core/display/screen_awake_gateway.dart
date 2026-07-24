import 'package:flutter/services.dart';

abstract interface class ScreenAwakeGateway {
  Future<void> setKeepScreenAwake(bool enabled);
}

class MethodChannelScreenAwakeGateway implements ScreenAwakeGateway {
  const MethodChannelScreenAwakeGateway();

  static const _channel = MethodChannel(
    'com.sloppybobbert.dosey_app/screen_awake',
  );

  @override
  Future<void> setKeepScreenAwake(bool enabled) {
    return _channel.invokeMethod<void>('setKeepScreenAwake', <String, Object>{
      'enabled': enabled,
    });
  }
}
