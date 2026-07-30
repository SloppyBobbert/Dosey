import 'package:dosey_app/core/build/app_build_profile.dart';
import 'package:dosey_app/core/settings/device_role.dart';

enum RuntimeCapability {
  phoneOnly('phone-only', 'phone_only'),
  hardwareAssisted('hardware-assisted', 'hardware_assisted');

  const RuntimeCapability(this.configuredValue, this.storageValue);

  static const configuredEnvironmentValue = String.fromEnvironment(
    'DOSEY_RUNTIME_CAPABILITY',
  );

  final String configuredValue;
  final String storageValue;

  static RuntimeCapability fromConfiguredValue(String value) {
    for (final capability in values) {
      if (capability.configuredValue == value) return capability;
    }
    throw FormatException('Unsupported runtime capability: "$value".');
  }

  static RuntimeCapability fromStorageValue(String value) {
    for (final capability in values) {
      if (capability.storageValue == value) return capability;
    }
    throw FormatException(
      'Unsupported persisted runtime capability: "$value".',
    );
  }

  static RuntimeCapability resolve({
    required String configuredValue,
    required AppBuildProfile buildProfile,
    required AppDevicePlatform platform,
  }) {
    if (configuredValue.isEmpty) {
      if (platform == AppDevicePlatform.android) {
        throw StateError('Android builds require DOSEY_RUNTIME_CAPABILITY.');
      }
      return hardwareAssisted;
    }

    final capability = fromConfiguredValue(configuredValue);
    if (capability == phoneOnly && platform != AppDevicePlatform.android) {
      throw StateError('phone-only is valid only for Android builds.');
    }
    return capability;
  }
}
