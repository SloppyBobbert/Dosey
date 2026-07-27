import 'package:dosey_app/core/cloud/appwrite_cloud_identity_gateway.dart';
import 'package:dosey_app/core/cloud/cloud_configuration.dart';
import 'package:dosey_app/core/cloud/cloud_gateway_factory.dart';
import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';
import 'package:dosey_app/core/household/appwrite_household_sync_gateway.dart';
import 'package:dosey_app/core/household/appwrite_household_management_gateway.dart';
import 'package:dosey_app/core/household/household_management_gateway.dart';
import 'package:dosey_app/core/household/household_sync_gateway.dart';
import 'package:dosey_app/core/household/appwrite_robot_pairing_gateway.dart';
import 'package:dosey_app/core/household/robot_pairing_gateway.dart';
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
    expect(
      gateways.householdManagement,
      isA<DisabledHouseholdManagementGateway>(),
    );
    expect(gateways.pairing, isA<DisabledRobotPairingGateway>());
  });

  test('web identity factory uses only the injected account API', () {
    final configuration = CloudConfiguration.fromValues(
      endpoint: 'https://example.appwrite.io/v1',
      projectId: 'dosey-development',
    );
    var factoryCalls = 0;

    final gateway = createWebCloudIdentityGateway(
      configuration,
      accountApiFactory: (receivedConfiguration) {
        factoryCalls += 1;
        expect(identical(receivedConfiguration, configuration), isTrue);
        return _UnusedAccountApi();
      },
    );

    expect(gateway, isA<AppwriteCloudIdentityGateway>());
    expect(factoryCalls, 1);
  });

  test('web identity factory disables identity without configuration', () {
    final gateway = createWebCloudIdentityGateway(
      CloudConfiguration.fromValues(),
    );

    expect(gateway, isA<DisabledCloudIdentityGateway>());
  });

  test('uses Appwrite adapter with complete cloud configuration', () {
    final configuration = CloudConfiguration.fromValues(
      endpoint: 'https://example.appwrite.io/v1',
      projectId: 'dosey-development',
      createPairingCodeFunctionId: 'create-code',
      claimRobotFunctionId: 'claim-robot',
      createRobotFunctionId: 'create-robot',
      createHouseholdInvitationFunctionId: 'create-invitation',
      acceptHouseholdInvitationFunctionId: 'accept-invitation',
      removeHouseholdMemberFunctionId: 'remove-member',
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
      pairingApiFactory: (_) => _UnusedPairingApi(),
      householdFunctionsApiFactory: (_) => _UnusedHouseholdFunctionsApi(),
    );

    expect(gateways.identity, isA<AppwriteCloudIdentityGateway>());
    expect(gateways.household, isA<AppwriteHouseholdSyncGateway>());
    expect(gateways.pairing, isA<AppwriteRobotPairingGateway>());
    expect(
      gateways.householdManagement,
      isA<AppwriteHouseholdManagementGateway>(),
    );
    expect(factoryCalls, 1);
  });
}

class _UnusedHouseholdFunctionsApi implements AppwriteHouseholdFunctionsApi {
  @override
  Future<HouseholdFunctionResponse> execute({
    required String functionId,
    required String body,
  }) => throw UnimplementedError();
}

class _UnusedPairingApi implements AppwriteRobotPairingApi {
  @override
  Future<void> ensureAnonymousSession() => throw UnimplementedError();

  @override
  Future<PairingFunctionResponse> execute({
    required String functionId,
    required String body,
  }) => throw UnimplementedError();
}

class _UnusedTeamsApi implements AppwriteTeamsApi {
  @override
  Future<List<RobotInstallation>> listRobotTeams() =>
      throw UnimplementedError();
}

class _UnusedAccountApi implements AppwriteAccountApi {
  @override
  Future<CloudIdentity?> getCurrentIdentity() => throw UnimplementedError();

  @override
  Future<void> signInWithGoogle({
    required List<String> scopes,
    String? successUrl,
    String? failureUrl,
  }) => throw UnimplementedError();

  @override
  Future<String> requestEmailOtp(String email) => throw UnimplementedError();

  @override
  Future<void> completeEmailOtp({
    required String userId,
    required String secret,
  }) => throw UnimplementedError();

  @override
  Future<void> signOutCurrentSession() => throw UnimplementedError();
}
