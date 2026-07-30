import 'package:dosey_app/core/cloud/appwrite_cloud_identity_gateway.dart';
import 'package:dosey_app/core/cloud/cloud_configuration.dart';
import 'package:dosey_app/core/cloud/cloud_gateway_factory.dart';
import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';
import 'package:dosey_app/core/caregiver/caregiver_snapshot.dart';
import 'package:dosey_app/core/caregiver/caregiver_snapshot_controller.dart';
import 'package:dosey_app/core/caregiver/appwrite_caregiver_sync_gateway.dart';
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

  test(
    'web gateway factory composes identity and household without pairing',
    () {
      final configuration = CloudConfiguration.fromValues(
        endpoint: 'https://example.appwrite.io/v1',
        projectId: 'dosey-development',
        createRobotFunctionId: 'create-robot',
        createHouseholdInvitationFunctionId: 'create-invitation',
        acceptHouseholdInvitationFunctionId: 'accept-invitation',
        removeHouseholdMemberFunctionId: 'remove-member',
      );

      final gateways = createWebCloudGateways(
        configuration,
        accountApiFactory: (_) => _UnusedAccountApi(),
        teamsApiFactory: (_) => _UnusedTeamsApi(),
        householdFunctionsApiFactory: (_) => _UnusedHouseholdFunctionsApi(),
      );

      expect(gateways.identity, isA<AppwriteCloudIdentityGateway>());
      expect(gateways.household, isA<AppwriteHouseholdSyncGateway>());
      expect(
        gateways.householdManagement,
        isA<AppwriteHouseholdManagementGateway>(),
      );
      expect(gateways.caregiver, isA<DisabledCaregiverSyncGateway>());
    },
  );

  test(
    'web gateway factory keeps caregiver sync disabled when IDs alone exist',
    () {
      final configured = CloudConfiguration.fromValues(
        endpoint: 'https://example.appwrite.io/v1',
        projectId: 'dosey-development',
        medicationSyncPushFunctionId: 'medication-sync-push',
        medicationSyncPullFunctionId: 'medication-sync-pull',
      );
      const caregiver = _UnusedCaregiverGateway();
      var calls = 0;

      final gateways = createWebCloudGateways(
        configured,
        accountApiFactory: (_) => _UnusedAccountApi(),
        teamsApiFactory: (_) => _UnusedTeamsApi(),
        caregiverGatewayFactory: (configuration) {
          calls += 1;
          expect(identical(configuration, configured), isTrue);
          return caregiver;
        },
      );

      expect(gateways.caregiver, isA<DisabledCaregiverSyncGateway>());
      expect(calls, 0);
    },
  );

  test(
    'web gateway factory builds medication sync only with its enabled flag',
    () {
      final configured = CloudConfiguration.fromValues(
        endpoint: 'https://example.appwrite.io/v1',
        projectId: 'dosey-development',
        medicationSyncPushFunctionId: 'medication-sync-push',
        medicationSyncPullFunctionId: 'medication-sync-pull',
        caregiverSyncEnabled: true,
      );
      var apiFactoryCalls = 0;

      final gateways = createWebCloudGateways(
        configured,
        accountApiFactory: (_) => _UnusedAccountApi(),
        teamsApiFactory: (_) => _UnusedTeamsApi(),
        medicationSyncFunctionsApiFactory: (_) {
          apiFactoryCalls += 1;
          return _UnusedMedicationSyncFunctionsApi();
        },
        webDeviceId: 'web-device',
        newSyncId: () => 'generated-id',
      );

      final caregiver = gateways.caregiver as AppwriteCaregiverSyncGateway;
      expect(caregiver.pushFunctionId, 'medication-sync-push');
      expect(caregiver.pullFunctionId, 'medication-sync-pull');
      expect(caregiver.deviceId, 'web-device');
      expect(apiFactoryCalls, 1);
    },
  );

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

class _UnusedMedicationSyncFunctionsApi
    implements AppwriteMedicationSyncFunctionsApi {
  @override
  Future<String> currentAccountId() => throw UnimplementedError();

  @override
  Future<MedicationSyncFunctionResponse> execute({
    required String functionId,
    required String body,
  }) => throw UnimplementedError();
}

class _UnusedCaregiverGateway implements CaregiverSyncGateway {
  const _UnusedCaregiverGateway();

  @override
  Future<CaregiverPullResult> pull(
    String robotId, {
    String? cursor,
    String? checkpoint,
    int limit = 100,
  }) => throw UnimplementedError();

  @override
  Future<void> push(String robotId, List<CaregiverMutation> operations) =>
      throw UnimplementedError();
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
