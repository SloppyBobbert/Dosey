import 'package:appwrite/appwrite.dart';
import 'package:dosey_app/core/cloud/appwrite_cloud_identity_gateway.dart';
import 'package:dosey_app/core/cloud/cloud_configuration.dart';
import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';
import 'package:dosey_app/core/household/appwrite_household_sync_gateway.dart';
import 'package:dosey_app/core/household/appwrite_robot_pairing_gateway.dart';
import 'package:dosey_app/core/household/household_sync_gateway.dart';
import 'package:dosey_app/core/household/robot_pairing_gateway.dart';

typedef AppwriteAccountApiFactory =
    AppwriteAccountApi Function(CloudConfiguration configuration);
typedef AppwriteTeamsApiFactory =
    AppwriteTeamsApi Function(CloudConfiguration configuration);
typedef AppwritePairingApiFactory =
    AppwriteRobotPairingApi Function(CloudConfiguration configuration);

class CloudGateways {
  const CloudGateways({
    required this.identity,
    required this.household,
    required this.pairing,
  });

  final CloudIdentityGateway identity;
  final HouseholdSyncGateway household;
  final RobotPairingGateway pairing;
}

CloudGateways createCloudGateways(
  CloudConfiguration configuration, {
  AppwriteAccountApiFactory? accountApiFactory,
  AppwriteTeamsApiFactory? teamsApiFactory,
  AppwritePairingApiFactory? pairingApiFactory,
}) {
  if (!configuration.isEnabled) {
    return const CloudGateways(
      identity: DisabledCloudIdentityGateway(),
      household: DisabledHouseholdSyncGateway(),
      pairing: DisabledRobotPairingGateway(),
    );
  }

  // Provider construction belongs here so the rest of app composition only
  // sees Dosey-owned contracts when Appwrite is replaced.
  if (accountApiFactory != null ||
      teamsApiFactory != null ||
      pairingApiFactory != null) {
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
      pairing: pairing,
    );
  }

  final client = _createAppwriteClient(configuration);
  return CloudGateways(
    identity: AppwriteCloudIdentityGateway(
      AppwriteAccountApiAdapter(Account(client)),
    ),
    household: AppwriteHouseholdSyncGateway(
      AppwriteTeamsApiAdapter(Teams(client)),
    ),
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
  return AppwriteTeamsApiAdapter(Teams(client));
}

AppwriteRobotPairingApi _createAppwritePairingApi(
  CloudConfiguration configuration,
) {
  final client = _createAppwriteClient(configuration);
  return AppwriteRobotPairingApiAdapter(Account(client), Functions(client));
}

Client _createAppwriteClient(CloudConfiguration configuration) =>
    Client(endPoint: configuration.endpoint!)
      ..setProject(configuration.projectId!);
