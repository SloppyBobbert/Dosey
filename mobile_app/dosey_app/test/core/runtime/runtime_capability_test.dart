import 'package:dosey_app/core/build/app_build_profile.dart';
import 'package:dosey_app/core/runtime/runtime_capability.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuntimeCapability', () {
    test('parses the two supported configured values', () {
      expect(
        RuntimeCapability.fromConfiguredValue('phone-only'),
        RuntimeCapability.phoneOnly,
      );
      expect(
        RuntimeCapability.fromConfiguredValue('hardware-assisted'),
        RuntimeCapability.hardwareAssisted,
      );
    });

    test('rejects missing and unknown configured values', () {
      expect(
        () => RuntimeCapability.fromConfiguredValue(''),
        throwsFormatException,
      );
      expect(
        () => RuntimeCapability.fromConfiguredValue('simulated'),
        throwsFormatException,
      );
    });

    test('requires an explicit capability for every Android build', () {
      expect(
        () => RuntimeCapability.resolve(
          configuredValue: '',
          buildProfile: AppBuildProfile.personal,
          platform: AppDevicePlatform.android,
        ),
        throwsStateError,
      );
    });

    test('defaults non-Android builds to hardware assisted compatibility', () {
      expect(
        RuntimeCapability.resolve(
          configuredValue: '',
          buildProfile: AppBuildProfile.personal,
          platform: AppDevicePlatform.ios,
        ),
        RuntimeCapability.hardwareAssisted,
      );
    });

    test('rejects phone-only capability for the Android Personal profile', () {
      expect(
        RuntimeCapability.resolve(
          configuredValue: 'hardware-assisted',
          buildProfile: AppBuildProfile.personal,
          platform: AppDevicePlatform.android,
        ),
        RuntimeCapability.hardwareAssisted,
      );
      expect(
        () => RuntimeCapability.resolve(
          configuredValue: 'phone-only',
          buildProfile: AppBuildProfile.personal,
          platform: AppDevicePlatform.android,
        ),
        throwsStateError,
      );
    });

    test('accepts phone-only capability for the Android Robot profile', () {
      expect(
        RuntimeCapability.resolve(
          configuredValue: 'phone-only',
          buildProfile: AppBuildProfile.robot,
          platform: AppDevicePlatform.android,
        ),
        RuntimeCapability.phoneOnly,
      );
    });

    test(
      'rejects hardware-assisted capability for the Android Robot profile',
      () {
        expect(
          () => RuntimeCapability.resolve(
            configuredValue: 'hardware-assisted',
            buildProfile: AppBuildProfile.robot,
            platform: AppDevicePlatform.android,
          ),
          throwsStateError,
        );
      },
    );

    test('rejects phone-only outside Android', () {
      expect(
        () => RuntimeCapability.resolve(
          configuredValue: 'phone-only',
          buildProfile: AppBuildProfile.robot,
          platform: AppDevicePlatform.ios,
        ),
        throwsStateError,
      );
    });
  });
}
