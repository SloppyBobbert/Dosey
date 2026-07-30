import 'package:dosey_app/core/runtime/runtime_bootstrap.dart';
import 'package:dosey_app/core/runtime/runtime_capability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phone-only bootstrap disables cloud construction', () {
    expect(
      RuntimeBootstrap.shouldCreateCloudGateways(RuntimeCapability.phoneOnly),
      isFalse,
    );
  });

  test('hardware-assisted bootstrap retains cloud construction', () {
    expect(
      RuntimeBootstrap.shouldCreateCloudGateways(
        RuntimeCapability.hardwareAssisted,
      ),
      isTrue,
    );
  });
}
