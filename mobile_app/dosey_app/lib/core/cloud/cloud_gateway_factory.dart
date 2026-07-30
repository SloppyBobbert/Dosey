import 'package:appwrite/appwrite.dart';
import 'package:dosey_app/core/cloud/appwrite_cloud_identity_gateway.dart';
import 'package:dosey_app/core/cloud/cloud_configuration.dart';
import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';
import 'package:dosey_app/core/caregiver/caregiver_snapshot_controller.dart';
import 'package:dosey_app/core/caregiver/appwrite_caregiver_sync_gateway.dart';
import 'package:dosey_app/core/household/appwrite_household_sync_gateway.dart';
import 'package:dosey_app/core/household/appwrite_household_management_gateway.dart';
import 'package:dosey_app/core/household/appwrite_robot_pairing_gateway.dart';
import 'package:dosey_app/core/household/household_sync_gateway.dart';
import 'package:dosey_app/core/household/household_management_gateway.dart';
import 'package:dosey_app/core/household/robot_pairing_gateway.dart';

typedef AppwriteAccountApiFactory =
    AppwriteAccountApi Function(CloudConfiguration configuration);

CloudIdentityGateway createWebCloudIdentityGateway(
  CloudConfiguration configuration, {
  AppwriteAccountApiFactory? accountApiFactory,
}) {
  if (!configuration.isEnabled) {
    return const DisabledCloudIdentityGateway();
  }

  final accountApi = accountApiFactory != null
      ? accountApiFactory(configuration)
      : _createAppwriteAccountApi(configuration);
  return AppwriteCloudIdentityGateway(accountApi);
}

typedef AppwriteTeamsApiFactory =
    AppwriteTeamsApi Function(CloudConfiguration configuration);
typedef AppwritePairingApiFactory =
    AppwriteRobotPairingApi Function(CloudConfiguration configuration);
typedef AppwriteHouseholdFunctionsApiFactory =
    AppwriteHouseholdFunctionsApi Function(CloudConfiguration configuration);
typedef CaregiverSyncGatewayFactory =
    CaregiverSyncGateway Function(CloudConfiguration configuration);
typedef AppwriteMedicationSyncFunctionsApiFactory =
    AppwriteMedicationSyncFunctionsApi Function(
      CloudConfiguration configuration,
    );

class WebCloudGateways {
  const WebCloudGateways({
    required this.identity,
    required this.household,
    required this.householdManagement,
    required this.caregiver,
  });

  final CloudIdentityGateway identity;
  final HouseholdSyncGateway household;
  final HouseholdManagementGateway householdManagement;
  final CaregiverSyncGateway caregiver;
}

WebCloudGateways createWebCloudGateways(
  CloudConfiguration configuration, {
  AppwriteAccountApiFactory? accountApiFactory,
  AppwriteTeamsApiFactory? teamsApiFactory,
  AppwriteHouseholdFunctionsApiFactory? householdFunctionsApiFactory,
  CaregiverSyncGatewayFactory? caregiverGatewayFactory,
  AppwriteMedicationSyncFunctionsApiFactory? medicationSyncFunctionsApiFactory,
  String? webDeviceId,
  String Function()? newSyncId,
}) {
  if (!configuration.isEnabled) {
    return const WebCloudGateways(
      identity: DisabledCloudIdentityGateway(),
      household: DisabledHouseholdSyncGateway(),
      householdManagement: DisabledHouseholdManagementGateway(),
      caregiver: DisabledCaregiverSyncGateway(),
    );
  }

  if (accountApiFactory != null ||
      teamsApiFactory != null ||
      householdFunctionsApiFactory != null ||
      medicationSyncFunctionsApiFactory != null) {
    final accountApi = (accountApiFactory ?? _createAppwriteAccountApi)(
      configuration,
    );
    return WebCloudGateways(
      identity: AppwriteCloudIdentityGateway(accountApi),
      household: AppwriteHouseholdSyncGateway(
        (teamsApiFactory ?? _createAppwriteTeamsApi)(configuration),
      ),
      householdManagement: _createHouseholdManagementGateway(
        configuration,
        householdFunctionsApiFactory,
      ),
      caregiver: _createCaregiverGateway(
        configuration,
        gatewayFactory: caregiverGatewayFactory,
        apiFactory: medicationSyncFunctionsApiFactory,
        deviceId: webDeviceId,
        newId: newSyncId,
      ),
    );
  }

  final client = _createAppwriteClient(configuration);
  return WebCloudGateways(
    identity: AppwriteCloudIdentityGateway(
      AppwriteAccountApiAdapter(Account(client)),
    ),
    household: AppwriteHouseholdSyncGateway(
      AppwriteTeamsApiAdapter(Teams(client), Account(client)),
    ),
    householdManagement: configuration.isHouseholdManagementEnabled
        ? AppwriteHouseholdManagementGateway(
            AppwriteHouseholdFunctionsApiAdapter(Functions(client)),
            createRobotFunctionId: configuration.createRobotFunctionId!,
            createInvitationFunctionId:
                configuration.createHouseholdInvitationFunctionId!,
            acceptInvitationFunctionId:
                configuration.acceptHouseholdInvitationFunctionId!,
            removeMemberFunctionId:
                configuration.removeHouseholdMemberFunctionId!,
          )
        : const DisabledHouseholdManagementGateway(),
    caregiver: _createCaregiverGateway(
      configuration,
      gatewayFactory: caregiverGatewayFactory,
      api: AppwriteMedicationSyncFunctionsApiAdapter(
        Functions(client),
        Account(client),
      ),
      deviceId: webDeviceId,
      newId: newSyncId,
    ),
  );
}

class CloudGateways {
  const CloudGateways({
    required this.identity,
    required this.household,
    required this.householdManagement,
    required this.pairing,
  });

  final CloudIdentityGateway identity;
  final HouseholdSyncGateway household;
  final HouseholdManagementGateway householdManagement;
  final RobotPairingGateway pairing;
}

CloudGateways createCloudGateways(
  CloudConfiguration configuration, {
  AppwriteAccountApiFactory? accountApiFactory,
  AppwriteTeamsApiFactory? teamsApiFactory,
  AppwritePairingApiFactory? pairingApiFactory,
  AppwriteHouseholdFunctionsApiFactory? householdFunctionsApiFactory,
}) {
  if (!configuration.isEnabled) {
    return const CloudGateways(
      identity: DisabledCloudIdentityGateway(),
      household: DisabledHouseholdSyncGateway(),
      householdManagement: DisabledHouseholdManagementGateway(),
      pairing: DisabledRobotPairingGateway(),
    );
  }

  // Provider construction belongs here so the rest of app composition only
  // sees Dosey-owned contracts when Appwrite is replaced.
  if (accountApiFactory != null ||
      teamsApiFactory != null ||
      pairingApiFactory != null ||
      householdFunctionsApiFactory != null) {
    final accountApi = (accountApiFactory ?? _createAppwriteAccountApi)(
      configuration,
    );
    final teamsApi = (teamsApiFactory ?? _createAppwriteTeamsApi)(
      configuration,
    );
    final pairing = configuration.isPairingEnabled
        ? AppwriteRobotPairingGateway(
            (pairingApiFactory ?? _createAppwritePairingApi)(configuration),
            configuration.createPairingCodeFunctionId!,
            configuration.claimRobotFunctionId!,
          )
        : const DisabledRobotPairingGateway();
    return CloudGateways(
      identity: AppwriteCloudIdentityGateway(accountApi),
      household: AppwriteHouseholdSyncGateway(teamsApi),
      householdManagement: _createHouseholdManagementGateway(
        configuration,
        householdFunctionsApiFactory,
      ),
      pairing: pairing,
    );
  }

  final client = _createAppwriteClient(configuration);
  return CloudGateways(
    identity: AppwriteCloudIdentityGateway(
      AppwriteAccountApiAdapter(Account(client)),
    ),
    household: AppwriteHouseholdSyncGateway(
      AppwriteTeamsApiAdapter(Teams(client), Account(client)),
    ),
    householdManagement: configuration.isHouseholdManagementEnabled
        ? AppwriteHouseholdManagementGateway(
            AppwriteHouseholdFunctionsApiAdapter(Functions(client)),
            createRobotFunctionId: configuration.createRobotFunctionId!,
            createInvitationFunctionId:
                configuration.createHouseholdInvitationFunctionId!,
            acceptInvitationFunctionId:
                configuration.acceptHouseholdInvitationFunctionId!,
            removeMemberFunctionId:
                configuration.removeHouseholdMemberFunctionId!,
          )
        : const DisabledHouseholdManagementGateway(),
    pairing: configuration.isPairingEnabled
        ? AppwriteRobotPairingGateway(
            AppwriteRobotPairingApiAdapter(Account(client), Functions(client)),
            configuration.createPairingCodeFunctionId!,
            configuration.claimRobotFunctionId!,
          )
        : const DisabledRobotPairingGateway(),
  );
}

AppwriteAccountApi _createAppwriteAccountApi(CloudConfiguration configuration) {
  final client = _createAppwriteClient(configuration);
  return AppwriteAccountApiAdapter(Account(client));
}

AppwriteTeamsApi _createAppwriteTeamsApi(CloudConfiguration configuration) {
  final client = _createAppwriteClient(configuration);
  return AppwriteTeamsApiAdapter(Teams(client), Account(client));
}

HouseholdManagementGateway _createHouseholdManagementGateway(
  CloudConfiguration configuration,
  AppwriteHouseholdFunctionsApiFactory? apiFactory,
) {
  if (!configuration.isHouseholdManagementEnabled) {
    return const DisabledHouseholdManagementGateway();
  }
  return AppwriteHouseholdManagementGateway(
    (apiFactory ?? _createAppwriteHouseholdFunctionsApi)(configuration),
    createRobotFunctionId: configuration.createRobotFunctionId!,
    createInvitationFunctionId:
        configuration.createHouseholdInvitationFunctionId!,
    acceptInvitationFunctionId:
        configuration.acceptHouseholdInvitationFunctionId!,
    removeMemberFunctionId: configuration.removeHouseholdMemberFunctionId!,
  );
}

AppwriteHouseholdFunctionsApi _createAppwriteHouseholdFunctionsApi(
  CloudConfiguration configuration,
) {
  final client = _createAppwriteClient(configuration);
  return AppwriteHouseholdFunctionsApiAdapter(Functions(client));
}

AppwriteRobotPairingApi _createAppwritePairingApi(
  CloudConfiguration configuration,
) {
  final client = _createAppwriteClient(configuration);
  return AppwriteRobotPairingApiAdapter(Account(client), Functions(client));
}

CaregiverSyncGateway _createCaregiverGateway(
  CloudConfiguration configuration, {
  CaregiverSyncGatewayFactory? gatewayFactory,
  AppwriteMedicationSyncFunctionsApiFactory? apiFactory,
  AppwriteMedicationSyncFunctionsApi? api,
  String? deviceId,
  String Function()? newId,
}) {
  if (!configuration.isMedicationSyncEnabled) {
    return const DisabledCaregiverSyncGateway();
  }
  if (gatewayFactory != null) return gatewayFactory(configuration);
  return AppwriteCaregiverSyncGateway(
    api ??
        (apiFactory ?? _createAppwriteMedicationSyncFunctionsApi)(
          configuration,
        ),
    pushFunctionId: configuration.medicationSyncPushFunctionId!,
    pullFunctionId: configuration.medicationSyncPullFunctionId!,
    deviceId: deviceId ?? 'web-${ID.unique()}',
    newId: newId ?? ID.unique,
  );
}

AppwriteMedicationSyncFunctionsApi _createAppwriteMedicationSyncFunctionsApi(
  CloudConfiguration configuration,
) {
  final client = _createAppwriteClient(configuration);
  return AppwriteMedicationSyncFunctionsApiAdapter(
    Functions(client),
    Account(client),
  );
}

Client _createAppwriteClient(CloudConfiguration configuration) =>
    Client(endPoint: configuration.endpoint!)
      ..setProject(configuration.projectId!);
