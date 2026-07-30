import 'package:dosey_app/core/cloud/cloud_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cloud configuration stays disabled when values are absent', () {
    final configuration = CloudConfiguration.fromValues();

    expect(configuration.isEnabled, isFalse);
    expect(configuration.endpoint, isNull);
    expect(configuration.projectId, isNull);
  });

  test('cloud configuration enables a complete Appwrite setup', () {
    final configuration = CloudConfiguration.fromValues(
      endpoint: 'https://nyc.cloud.appwrite.io/v1',
      projectId: 'dosey-development',
      createPairingCodeFunctionId: 'create-code',
      claimRobotFunctionId: 'claim-robot',
      createRobotFunctionId: 'create-robot',
      createHouseholdInvitationFunctionId: 'create-invitation',
      acceptHouseholdInvitationFunctionId: 'accept-invitation',
      removeHouseholdMemberFunctionId: 'remove-member',
    );

    expect(configuration.isEnabled, isTrue);
    expect(configuration.isPairingEnabled, isTrue);
    expect(configuration.endpoint, 'https://nyc.cloud.appwrite.io/v1');
    expect(configuration.projectId, 'dosey-development');
    expect(configuration.createPairingCodeFunctionId, 'create-code');
    expect(configuration.claimRobotFunctionId, 'claim-robot');
    expect(configuration.isHouseholdManagementEnabled, isTrue);
  });

  test(
    'identity stays enabled while incomplete pairing setup stays disabled',
    () {
      final configuration = CloudConfiguration.fromValues(
        endpoint: 'https://nyc.cloud.appwrite.io/v1',
        projectId: 'dosey-development',
        createPairingCodeFunctionId: 'create-code',
      );

      expect(configuration.isEnabled, isTrue);
      expect(configuration.isPairingEnabled, isFalse);
    },
  );

  test('incomplete household Function setup stays disabled', () {
    final configuration = CloudConfiguration.fromValues(
      endpoint: 'https://nyc.cloud.appwrite.io/v1',
      projectId: 'dosey-development',
      createRobotFunctionId: 'create-robot',
    );

    expect(configuration.isEnabled, isTrue);
    expect(configuration.isHouseholdManagementEnabled, isFalse);
  });

  test('caregiver sync defaults to disabled', () {
    final configuration = CloudConfiguration.fromValues(
      endpoint: 'https://nyc.cloud.appwrite.io/v1',
      projectId: 'dosey-development',
    );

    expect(configuration.caregiverSyncEnabled, isFalse);
    expect(configuration.isMedicationSyncEnabled, isFalse);
  });

  test('caregiver sync requires its flag and both Function IDs', () {
    final idsOnly = CloudConfiguration.fromValues(
      endpoint: 'https://nyc.cloud.appwrite.io/v1',
      projectId: 'dosey-development',
      medicationSyncPushFunctionId: 'medication-push',
      medicationSyncPullFunctionId: 'medication-pull',
    );
    final complete = CloudConfiguration.fromValues(
      endpoint: 'https://nyc.cloud.appwrite.io/v1',
      projectId: 'dosey-development',
      medicationSyncPushFunctionId: 'medication-push',
      medicationSyncPullFunctionId: 'medication-pull',
      caregiverSyncEnabled: true,
    );
    final partial = CloudConfiguration.fromValues(
      endpoint: 'https://nyc.cloud.appwrite.io/v1',
      projectId: 'dosey-development',
      medicationSyncPushFunctionId: 'medication-push',
      caregiverSyncEnabled: true,
    );

    expect(idsOnly.isMedicationSyncEnabled, isFalse);
    expect(complete.isMedicationSyncEnabled, isTrue);
    expect(complete.medicationSyncPullFunctionId, 'medication-pull');
    expect(partial.isMedicationSyncEnabled, isFalse);
  });

  test('cloud configuration rejects a partial Appwrite setup', () {
    expect(
      () => CloudConfiguration.fromValues(
        endpoint: 'https://nyc.cloud.appwrite.io/v1',
      ),
      throwsArgumentError,
    );
    expect(
      () => CloudConfiguration.fromValues(projectId: 'dosey-development'),
      throwsArgumentError,
    );
  });
}
