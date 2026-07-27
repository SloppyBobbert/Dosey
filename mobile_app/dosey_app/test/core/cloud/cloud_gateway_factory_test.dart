import 'package:dosey_app/core/cloud/appwrite_cloud_identity_gateway.dart';
import 'package:dosey_app/core/cloud/cloud_configuration.dart';
import 'package:dosey_app/core/cloud/cloud_gateway_factory.dart';
import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';
import 'package:dosey_app/core/household/appwrite_household_sync_gateway.dart';
import 'package:dosey_app/core/household/household_sync_gateway.dart';
import 'package:dosey_app/core/household/robot_installation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses disabled identity gateway without cloud configuration', () {
    final gateways = createCloudGateways(
      CloudConfiguration.fromValues(),
      accountApiFactory: (_) => _UnusedAccountApi(),
      teamsApiFactory: (_) => _UnusedTeamsApi(),
    );

    expect(gateways.identity, isA<DisabledCloudIdentityGateway>());
    expect(gateways.household, isA<DisabledHouseholdSyncGateway>());
  });

  test('uses Appwrite adapter with complete cloud configuration', () {
    final configuration = CloudConfiguration.fromValues(
      endpoint: 'https://example.appwrite.io/v1',
      projectId: 'dosey-development',
    );
    var factoryCalls = 0;

    final gateways = createCloudGateways(
      configuration,
      accountApiFactory: (receivedConfiguration) {
        factoryCalls += 1;
        expect(identical(receivedConfiguration, configuration), isTrue);
        return _UnusedAccountApi();
      },
      teamsApiFactory: (_) => _UnusedTeamsApi(),
    );

    expect(gateways.identity, isA<AppwriteCloudIdentityGateway>());
    expect(gateways.household, isA<AppwriteHouseholdSyncGateway>());
    expect(factoryCalls, 1);
  });
}

class _UnusedTeamsApi implements AppwriteTeamsApi {
  @override
  Future<RobotInstallation> createRobotTeam({
    required String displayName,
    required String ownerAccountId,
    required String mountedDeviceId,
  }) => throw UnimplementedError();

  @override
  Future<List<RobotInstallation>> listRobotTeams() =>
      throw UnimplementedError();
}

class _UnusedAccountApi implements AppwriteAccountApi {
  @override
  Future<CloudIdentity?> getCurrentIdentity() => throw UnimplementedError();

  @override
  Future<void> signInWithGoogle({required List<String> scopes}) =>
      throw UnimplementedError();

  @override
  Future<void> signOutCurrentSession() => throw UnimplementedError();
}
