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
    expect(configuration.isPersonalPairingEnabled, isTrue);
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
      expect(configuration.isPersonalPairingEnabled, isFalse);
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

  test('mounted robot access requires its dedicated Function ID', () {
    final incomplete = CloudConfiguration.fromValues(
      endpoint: 'https://nyc.cloud.appwrite.io/v1',
      projectId: 'dosey-development',
    );
    expect(incomplete.isMountedRobotAccessEnabled, isFalse);

    final complete = CloudConfiguration.fromValues(
      endpoint: 'https://nyc.cloud.appwrite.io/v1',
      projectId: 'dosey-development',
      getMountedRobotFunctionId: 'get-mounted-robot',
    );
    expect(complete.isMountedRobotAccessEnabled, isTrue);
    expect(complete.getMountedRobotFunctionId, 'get-mounted-robot');
  });

  test('splits Personal pairing and Robot claim predicates', () {
    final personal = CloudConfiguration.fromValues(
      endpoint: 'https://cloud.example/v1',
      projectId: 'project',
      createPairingCodeFunctionId: 'create-code',
      claimRobotFunctionId: 'claim-robot',
    );
    expect(personal.isPersonalPairingEnabled, isTrue);
    expect(personal.isRobotClaimEnabled, isFalse);

    final robot = CloudConfiguration.fromValues(
      endpoint: 'https://cloud.example/v1',
      projectId: 'project',
      claimRobotFunctionId: 'claim-robot',
      getMountedRobotFunctionId: 'get-mounted-robot',
    );
    expect(robot.isPersonalPairingEnabled, isFalse);
    expect(robot.isRobotClaimEnabled, isTrue);
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
