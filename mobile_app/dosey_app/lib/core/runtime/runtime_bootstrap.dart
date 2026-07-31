import 'package:dosey_app/core/runtime/runtime_capability.dart';

abstract final class RuntimeBootstrap {
  static bool shouldCreateCloudGateways(RuntimeCapability capability) {
    return capability == RuntimeCapability.hardwareAssisted;
  }
}
